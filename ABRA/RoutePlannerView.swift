//
//  RoutePlannerView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/13/24.
//

import SwiftUI
import SwiftData
import MapKit

struct RoutePlannerView: View {
    @Binding var presented: Bool;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    @State private var routePoints: [RoutePoint] = []
    @State private var routeDistanceText = "";
    var modelContainer: ModelContainer

    var body: some View {
        let unit = (distanceUnit == 0) ? " km" : " mi"
        let glassRectangle = RoundedRectangle(cornerRadius: 20, style: .continuous)
        MapReader { reader in
            Map(initialPosition: .userLocation(fallback: .automatic), interactionModes: .all) {
                //Move these to the routelistview
                if routePoints.count > 1 {
                    MapPolyline(coordinates: routePoints.map(\.coordinate))
                        .stroke(.blue, lineWidth: 3)
                }
                ForEach(routePoints) { point in
                    Annotation(coordinate: point.coordinate, anchor: .center){
                            Circle().foregroundStyle(.accent).frame(width: 10, height: 10);
                    } label: {
                        
                    }
                }
            }
            .onTapGesture { screenCoord in
                if let pinLocation = reader.convert(screenCoord, from: .local) {
                    addRoutePoint(pinLocation)
                    setDistanceString()
                }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            VStack(spacing: 0){
                VStack {
                    Spacer()
                    if routePoints.isEmpty{
                        Text("Select a Location").font(.system(size: 27, weight: .bold)).multilineTextAlignment(.center).padding([.leading, .trailing])
                    }else{
                        Text("Distance: " + routeDistanceText + unit).font(.system(size: 27, weight: .bold)).multilineTextAlignment(.center).padding([.leading, .trailing])
                    }
                    Spacer()
                }.frame(height: 70)
                VStack(spacing: 0){
                    Divider()
                    HStack {
                        Spacer()
                        Button {
                            if(routePoints.count == 0){
                                presented = false;
                                return;
                            }
                            let _ = routePoints.popLast()
                            setDistanceString()
                        }label: {
                            if(routePoints.count == 0){
                                Text("Cancel")
                            } else {
                                Text("Undo")
                            }
                        }
                        Spacer()
                        Divider()
                        Spacer()
                        Button {
                            let context = ModelContext(modelContainer)
                            context.insert(RouteModel(coords: routePoints.map{ $0.coordinate }, distance: getRouteDistance()))
                            do {
                                try context.save()
                            }catch {
                            }
                            presented = false;
                        } label: {
                            Text("Done")
                        }
                        Spacer()
                    }.frame(height: 45)
                }
            }.frame(width: 330, height: 115).background(.ultraThinMaterial, in: glassRectangle).padding()
        }
    }

    private func addRoutePoint(_ coordinate: CLLocationCoordinate2D) {
        let newPoint = RoutePoint(coordinate: coordinate)
        routePoints.append(newPoint)
    }
    func getRouteDistance() -> Double{
        var runDistanceMeters = 0.0;
        if(routePoints.count > 1){
            for i in 0...routePoints.count - 2{
                runDistanceMeters += calculateDistance(from: routePoints[i], to: routePoints[i + 1]);
            }
        }
        return runDistanceMeters;
    }
    func calculateDistance(from: RoutePoint, to: RoutePoint) -> Double {
        let loc1 = CLLocation(latitude: from.coordinate.latitude, longitude: from.coordinate.longitude);
        let loc2 = CLLocation(latitude: to.coordinate.latitude, longitude: to.coordinate.longitude);
        return loc1.distance(from: loc2)
    }
    func setDistanceString() {
        let distanceDivider: Double = (distanceUnit == 0) ? 1000 : 1609;
        let routeDistanceMeters = getRouteDistance();
        routeDistanceText = String(format: "%.2f", routeDistanceMeters/distanceDivider)
    }
}
struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

