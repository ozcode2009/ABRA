//
//  RouteMOdel.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/13/24.
//

import Foundation
import SwiftData
import CoreLocation
import MapKit

@Model
final class RouteModel {
    @Attribute(.unique)
    var id = UUID()
    var routeDistanceMeters: Double
    var coordinates: [RouteCoord]
    
    init(coords: [CLLocationCoordinate2D], distance: Double){
        coordinates = coords.map{ RouteCoord(latitude: $0.latitude, longitude: $0.longitude) }
        routeDistanceMeters = distance;
    }
    func getAverageCoordinate() -> CLLocationCoordinate2D{
        var totalLat = 0.0;
        var totalLon = 0.0;
        var numCoords: Double = 0.0;
        let locationCoordinates = coordinates.map { $0.toCLLocationCoordinate() };
        
        if(locationCoordinates.count < 1){
            return CLLocationCoordinate2D()
        }
        
        for locationCoordinate in locationCoordinates{
            numCoords += 1;
            totalLat += locationCoordinate.latitude;
            totalLon += locationCoordinate.longitude;
        }
        totalLat /= numCoords;
        totalLon /= numCoords;
        
        return CLLocationCoordinate2D(latitude: totalLat, longitude: totalLon)
    }
    func getZoom() -> MKCoordinateRegion {
        if coordinates.count > 1 {
            let latitudes = coordinates.map { $0.latitude }
            let longitudes = coordinates.map { $0.longitude }
            
            let c1 = CLLocation(latitude: latitudes.min()!, longitude: longitudes.min()!)
            let c2 = CLLocation(latitude: latitudes.max()!, longitude: longitudes.max()!)
            
            let zoom = c1.distance(from: c2)
            
            let location = CLLocationCoordinate2D(latitude: (latitudes.min()! + latitudes.max()!)/2, longitude: (longitudes.min()! + longitudes.max()!)/2)
            return MKCoordinateRegion(center: location, latitudinalMeters: zoom, longitudinalMeters: zoom);
        } else{
            return MKCoordinateRegion(center: CLLocationCoordinate2D(), latitudinalMeters: 5, longitudinalMeters: 5);
        }
    }
}

struct RouteCoord: Codable, Identifiable {
    let id = UUID()
    var latitude : Double
    var longitude: Double
    
    mutating func fromCLLocationCoordinate(coord: CLLocationCoordinate2D){
        latitude = coord.latitude;
        longitude = coord.longitude;
    }
    func toCLLocationCoordinate() -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
