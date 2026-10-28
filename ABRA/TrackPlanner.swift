//
//  RoutePlannerView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 8/15/24.
//

import SwiftUI
import MapKit

struct TrackPlannerView: View {
    @Binding var presented: Bool;
    
    @State private var trackPoints: [RoutePoint] = []
    @State private var instructions = "Select the start of the track";

    var body: some View {
        let glassRectangle = RoundedRectangle(cornerRadius: 20, style: .continuous)
        MapReader { reader in
            Map(initialPosition: .userLocation(fallback: .automatic), interactionModes: .all) {
                UserAnnotation()
                ForEach(trackPoints) { point in
                    Annotation(coordinate: point.coordinate, anchor: .center){
                            Circle().foregroundStyle(.accent).frame(width: 10, height: 10);
                    } label: {
                        
                    }
                }
            }
            .onTapGesture { screenCoord in
                if let pinLocation = reader.convert(screenCoord, from: .local) {
                    addRoutePoint(pinLocation)
                    setInstructionString()
                }
            }
            .mapStyle(.hybrid)
        }
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            VStack(spacing: 0){
                VStack {
                    Spacer()
                    Text(instructions).font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center).padding([.leading, .trailing])
                    Spacer()
                }.frame(height: 70)
                Divider()
                VStack{
                    Spacer()
                    Text("Ensure the point you select is in the middle of the lane you will be running in").bold().padding(.horizontal).multilineTextAlignment(.center).font(.system(size: 15))
                    Spacer()
                }.frame(height: 60)
                VStack(spacing: 0){
                    Divider()
                    HStack {
                        Spacer()
                        Button {
                            if(trackPoints.count == 0){
                                presented = false;
                                return;
                            }
                            let _ = trackPoints.popLast()
                            setInstructionString()
                        }label: {
                            if(trackPoints.count == 0){
                                Text("Cancel")
                            } else {
                                Text("Undo")
                            }
                        }
                        Spacer()
                    }.frame(height: 45)
                }
            }.frame(width: 330, height: 175).background(.ultraThinMaterial, in: glassRectangle).padding()
        }
        .overlay(alignment: .bottom) {
            if(trackPoints.count >= 4) {
                Button {
                    RunCoordinator.shared.trackCoordinates = trackPoints
                    if(!RunCoordinator.shared.locationPermitted){
                        RunCoordinator.shared.getLocationStatus(request: true);
                    }
                    if(RunCoordinator.shared.locationPermitted){
                        RunCoordinator.shared.startRun();
                    }
                } label: {
                    Text("START")
                        .frame(width: 100, height: 60)
                        .foregroundColor(Color(hex: 0xffffff))
                        .background(Color(hex: 0x19B519))
                        .clipShape(Capsule())
                        .font(Font.custom("HelveticaNeue-Bold", size: 20))
                }.padding(.bottom).padding(.bottom)
            }
        }
    }

    private func addRoutePoint(_ coordinate: CLLocationCoordinate2D) {
        if(trackPoints.count < 4) {
            let newPoint = RoutePoint(coordinate: coordinate)
            trackPoints.append(newPoint)
        }
    }
    func setInstructionString() {
        switch trackPoints.count {
        case 0:
            instructions = "Select the start of the track"
            break;
        case 1:
            instructions = "Select the 100 meter mark"
            break;
        case 2:
            instructions = "Select the 200 meter mark"
            break;
        case 3:
            instructions = "Select the 300 meter mark"
            break;
        default:
            instructions = "Press Start"
            break;
        }
    }
}
