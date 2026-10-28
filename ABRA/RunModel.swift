//
//  RunModel.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/27/24.
//

import Foundation
import SwiftData
import CoreLocation
import MapKit


struct TrackCoordinate: Codable {
    var latitude: Double
    var longitude: Double
    var rest: Bool
    var elapsedTime: Double
    var date: Date
}

struct Coordinate: Codable {
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var time: Date
    func locationCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: self.latitude,
                                      longitude: self.longitude)
    }
}

struct CombinedCoordinates {
    var trackCoordinates: [TrackCoordinate]?
    var runCoordinates: [Coordinate]?
}
struct identifiablePace: Identifiable{
    let id = UUID();
    let rest: Bool;
    let paceDate: Date;
    let restPace: Double;
    let pace: Double;
    let location: CLLocationCoordinate2D;
    let dist: Double;
}
//It is expected that this function is called as soon as the coordinate is recieved.
func initCoordinate(coordinate: CLLocation, pauseSubtract: TimeInterval) -> Coordinate{
    let coord = Coordinate(latitude: coordinate.coordinate.latitude, longitude: coordinate.coordinate.longitude, horizontalAccuracy: coordinate.horizontalAccuracy, time: coordinate.timestamp.addingTimeInterval(-pauseSubtract));
    return coord;
}
func initCoordinate(coordinate: CLLocation, latitude: Double, longitude: Double, pauseSubtract: TimeInterval) -> Coordinate{
    let coord = Coordinate(latitude: latitude, longitude: longitude, horizontalAccuracy: coordinate.horizontalAccuracy, time: coordinate.timestamp.addingTimeInterval(-pauseSubtract));
    return coord;
}
func calculateDistance(from: Coordinate, to: Coordinate) -> Double {
    let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude);
    let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude);
    return loc1.distance(from: loc2)
}
func calculateTimeDifference(from: Coordinate, to: Coordinate) -> TimeInterval {
    return to.time.timeIntervalSince(from.time)
}
func calculatePace(distance: Double, time: TimeInterval) -> Double {
    let distanceUnit = UserDefaults.standard.integer(forKey: "distanceUnit")
    let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
    if distance == 0 {
        return 0
    }
    let distanceMiles = distance / distanceDivider;
    let timeMinutes = time;
    let pacePerMile = timeMinutes / distanceMiles;
    return pacePerMile;
}

