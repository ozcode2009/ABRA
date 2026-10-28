//
//  RunningView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/27/24.
//

import Foundation
import SwiftUI
import MapKit
import SwiftData

struct RunningView: View{
    
    let container: ModelContainer
    
    @AppStorage("distanceUnit") private var distanceUnit = 1
    @StateObject var runCoordinator = RunCoordinator.shared;
    @ObservedObject var musicCoordinator = MusicCoordinator.shared
    @State var runPausedText = "";
    @State var runExtraText = "";
    @State var circleTrim = 1.0;
    @State var stopButtonPressed = false;
    @State var timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var fontSize: CGFloat = 37;
    
    var body: some View{
        ZStack{
            let mapCoordinates = runCoordinator.runManager.getCLLocationCoordinates();
            Map(initialPosition: .userLocation(fallback: .automatic),
                bounds: MapCameraBounds(centerCoordinateBounds: MKCoordinateRegion(center: runCoordinator.lastCoordinate?.coordinate ?? CLLocationCoordinate2D(), latitudinalMeters: 10000, longitudinalMeters: 10000), minimumDistance: 125, maximumDistance: 10000),
                interactionModes: .all) {
                if runCoordinator.runRoute != nil {
                    MapPolyline(coordinates: runCoordinator.runRoute!.coordinates.map { $0.toCLLocationCoordinate()} )
                        .stroke(.orange, lineWidth: 2);
                }
                MapPolyline(coordinates: mapCoordinates)
                    .stroke(.blue, lineWidth: 2);
                UserAnnotation();
            }
            .mapControlVisibility(.hidden)
            .ignoresSafeArea()
            
            VStack{
                let unit = runCoordinator.runManager.getTrackRun() ? " meters" : (distanceUnit == 0) ? " km" : " miles"
                let dist = runCoordinator.runManager.getTrackRun() ? (runCoordinator.runManager.runDistanceMeters - Double(runCoordinator.distanceSubtract)) : (distanceUnit == 0) ? (runCoordinator.runManager.runDistanceMeters - Double(runCoordinator.distanceSubtract))/1000 : (runCoordinator.runManager.runDistanceMeters - Double(runCoordinator.distanceSubtract))/1609
                let formattedDist = String(format: runCoordinator.runManager.getTrackRun() ? "%.0f" : "%.2f", dist)
                Text(formattedDist + unit).font(Font.custom("HelveticaNeue-Bold", size: 37)).fontWeight(.bold).frame(width: 275, height: 80).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous)).padding().padding()

                Spacer()
                VStack(spacing: 0) {
                    Spacer()
                    HStack{
                        Spacer()
                        CurrentPaceView(fontSize: fontSize, pace: runCoordinator.currentPace, run: runCoordinator.runManager);
                        Spacer()
                        TimeView(fontSize: fontSize, runElapsedTimeString: runCoordinator.runTimeString);
                        Spacer()
                        AvgPaceView(fontSize: fontSize, avgPace: runCoordinator.averagePace, run: runCoordinator.runManager);
                        Spacer()
                    }
                    Spacer()
                    Divider()
                    VStack {
                        Spacer()
                        HStack {
                            Text(musicCoordinator.songName).bold().padding(.leading);
                            Spacer()
                            HStack {
                                if(musicCoordinator.isPlaying){
                                    Button {
                                        musicCoordinator.pause()
                                    } label: {
                                        Image(systemName: "pause.fill").resizable().scaledToFit().frame(width: 20, height: 20)
                                    }.padding(.trailing)
                                }else{
                                    Button {
                                        musicCoordinator.play()
                                    } label: {
                                        Image(systemName: "play.fill").resizable().scaledToFit().frame(width: 20, height: 20)
                                    }.padding(.trailing)
                                }
                                Button {
                                    musicCoordinator.skip()
                                } label: {
                                    Image(systemName: "forward.fill").resizable().scaledToFit().frame(width: 20, height: 20)
                                }
                            }.padding().foregroundStyle(.foreground)
                        }
                        Spacer()
                    }.frame(height: 50);
                }.frame(width: 350, height: 145).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous)).padding()
                Button(action: {
                    runCoordinator.runPaused = true;
                    runPausedText = "Run is paused";
                    runExtraText = "Hold down the stop button to stop the run"
                }){
                    Text("PAUSE")
                        .frame(width: 100, height: 60)
                        .foregroundColor(Color(hex: 0xffffff))
                        .background(Color.red)
                        .clipShape(Capsule())
                        .font(Font.custom("HelveticaNeue-Bold", size: 20))
                }.padding([.bottom]).padding([.bottom]).padding([.bottom]).padding([.bottom]).padding([.bottom])
            }
            if(runCoordinator.runPaused){
                ZStack{
                    RoundedRectangle(cornerRadius: 8.0)
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea()
                    VStack{
                        Spacer()
                        HStack{
                            Spacer();
                            VStack{
                                Text(runCoordinator.runPausedString).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
                                Text("rest").font(Font.custom("HelveticaNeue-Bold", size: 18)).lineLimit(1).minimumScaleFactor(0.35);
                            }
                            .frame(width: 90)
                            Spacer();
                            DarkMileView(run: runCoordinator.runManager, fontSize: 37)
                            Spacer();
                        }
                        .frame(width: 350, height: 100).background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .foregroundStyle(.ultraThinMaterial)).padding([.bottom])
                        HStack{
                            Spacer();
                            VStack{
                                Text(runCoordinator.runTimeString).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
                                Text("time").font(Font.custom("HelveticaNeue-Bold", size: 18)).lineLimit(1).minimumScaleFactor(0.35);
                            }
                            .frame(width: 90)
                            Spacer();
                            DarkAvgPaceView(fontSize: 37, avgPace: runCoordinator.averagePace, run: runCoordinator.runManager);
                            Spacer();
                        }
                        .frame(width: 350, height: 100).background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .foregroundStyle(.ultraThinMaterial)).padding([.bottom])
                        Text(runPausedText).multilineTextAlignment(.center).font(Font.custom("HelveticaNeue-Bold", size: 26)).padding([.leading, .trailing]);
                        Text(runExtraText).multilineTextAlignment(.center).font(Font.custom("HelveticaNeue-Bold", size: 18)).padding([.leading, .trailing]);
                        Spacer()
                        if let _ = runCoordinator.trackCoordinates {
                            VStack{
                                HStack {
                                    Spacer()
                                    Button {
                                        runCoordinator.runManager.lapStartTime = Date()
                                        runCoordinator.runManager.lapPauseTime = 0;
                                        runCoordinator.distanceSubtract = runCoordinator.runManager.runDistanceMeters;
                                        runCoordinator.runPaused = false;
                                        runPausedText = "";
                                        runExtraText = ""
                                        runCoordinator.resetPause()
                                    } label: {
                                        Text("Lap & Resume")
                                            .frame(width: 175, height: 60)
                                            .foregroundColor(.white)
                                            .background(.black)
                                            .clipShape(Capsule())
                                            .font(Font.custom("HelveticaNeue-Bold", size: 20))
                                    }.padding(.bottom).padding(.bottom)
                                    Spacer()
                                    Button {
                                        runCoordinator.runPaused = false;
                                        runPausedText = "";
                                        runExtraText = ""
                                        runCoordinator.resetPause()
                                    } label: {
                                        Text("Resume")
                                            .frame(width: 100, height: 60)
                                            .foregroundColor(.white)
                                            .background(.black)
                                            .clipShape(Capsule())
                                            .font(Font.custom("HelveticaNeue-Bold", size: 20))
                                    }.padding(.bottom).padding(.bottom)
                                    Spacer()
                                }.padding()
                                HStack {
                                    Spacer()
                                    Image(systemName: "stop.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(Color.black)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .onLongPressGesture(minimumDuration: 60){
                                            RunCoordinator.shared.stopAndResetRun(container: container);
                                        } onPressingChanged: { isPressing in
                                            self.stopButtonPressed = isPressing;
                                            if(isPressing == false){
                                                circleTrim = 1;
                                            }
                                        }
                                        .mask(){
                                            clock(circleTrim).frame(width: 100, height: 100)
                                        }
                                    Spacer()
                                }.padding()
                            }
                        } else {
                            HStack{
                                Spacer()
                                Button(action: {
                                    runCoordinator.runPaused = false;
                                    runPausedText = "";
                                    runExtraText = ""
                                    runCoordinator.resetPause()
                                }) {
                                    Image(systemName: "play.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(Color.black)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }.padding().padding()
                                Image(systemName: "stop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .foregroundColor(Color.black)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .onLongPressGesture(minimumDuration: 60){
                                        RunCoordinator.shared.stopAndResetRun(container: container);
                                    } onPressingChanged: { isPressing in
                                        self.stopButtonPressed = isPressing;
                                        if(isPressing == false){
                                            circleTrim = 1;
                                        }
                                    }
                                    .mask(){
                                        clock(circleTrim).frame(width: 100, height: 100)
                                    }
                                    .padding()
                                    .padding()
                                Spacer();
                            }.frame(alignment: .center)
                        }
                        Spacer()
                    }
                }
            }
        }.onReceive(timer) { timer in
            if stopButtonPressed {
                withAnimation(.linear) {
                    circleTrim -= 0.075;
                }
            }
            if(circleTrim <= -0.3){
                RunCoordinator.shared.stopAndResetRun(container: container);
            }
        }
    }
    func clock(_ value: Double) -> some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .inset(by: proxy.size.width / 4)
                    .trim(from: 0, to: value)
                    .stroke(.white, style: StrokeStyle(lineWidth: proxy.size.width / 2))
                    .rotationEffect(.radians(-.pi/2))
                    .animation(.linear, value: value)
            }
        }
    }
}


