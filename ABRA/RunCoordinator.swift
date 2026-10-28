//
//  LocationServices.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/26/24.
//

import Foundation
import CoreLocation
import SwiftData
import SwiftUI
import ActivityKit

struct RunLiveData: ActivityAttributes {
    var test = 1;
    public struct ContentState: Codable, Hashable {
        var runDistanceMeters: Double
        var pace: Double
        var elapsedTime: String
    }
}

class RunCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = RunCoordinator();
    
    let locationManager = CLLocationManager();
    var runManager = RunData();
    var lastCoordinate: CLLocation? = nil;
    var locationAccessType: CLAuthorizationStatus = .notDetermined;
    var elapsedTimeTimer: Timer?;
    var lastWeatherUpdate: Date = Date(timeIntervalSince1970: 0);
    var runRoute: RouteModel? = nil;
    var trackCoordinates: [RoutePoint]? = nil;
    var dontFetchRuns = false;
    var runPausedTime: TimeInterval = 0;
    var runPausedLastUpdated: Date = Date();
    var lastTrackReferenceCoordinate = 0;
    var lastTrackCoordinateTime = Date();
    var lastLocation: CLLocation = CLLocation()
    var distanceSubtract: Double = 0;

    @Published var locationPermitted = false;
    @Published var locationDenied = false;
    @Published var runOccuring = false;
    @Published var runScreen = false;
    @Published var runPaused = false;
    @Published var runCountdownActive = false;
    @Published var runCountdown = 1;
    @Published var currentPace: Double = 0;
    @Published var averagePace: Double = 0;
    @Published var runTimeString: String = "0:00";
    @Published var runPausedString: String = "0:00"
    
    @AppStorage("weight") private var selectedWeight: Double = 150
    @AppStorage("weightUnit") private var weightUnit = 0
    @AppStorage("distanceUnit") private var distanceUnit = 1

    
    override init() {
        super.init();
        
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    //Location Permission Stuff
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAccessType = locationManager.authorizationStatus;
        switch locationManager.authorizationStatus{
        case .notDetermined:
            self.locationPermitted = false;
            self.locationDenied = false;
        case .authorizedWhenInUse:
            self.locationPermitted = true;
            self.locationDenied = false;
        default:
            self.locationDenied = true;
            self.locationPermitted = false;
        }
    }
    //Call when location status needs to be determined or redetermined. Returns whether the user denied access to location or not
    func getLocationStatus(request: Bool){
        switch locationManager.authorizationStatus{
        case .notDetermined:
            self.locationPermitted = false;
            self.locationDenied = false;
            if(request){
                locationManager.requestWhenInUseAuthorization();
            }
        case .authorizedWhenInUse:
            self.locationDenied = false;
            self.locationPermitted = true;
        default:
            self.locationDenied = true;
            self.locationPermitted = false;
        }
    }
    //Live Activity stuff
    func startRunningActivity() {
        let runLiveDataStruct = RunLiveData()
        let runLiveData = RunLiveData.ContentState(
            runDistanceMeters: 0,
            pace: 0.0,
            elapsedTime: "0:00"
        )
        
        do {
            let activity = try Activity.request(
                attributes: runLiveDataStruct,
                content: .init(state: runLiveData, staleDate: nil),
                pushType: nil
            )
            
        } catch (let error) {
        
        }
    }
    func updateRunningActivity(distance: Double, elapsedTime: String, pace: Double) {
        let updatedContentState = RunLiveData.ContentState(
            runDistanceMeters: distance,
            pace: pace,
            elapsedTime: elapsedTime
        )
        
        Task {
            for activity in Activity<RunLiveData>.activities {
                await activity.update(.init(state: updatedContentState, staleDate: Date().addingTimeInterval(0.05)))
            }
        }
    }
    
    func endRunningActivity() {
        Task {
            for activity in Activity<RunLiveData>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    //Run Tracking Stuff
    func startRun(){
        Task.detached{
            await WeatherStuff.shared.getWeather();
        }
        UIApplication.shared.isIdleTimerDisabled = true;
        locationManager.startUpdatingLocation();
        locationManager.allowsBackgroundLocationUpdates = true;
        locationManager.showsBackgroundLocationIndicator = true;
        runScreen = true;
        if let realTrackCoordinates = trackCoordinates {
            lastTrackCoordinateTime = Date()
            runManager.addTrackCoordinate(elapsedTime: 0, rest: false, coord: realTrackCoordinates[0].coordinate)
            self.runOccuring = true;
            self.runManager.startRun();
            self.elapsedTimeTimer?.invalidate();
            self.elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                if(!self.runPaused) {
                    self.runTimeString = self.runManager.getRunElapsedTimeString();
                    self.runPausedString = self.getPauseElapsedTimeString();
                }else{
                    self.runPausedString = self.getPauseElapsedTimeString();
                    if(Date().timeIntervalSince(self.runPausedLastUpdated) >= 1){
                        self.runPausedTime += 1;
                        self.runPausedLastUpdated = Date()
                        self.runManager.pauseSubtract += 1;
                        if let _ = self.runManager.lapStartTime {
                            self.runManager.lapPauseTime += 1
                        }
                    }
                }
            }
            self.runManager.weatherImageString = WeatherStuff.shared.currentWeather?.symbolName ?? "cloud.sun";
            let temp = (WeatherStuff.shared.currentWeather?.temperature.value ?? 0) * 9/5 + 32
            self.runManager.temperatureF = temp;
            runCountdown = 0
        }else{
            startRunningActivity()
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                if(self.runCountdown > 0){
                    self.runCountdown -= 1;
                }else{
                    self.runOccuring = true;
                    self.runManager.startRun();
                    self.elapsedTimeTimer?.invalidate();
                    self.elapsedTimeTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                        if(!self.runPaused) {
                            self.runTimeString = self.runManager.getRunElapsedTimeString();
                            self.runPausedString = self.getPauseElapsedTimeString();
                        }else{
                            self.runPausedString = self.getPauseElapsedTimeString();
                            if(Date().timeIntervalSince(self.runPausedLastUpdated) >= 1){
                                self.runPausedTime += 1;
                                self.runPausedLastUpdated = Date()
                                self.runManager.pauseSubtract += 1;
                            }
                        }
                    
                        
                    }
                    self.runManager.weatherImageString = WeatherStuff.shared.currentWeather?.symbolName ?? "cloud.sun";
                    let temp = (WeatherStuff.shared.currentWeather?.temperature.value ?? 0) * 9/5 + 32
                    self.runManager.temperatureF = temp;
                    timer.invalidate()
                }
            }
        }
    }
    func resetPause() {
        if let realTrackCoordinates = trackCoordinates {
            for (index, realTrackCoordinate) in realTrackCoordinates.enumerated() {
                let realTrackLocationCoordinate = CLLocation(latitude: realTrackCoordinate.coordinate.latitude, longitude: realTrackCoordinate.coordinate.longitude)
                if(realTrackLocationCoordinate.distance(from: lastLocation) < 8 && lastLocation.horizontalAccuracy < 12){
                    if(index != lastTrackReferenceCoordinate){
                        let markings = detectSkippedMarkings(currentPosition: index);
                        let coordElapsedTime = lastLocation.timestamp.timeIntervalSince(lastTrackCoordinateTime) / Double(markings)
                        for marking in (0...markings-1).reversed() {
                            let newIndex = (index + marking + 4) % 4
                            let referenceCoord = realTrackCoordinates[newIndex]
                        }
                        lastTrackCoordinateTime = lastLocation.timestamp;
                        lastTrackReferenceCoordinate = index;
                    }
                }
            }
            runManager.addTrackCoordinate(elapsedTime: runPausedTime, rest: true, coord: realTrackCoordinates[lastTrackReferenceCoordinate].coordinate)
            lastTrackCoordinateTime = Date()
        }
        runPausedTime = 0;
    }
    func stopAndResetRun(container: ModelContainer){
        runManager.stopRun();
        endRunningActivity();
        let calories = (runManager.runDistanceMeters / 1000) * ((weightUnit == 0) ? selectedWeight : (selectedWeight / 2.205)) * 1.032;
        runManager.runCalories = Int(calories);
        runOccuring = false;
        runScreen = false;
        UIApplication.shared.isIdleTimerDisabled = false;
        locationManager.allowsBackgroundLocationUpdates = false;
        locationManager.showsBackgroundLocationIndicator = false;
        locationManager.stopUpdatingLocation();
        dontFetchRuns = true;
        Task{
            let context = ModelContext(container)
            if let firstCoord = runManager.runCoordinates.first{
                let locality = await sendRunAndGetLocality(runDistance: Float(runManager.runDistanceMeters) / 1609, runPace: Float(runManager.getAveragePaceMiles()), runTime: Float(runManager.getFinishedRunElapsedTime()), runStart: Int(runManager.runStart.timeIntervalSince1970), runStartCoord: firstCoord.locationCoordinate())
                runManager.locality = locality;
                if(locality != "Earth"){
                    runManager.runUploaded = true;
                }
                context.insert(runManager);
                do {
                    try context.save()
                    
                } catch {
                }
            }
            await PRManager.shared.updatePRs(with: runManager);
            runManager.prCalculated = true;
            DispatchQueue.main.async {
                self.resetRun()
                self.dontFetchRuns = false;
            }
        }
    }
    private func resetRun(){
        //New RunData
        runManager = RunData();
        //Reset the countdown
        runCountdown = 1;
        //Don't show runPaused screen on next run
        runPaused = false;
        runPausedTime = 0;
        //Reset the timer
        runTimeString = "0:00"
        elapsedTimeTimer?.invalidate();
        //Reset the route
        runRoute = nil;
        //Reset the last coordinate
        lastCoordinate = nil;
        //No track stuff
        trackCoordinates = nil;
        lastTrackReferenceCoordinate = 0;
        lastTrackCoordinateTime = Date();
        
        distanceSubtract = 0
        currentPace = 0
        averagePace = 0
    }
    
    func getPauseElapsedTimeString() -> String {
        let seconds = runPausedTime.truncatingRemainder(dividingBy: 60);
        let minutes = (runPausedTime - seconds) / 60;
        let formattedMin = String(format: "%.0f", minutes)
        let formattedSec: String = String(format: "%02d", Int(seconds));
        return formattedMin + ":" + formattedSec;
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]){
        lastLocation = locations[locations.count - 1]
        WeatherStuff.shared.currentLocation = locations[0];
        if(lastWeatherUpdate.timeIntervalSinceNow < -300){
            lastWeatherUpdate = Date();
            Task.detached{
                await WeatherStuff.shared.getWeather();
            }
        }
        if(runCountdown > 0 || runPaused == true){
            return;
        }

        for location in locations {
            if let realTrackCoordinates = trackCoordinates {
                for (index, realTrackCoordinate) in realTrackCoordinates.enumerated() {
                    let realTrackLocationCoordinate = CLLocation(latitude: realTrackCoordinate.coordinate.latitude, longitude: realTrackCoordinate.coordinate.longitude)
                    if(realTrackLocationCoordinate.distance(from: location) < 8 && location.horizontalAccuracy < 12){
                        if(index != lastTrackReferenceCoordinate){
                            let markings = detectSkippedMarkings(currentPosition: index);
                            let coordElapsedTime = location.timestamp.timeIntervalSince(lastTrackCoordinateTime) / Double(markings)
                            for marking in (0...markings-1).reversed() {
                                let newIndex = (index + marking + 4) % 4
                                let referenceCoord = realTrackCoordinates[newIndex]
                                runManager.addTrackCoordinate(elapsedTime: coordElapsedTime, rest: false, coord: referenceCoord.coordinate)
                                print("trackcoord \(coordElapsedTime)")
                                print("dist: \(runManager.getRunDistance())")
                                print("averagepace: \(runManager.getAveragePace())")
                                print("")
                            }
                            lastTrackCoordinateTime = location.timestamp;
                            lastTrackReferenceCoordinate = index;
                        }
                    }
                }
            }
            if(lastCoordinate != nil){
                if(location.horizontalAccuracy > 17){
                    continue;
                }
                let radii = (lastCoordinate!.horizontalAccuracy + location.horizontalAccuracy) * 0.20;
                //print(CLLocation.distance(from: lastCoordinate!.coordinate, to: location.coordinate));
                if(CLLocation.distance(from: lastCoordinate!.coordinate, to: location.coordinate) > radii){
                    runManager.addCoordinate(coordinate: location);
                    currentPace = runManager.getCurrentPace();
                    averagePace = runManager.getAveragePace();
                    lastCoordinate = location;
                }
            }else{
                if(location.horizontalAccuracy > 17){
                    continue;
                }
                runManager.addCoordinate(coordinate: location);
                lastCoordinate = location;
            }
        }
        updateRunningActivity(distance: runManager.runDistanceMeters, elapsedTime: runManager.getRunElapsedTimeString(), pace: runManager.getCurrentPace())
    }
    func detectSkippedMarkings(currentPosition: Int) -> Int {
        let totalPositions = 4
        
        var positionsMoved = (currentPosition - lastTrackReferenceCoordinate + totalPositions) % totalPositions
        
        if positionsMoved == 0 {
            positionsMoved = totalPositions
        }
        
        //num skipped markings + 1
        return min(positionsMoved, 4)
    }

}

extension CLLocation {
    class func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
}