@Model
final class RunData{
    @Attribute(.unique) var id: String = UUID().uuidString;
    var runStart: Date;
    var runFinish: Date = Date();
    //Oldest coordinate goes first
    var runCoordinates: [Coordinate] = [];
    var trackCoordinates: [TrackCoordinate] = [];
    var runDistanceMeters: Double = 0;
    var weatherImageString: String = "";
    var temperatureF: Double = 0.0;
    var locality: String = "";
    var runUploaded: Bool = false;
    var downloadedRunPace: Double = 0.0;
    var runCalories: Int = 0;
    var prCalculated = false;
    var pauseSubtract: TimeInterval = 0;
    var workout: Bool = false;
    @Transient
    var lapStartTime: Date?
    @Transient
    var lapPauseTime: TimeInterval = 0
    @Transient
    var kalmanFilter = GPSKalmanFilter();
    @Transient
    var precomputedPaces: [identifiablePace] = [];
    @Transient
    var tempTrackCoordinates: [TrackCoordinate] = [];
    
    
    init(id: String = UUID().uuidString){
        runStart = Date();
        runFinish = Date();
    }
    init(runStart: Date, runFinish: Date, runCoordinates: [Coordinate], runDistanceMeters: Double, weatherImageString: String, temperatureF: Double) {
        self.runStart = runStart
        self.runFinish = runFinish
        self.runCoordinates = runCoordinates
        self.runDistanceMeters = runDistanceMeters
        self.weatherImageString = weatherImageString
        self.temperatureF = temperatureF
    }
    func addCoordinate(coordinate: CLLocation){
        let latlon = kalmanFilter.process(lat: coordinate.coordinate.latitude, lng: coordinate.coordinate.longitude, accuracy: coordinate.horizontalAccuracy, timestampInMs: Double(coordinate.timestamp.millisecondsSince1970))
        runCoordinates.append(initCoordinate(coordinate: coordinate, latitude: latlon[0], longitude: latlon[1], pauseSubtract: pauseSubtract));
        _ = getRunDistance();

    }
    func addTrackCoordinate(elapsedTime: Double, rest: Bool, coord: CLLocationCoordinate2D){
        trackCoordinates.append(TrackCoordinate(latitude: coord.latitude, longitude: coord.longitude, rest: rest, elapsedTime: elapsedTime, date: Date()))
    }
    func getRunDistance() -> Double{
        if(trackCoordinates.count > 0){
            if(trackCoordinates.allSatisfy { $0.rest == true}) {
                runDistanceMeters = 0;
                return runDistanceMeters;
            }
            runDistanceMeters = Double((trackCoordinates.filter { !$0.rest }.count - 1) * 100)
            return runDistanceMeters
        }
        runDistanceMeters = 0;
        if(runCoordinates.count > 1){
            for i in 0...runCoordinates.count - 2{
                runDistanceMeters += calculateDistance(from: runCoordinates[i], to: runCoordinates[i + 1]);
            }
        }
        return runDistanceMeters;
    }
    func getWorkoutDistance() -> [Double] {
        var distances: [Double] = []
        for segment in separateWorkoutSegments() {
            if(segment.trackCoordinates!.count > 0){
                if(segment.trackCoordinates!.allSatisfy { $0.rest == true}) {
                    distances.append(0);
                } else {
                    distances.append(Double((segment.trackCoordinates!.filter { !$0.rest }.count - 1) * 100))
                }
                continue;
            }
            var tempDistance: Double = 0;
            if(segment.runCoordinates!.count > 1){
                for i in 0...segment.runCoordinates!.count - 2{
                    tempDistance += calculateDistance(from: segment.runCoordinates![i], to: segment.runCoordinates![i + 1]);
                }
            }
            distances.append(tempDistance)
        }
        print(distances)
        return distances
    }
    func getCurrentPace() -> Double {
        if(trackCoordinates.count > 0){
            //Return average of last 4 coords elapsed time (100 meter pace over last lap) which can be converted into any pace
            var totalCoordTime: Double = 0.0
            var totalCoords: Int = 0
            for coord in trackCoordinates.filter({!$0.rest}).suffix(4){
                totalCoords += 1
                totalCoordTime += coord.elapsedTime;
            }
            print(totalCoordTime)
            if(totalCoords == 0){
                return 60
            } else {
                return totalCoordTime / Double(totalCoords);
            }
        }
        let distanceUnit = UserDefaults.standard.integer(forKey: "distanceUnit")
        let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
        
        guard runCoordinates.count > 1 else {
            return 0.0
        }
        
        let lastCoordinates = Array(runCoordinates.suffix(16))
        
        var totalDistance = 0.0
        var totalTime: TimeInterval = 0.0
        
        for i in 0..<lastCoordinates.count - 1 {
            totalDistance += calculateDistance(from: lastCoordinates[i], to: lastCoordinates[i + 1])
            totalTime += calculateTimeDifference(from: lastCoordinates[i], to: lastCoordinates[i + 1])
        }
        
        guard totalDistance > 0 && totalTime > 0 else {
            return 0.0
        }
        
        let pace = calculatePace(distance: totalDistance, time: totalTime)
        if pace < 6000{
            return pace
        }else{
            return 0.0
        }
    }
    func getAveragePace() -> Double{
        if(trackCoordinates.count > 0){
            var totalCoordTime: Double = 0.0
            var totalCoords: Int = 0
            for coord in trackCoordinates.filter({!$0.rest}) {
                totalCoords += 1
                totalCoordTime += coord.elapsedTime
            }
            print(totalCoordTime)
            if(totalCoords == 0){
                return 60
            } else {
                return totalCoordTime / Double(totalCoords);
            }
        }
        let distanceUnit = UserDefaults.standard.integer(forKey: "distanceUnit")
        let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
        
        if(runCoordinates.count < 15){
            return 0.0;
        }
        let newestCoord = runCoordinates[runCoordinates.count - 1];
        let oldestCoord = runCoordinates[0];
        let timeBetweenCoords = newestCoord.time.timeIntervalSince(oldestCoord.time)
        let distBetweenCoords = runDistanceMeters;
        let rawPace = timeBetweenCoords / (distBetweenCoords/distanceDivider);
        if(rawPace < 6039){
            return rawPace
        }else{
            return 0.0
        }
    }
    
    func getAveragePaceMiles() -> Double {
        if(trackCoordinates.count > 0){
            var totalCoordTime: Double = 0.0
            var totalCoords: Int = 0
            for coord in trackCoordinates.filter({!$0.rest}) {
                totalCoords += 1
                totalCoordTime += coord.elapsedTime
            }
            return (totalCoordTime / Double(totalCoords)) * 16.09
        }
        
        let distanceDivider: Double = 1609.0
        
        if(runCoordinates.count < 15){
            return 0.0;
        }
        let newestCoord = runCoordinates[runCoordinates.count - 1];
        let oldestCoord = runCoordinates[0];
        let timeBetweenCoords = newestCoord.time.timeIntervalSince(oldestCoord.time)
        let distBetweenCoords = runDistanceMeters;
        let rawPace = timeBetweenCoords / (distBetweenCoords/distanceDivider);
        if(rawPace < 6039){
            return rawPace
        }else{
            return 0.0
        }
    }
    
    func normalizeArray<T>(_ array: [T], to newSize: Int) -> [T] {
        guard array.count > newSize else { return array }
        
        // Calculate the step size
        let stepSize = Double(array.count) / Double(newSize)
        
        var result = [T]()
        result.reserveCapacity(newSize)
        
        for i in stride(from: 0, to: Double(array.count), by: stepSize) {
            result.append(array[Int(i)])
        }
        
        return result
    }
    func getFullTrackPaces() -> [identifiablePace] {
        if(trackCoordinates.count > 0){
            var identifiablePaces: [identifiablePace] = []
            var trackTime: Double = runStart.timeIntervalSince1970
            var totalDist = 0.0
            for trackCoordinate in trackCoordinates[1...] {
                if(!trackCoordinate.rest){
                    totalDist += 100.0;
                }
                trackTime += trackCoordinate.elapsedTime;
                identifiablePaces.append(identifiablePace(rest: trackCoordinate.rest, paceDate: Date(timeIntervalSince1970: trackTime), restPace: trackCoordinate.elapsedTime, pace: (!trackCoordinate.rest ? trackCoordinate.elapsedTime : 0.0), location: CLLocationCoordinate2D(latitude: trackCoordinate.latitude, longitude: trackCoordinate.longitude), dist: totalDist))

            }
            print(identifiablePaces)
            return identifiablePaces
        }
        return []
    }
    func getPaces() -> [identifiablePace] {
        if(precomputedPaces.count > 0){
            return precomputedPaces;
        }
        if(trackCoordinates.count > 0){
            var identifiablePaces: [identifiablePace] = []
            var trackTime: Double = runStart.timeIntervalSince1970
            var totalDist = 0.0
            for trackCoordinate in trackCoordinates[1...] {
                trackTime += trackCoordinate.elapsedTime;
                if(!trackCoordinate.rest){
                    totalDist += 100.0;
                    identifiablePaces.append(identifiablePace(rest: trackCoordinate.rest, paceDate: Date(timeIntervalSince1970: trackTime), restPace: trackCoordinate.elapsedTime, pace: (!trackCoordinate.rest ? trackCoordinate.elapsedTime : 0.0), location: CLLocationCoordinate2D(latitude: trackCoordinate.latitude, longitude: trackCoordinate.longitude), dist: totalDist))
                }

            }
            precomputedPaces = identifiablePaces;
            return identifiablePaces
        }

        var identifiablePaces: [identifiablePace] = []
        let windowSize = 16;
        
        if runCoordinates.count < windowSize * 2 {
            return identifiablePaces;
        }
        var totalDist = 0.0;
        
        for i in 1...windowSize {
            let previousCoordinate = runCoordinates[i - 1];
            let currentCoordinate = runCoordinates[i];
            totalDist += (calculateDistance(from: previousCoordinate, to: currentCoordinate) / 1609)
        }
        
        for i in (windowSize+1)...runCoordinates.count - 1{
            var dist = 0.0;
            var time = 0.0;
            var paceDate = Date()
            var paceCoordinate = CLLocationCoordinate2D();
            
            let previousCoordinate = runCoordinates[i - 1];
            let currentCoordinate = runCoordinates[i];
            totalDist += (calculateDistance(from: previousCoordinate, to: currentCoordinate) / 1609)
            for j in (i-windowSize)...i {
                let previousCoordinate = runCoordinates[j - 1];
                let currentCoordinate = runCoordinates[j];
                
                dist += (calculateDistance(from: previousCoordinate, to: currentCoordinate) / 1609)
                time += currentCoordinate.time.timeIntervalSince(previousCoordinate.time);
                paceDate = currentCoordinate.time;
                paceCoordinate = currentCoordinate.locationCoordinate()
            }
            let pace = time / dist;
            
            identifiablePaces.append(identifiablePace(rest: false, paceDate: paceDate, restPace: 0.0, pace: pace / 60, location: paceCoordinate, dist: totalDist))
        }
        let normalizedPaces = normalizeArray(identifiablePaces, to: 750)
        precomputedPaces = normalizedPaces;
        return normalizedPaces;
    }
    func calculatePacesPerMile(coordinates: [Coordinate]) -> [Double] {
        guard coordinates.count > 1 else {
            return []
        }
        
        let distanceUnit = UserDefaults.standard.integer(forKey: "distanceUnit")
        let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
        
        let metersPerMile: Double = distanceDivider
        var totalDistance = 0.0
        var paces: [Double] = []
        var currentMileStartIndex = 0
        var currentMileDistance = 0.0
        var currentMileTime = 0.0
        
        for i in 1..<coordinates.count {
            let distance = CLLocation.distance(from: coordinates[i-1].locationCoordinate(),
                                               to: coordinates[i].locationCoordinate())
            let time = coordinates[i].time.timeIntervalSince(coordinates[i-1].time)
            
            totalDistance += distance
            currentMileDistance += distance
            currentMileTime += time
            
            if currentMileDistance >= metersPerMile {
                let pace = currentMileTime
                paces.append(pace)
                
                let overshoot = currentMileDistance - metersPerMile
                currentMileStartIndex = i
                currentMileDistance = overshoot
                currentMileTime = (overshoot / distance) * time
            }
        }
        

        if currentMileDistance > 0 {
            let pace = (currentMileTime / currentMileDistance) * metersPerMile
            paces.append(pace)
        }
        
        return paces
    }
    func separateWorkoutSegments() -> [CombinedCoordinates] {
        var sortedTrackCoords = trackCoordinates.sorted { $0.date < $1.date }
        //print(trackCoordinates)
        let sortedRunCoords = runCoordinates.sorted { $0.time < $1.time }
        //print(runCoordinates)
        
        var segments: [CombinedCoordinates] = []
        while (true) {
            var currentSegment = CombinedCoordinates(trackCoordinates: [], runCoordinates: []);
            
            if let firstSegment = sortedTrackCoords.first(where: { x in x.rest == true }) {
                if(firstSegment.elapsedTime > 0) {
                    currentSegment.trackCoordinates?.append(firstSegment);
                    segments.append(currentSegment);
                    sortedTrackCoords.removeAll { $0.date == firstSegment.date }
                    continue;
                }
                if let secondSegment = sortedTrackCoords.first(where: { x in x.rest == true && x.date.timeIntervalSince1970 != firstSegment.date.timeIntervalSince1970 && x.elapsedTime < 0 }) {
                    for trackCoordinate in sortedTrackCoords {
                        if trackCoordinate.date > firstSegment.date && trackCoordinate.date < secondSegment.date {
                            currentSegment.trackCoordinates?.append(trackCoordinate);
                        }
                    }
                    for runCoordinate in sortedRunCoords {
                        if runCoordinate.time > firstSegment.date && runCoordinate.time < secondSegment.date {
                            currentSegment.runCoordinates?.append(runCoordinate)
                        }
                    }
                } else {
                    for trackCoordinate in sortedTrackCoords {
                        if trackCoordinate.date > firstSegment.date {
                            currentSegment.trackCoordinates?.append(trackCoordinate);
                        }
                    }
                    for runCoordinate in sortedRunCoords {
                        if runCoordinate.time > firstSegment.date {
                            currentSegment.runCoordinates?.append(runCoordinate)
                        }
                    }
                }
                segments.append(currentSegment)
                sortedTrackCoords.removeAll { $0.date == firstSegment.date }
            } else {
                return segments;
            }
        }
    }
    func getCLLocationCoordinates() -> [CLLocationCoordinate2D]{
        var coordinates: [CLLocationCoordinate2D] = [];
        
        for coordinate in runCoordinates{
            coordinates.append(CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude));
        }
        
        return coordinates;
    }
    func getAverageCoordinate() -> CLLocationCoordinate2D{
        var totalLat = 0.0;
        var totalLon = 0.0;
        var numCoords: Double = 0.0;
        let coordinates = getCLLocationCoordinates();
        
        if(coordinates.count < 1){
            return CLLocationCoordinate2D()
        }
        
        for coordinate in coordinates{
            numCoords += 1;
            totalLat += coordinate.latitude;
            totalLon += coordinate.longitude;
        }
        totalLat /= numCoords;
        totalLon /= numCoords;
        
        return CLLocationCoordinate2D(latitude: totalLat, longitude: totalLon)
    }
    func getZoom() -> MKCoordinateRegion {
        let latitudes = runCoordinates.map { $0.latitude }
        let longitudes = runCoordinates.map { $0.longitude }
        
        let c1 = CLLocation(latitude: latitudes.min()!, longitude: longitudes.min()!)
        let c2 = CLLocation(latitude: latitudes.max()!, longitude: longitudes.max()!)
        
        let zoom = c1.distance(from: c2)
        
        let location = CLLocationCoordinate2D(latitude: (latitudes.min()! + latitudes.max()!)/2, longitude: (longitudes.min()! + longitudes.max()!)/2)
        return MKCoordinateRegion(center: location, latitudinalMeters: zoom, longitudinalMeters: zoom);
    }
    func getZoomMeters() -> Double {
        let latitudes = runCoordinates.map { $0.latitude }
        let longitudes = runCoordinates.map { $0.longitude }
        
        let c1 = CLLocation(latitude: latitudes.min()!, longitude: longitudes.min()!)
        let c2 = CLLocation(latitude: latitudes.max()!, longitude: longitudes.max()!)
        
        let zoom = c1.distance(from: c2)
        
        return zoom * 8;
    }
    func getRunElapsedTimeString() -> String {
        if let LST = lapStartTime {
            let newTime = LST.addingTimeInterval(lapPauseTime)
            let seconds = -newTime.timeIntervalSinceNow.truncatingRemainder(dividingBy: 60);
            let minutes = (-newTime.timeIntervalSinceNow - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            return formattedMin + ":" + formattedSec;
        }
        let newTime = runStart.addingTimeInterval(pauseSubtract)
        let seconds = -newTime.timeIntervalSinceNow.truncatingRemainder(dividingBy: 60);
        let minutes = (-newTime.timeIntervalSinceNow - seconds) / 60;
        let formattedMin = String(format: "%.0f", minutes)
        let formattedSec: String = String(format: "%02d", Int(seconds));
        return formattedMin + ":" + formattedSec;
    }
    func getRunElapsedTimeString(date: Date) -> String {
        let seconds = -runStart.timeIntervalSince(date).truncatingRemainder(dividingBy: 60);
        let minutes = (-runStart.timeIntervalSince(date) - seconds) / 60;
        let formattedMin = String(format: "%.0f", minutes)
        let formattedSec: String = String(format: "%02d", Int(seconds));
        return formattedMin + ":" + formattedSec;
    }
    func getFinishedRunElapsedTimeString() -> String{
        let newTime = runStart.addingTimeInterval(pauseSubtract)
        if(runFinish.timeIntervalSince(newTime) < 3600){
            let seconds = runFinish.timeIntervalSince(newTime).truncatingRemainder(dividingBy: 60);
            let minutes = (runFinish.timeIntervalSince(newTime) - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            return formattedMin + ":" + formattedSec;
        }else{
            let seconds = runFinish.timeIntervalSince(newTime).truncatingRemainder(dividingBy: 60);
            let minutes = (runFinish.timeIntervalSince(newTime) - seconds) / 60;
            let minutesDisplay = minutes.truncatingRemainder(dividingBy: 60);
            let hours = (minutes - minutesDisplay) / 60;
            let formattedHours = String(format: "%.0f", hours)
            var formattedMin = String(format: "%.0f", minutesDisplay)
            if(Int(formattedMin) ?? 10 < 10){
                formattedMin = "0" + formattedMin;
            }
            let formattedSec: String = String(format: "%02d", Int(seconds));
            return formattedHours + ":" + formattedMin + ":" + formattedSec;
        }
    }
    func getTrackRun() -> Bool {
        if trackCoordinates.count > 0{
            return true
        }
        return false
    }
    func getFinishedRunElapsedTime() -> Double {
        return runFinish.timeIntervalSince(runStart.addingTimeInterval(pauseSubtract));
    }
    func finalizeRun(){
        runDistanceMeters = getRunDistance();
    }
    func startRun(){
        runStart = Date();
    }
    func stopRun(){
        runFinish = Date();
    }
    
}


class GPSKalmanFilter {
    var decay: Double
    var variance: Double
    var minAccuracy: Double
    var lat: Double
    var lng: Double
    var timestampInMs: Double
    
    init(decay: Double = 3.5) {
        self.decay = decay
        self.variance = -1
        self.minAccuracy = 1
        self.lat = 0
        self.lng = 0
        self.timestampInMs = 0
    }
    
    func process(lat: Double, lng: Double, accuracy: Double, timestampInMs: Double) -> [Double] {
        var accuracy = accuracy
        if accuracy < minAccuracy {
            accuracy = minAccuracy
        }
        
        if variance < 0 {
            self.timestampInMs = timestampInMs
            self.lat = lat
            self.lng = lng
            self.variance = accuracy * accuracy
        } else {
            let timeIncMs = timestampInMs - self.timestampInMs
            
            if timeIncMs > 0 {
                self.variance += (timeIncMs * decay * decay) / 1000
                self.timestampInMs = timestampInMs
            }
            
            let _k = self.variance / (self.variance + (accuracy * accuracy))
            self.lat += _k * (lat - self.lat)
            self.lng += _k * (lng - self.lng)
            
            self.variance = (1 - _k) * self.variance
        }
        
        return [self.lat, self.lng]
    }
}

extension Date {
    var millisecondsSince1970:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
