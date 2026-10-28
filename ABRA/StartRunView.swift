//
//  CurrentRunView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/27/24.
//
import SwiftUI
import SwiftData
import MapKit

struct StartRunView: View{
    @AppStorage("temperatureUnit") private var temperatureUnit: Int = 0;
    @ObservedObject var musicCoordinator           = MusicCoordinator.shared
    @StateObject    var runCoordinator             = RunCoordinator.shared;
    @StateObject    var weatherCoordinator         = WeatherStuff.shared;
    @State private  var settingsViewShown:    Bool = false;
    @State private  var routePlannerShown:    Bool = false;
    @State private  var trackRunPlannerShown: Bool = false;

    
    let modelContainer: ModelContainer
    
    var body: some View{
        ZStack{
            let cameraBounds = MapCameraBounds(centerCoordinateBounds: MKCoordinateRegion(center: runCoordinator.lastCoordinate?.coordinate ?? CLLocationCoordinate2D(), latitudinalMeters: 10000, longitudinalMeters: 10000), minimumDistance: 125, maximumDistance: 10000)
            Map(initialPosition: .userLocation(fallback: .automatic),
                bounds: cameraBounds,
                interactionModes: .all) {
                UserAnnotation();
            }.ignoresSafeArea()
            VStack{
                let glassRectangle = RoundedRectangle(cornerRadius: 20, style: .continuous)
                VStack {
                    HStack {
                        Button {
                            settingsViewShown = true;
                        } label: {
                            VStack {
                                Image(systemName: "gear").resizable().scaledToFit().frame(width: 30, height: 30).foregroundStyle(.gray)
                            }.frame(width: 55, height: 55).background(.ultraThinMaterial, in: glassRectangle).padding(.leading)
                        }
                        Spacer()
                        Button {
                            routePlannerShown = true;
                        } label: {
                            VStack {
                                Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath").resizable().scaledToFit().frame(width: 30, height: 30).foregroundStyle(.gray)
                            }.frame(width: 55, height: 55).background(.ultraThinMaterial, in: glassRectangle).padding(.trailing)
                        }
                    }
                    VStack(spacing: 0){
                        VStack {
                            Spacer()
                            let temp = (temperatureUnit == 0) ? (weatherCoordinator.currentWeather?.temperature.value ?? 0) : (weatherCoordinator.currentWeather?.temperature.value ?? 0) * 9/5 + 32
                            let formattedTemp = String(format: "%.0f", temp)
                            let tempText = "It's " + formattedTemp + " degrees and " + (weatherCoordinator.currentWeather?.condition.description.lowercased() ?? "we don't know")
                            Text(tempText).font(.system(size: 27, weight: .bold)).multilineTextAlignment(.center).padding([.leading, .trailing])
                            Spacer()
                        }
                        Divider()
                        VStack{
                            Spacer()
                            HStack{
                                AsyncImage(url: weatherCoordinator.weatherAttribution?.combinedMarkLightURL, content: { image in
                                    image.image?.resizable().scaledToFit()
                                }).frame(maxWidth: 90, maxHeight: 33).padding(.leading)
                                Spacer()
                                if let legalPageURL = weatherCoordinator.weatherAttribution?.legalPageURL {
                                    Link(destination: legalPageURL){
                                        Text("Weather Data Sources").font(.footnote).padding(.trailing).foregroundStyle(.blue)
                                    }
                                }
                            }
                            Spacer()
                        }.frame(height: 40)
                    }.frame(width: 330, height: 130).background(.ultraThinMaterial, in: glassRectangle).padding()
                }
                Spacer()
                VStack(spacing: 0){
                    VStack {
                        Spacer()
                        Toggle(isOn: $trackRunPlannerShown){
                            Text("Track Run").bold()
                        }.padding(.horizontal)
                        Spacer()
                    }.frame(height: 45)
                    Divider()
                    VStack {
                        Spacer()
                        Text("Ready for " + timeOfDay(for: Date()) + " run?").font(.system(size: 27, weight: .bold)).multilineTextAlignment(.center).padding([.leading, .trailing])
                        Spacer()
                    }
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
                    }.frame(height: 45);
                }.frame(width: 330, height: 175).background(.ultraThinMaterial, in: glassRectangle).padding()
                
                
                Button(action: {
                    if(!RunCoordinator.shared.locationPermitted){
                        RunCoordinator.shared.getLocationStatus(request: true);
                    }
                    if(RunCoordinator.shared.locationPermitted){
                        RunCoordinator.shared.startRun();
                    }
                    
                }){
                    Text("START")
                        .frame(width: 100, height: 60)
                        .foregroundColor(Color(hex: 0xffffff))
                        .background(Color(hex: 0x19B519))
                        .clipShape(Capsule())
                        .font(Font.custom("HelveticaNeue-Bold", size: 20))
                }.padding(.bottom).padding(.bottom)
            }.onAppear(){
                Task{
                    RunCoordinator.shared.locationManager.startUpdatingLocation()
                }
            }
            .sheet(isPresented: $settingsViewShown) { SettingsView(isPresented: $settingsViewShown)}
            .sheet(isPresented: $routePlannerShown) { RouteListView(sheetPresented: $routePlannerShown, modelContainer: modelContainer)}
            .fullScreenCover(isPresented: $trackRunPlannerShown) { TrackPlannerView(presented: $trackRunPlannerShown) }
        }
    }
    func timeOfDay(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        switch hour {
        case 4..<12:
            return "a morning"
        case 12..<17:
            return "an afternoon"
        case 17..<21:
            return "an evening"
        default:
            return "a night"
        }
    }
}


    extension Color {
        init(hex: UInt, alpha: Double = 1) {
            self.init(
                .sRGB,
                red: Double((hex >> 16) & 0xff) / 255,
                green: Double((hex >> 08) & 0xff) / 255,
                blue: Double((hex >> 00) & 0xff) / 255,
                opacity: alpha
            )
        }
        var components: (red: Double, green: Double, blue: Double) {
            let uiColor = UIColor(self)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            return (Double(r), Double(g), Double(b))
        }
    }
    extension View {
        public func gradientForeground(colors: [Color]) -> some View {
            self.overlay(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            )
            .mask(self)
        }
    }

struct SettingsView: View {
    @State private var showDeleteConfirmation = false
    @State private var showPrivacyPolicy = false
    @Binding var isPresented: Bool
    @AppStorage("temperatureUnit") private var temperatureUnit = 1
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    let temperatureUnits = ["Celsius", "Fahrenheit"]
    let distanceUnits = ["Kilometers", "Miles"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    Text("Settings")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(Color.primary.opacity(0.8))
                    VStack(spacing: 20) {
                        VStack(spacing: 20){
                            Button(action: {
                                Task {
                                    await signOut()
                                }
                                UserDefaults.standard.set(false, forKey: "signedIn")
                                isPresented = false
                            }) {
                                Text("Sign Out")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                            }
                            
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Text("Delete My Account")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                            }
                            .alert(isPresented: $showDeleteConfirmation) {
                                Alert(
                                    title: Text("Confirm Account Deletion"),
                                    message: Text("Are you sure you want to delete your account? This action cannot be undone."),
                                    primaryButton: .destructive(Text("Delete")) {
                                        Task {
                                            await deleteAccount()
                                        }
                                        UserDefaults.standard.set(false, forKey: "signedIn")
                                        isPresented = false
                                    },
                                    secondaryButton: .cancel()
                                )
                            }
                            
                            NavigationLink(destination: PrivacyPolicyView()) {
                                Text("View Privacy Policy")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                    .foregroundColor(.blue)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                            }
                            NavigationLink(destination: TermsOfServiceView()) {
                                Text("View Terms of Service")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                    .foregroundColor(.blue)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.blue, lineWidth: 1)
                                    )
                            }
                        }.padding().overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.green, lineWidth: 5)
                        )
                        VStack(spacing: 20) {
                            Text("Units")
                                .font(.headline)
                            Picker("Temperature Unit", selection: $temperatureUnit) {
                                ForEach(0..<temperatureUnits.count, id: \.self) { index in
                                    Text(temperatureUnits[index]).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Picker("Distance Unit", selection: $distanceUnit) {
                                ForEach(0..<distanceUnits.count, id: \.self) { index in
                                    Text(distanceUnits[index]).tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            WeightPicker()
                        }.padding().overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.green, lineWidth: 5)
                        )
                        Text("Thanks to BottomSheet for portions of this software, which are Copyright (c) 2021-2022 Lucas Zischka.").multilineTextAlignment(.center).padding()
                    }
                    .padding()
                    .cornerRadius(35)
                    
                }
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") {
                isPresented = false
            })
        }
    }
}

struct RouteListView: View{
    @Binding var sheetPresented: Bool;
    @Query var routes: [RouteModel];
    @Environment(\.modelContext) private var context
    @AppStorage("distanceUnit") private var distanceUnit = 1
    let modelContainer: ModelContainer
    
    @State private var routeBuilderShown = false;
    @State private var refreshID = UUID()
    
    var body: some View{
        let distanceDivider: Double = (distanceUnit == 0) ? 1000 : 1609;
        let unit = (distanceUnit == 0) ? "km" : "mi"
        HStack {
            Button("Cancel") {
                sheetPresented = false
            }.padding(.leading)
            Spacer()
            Button {
                routeBuilderShown = true
            } label: {
                Image(systemName: "plus")
                    .resizable()
                    .padding(6)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accent)
                
            }.padding(.trailing)
        }.padding(.top)
        VStack{
            ScrollView {
                VStack {
                    Text(routes.isEmpty ? "No Saved Routes" : "Saved Routes")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top)
                        .foregroundColor(Color.primary.opacity(0.8))
                    if(routes.isEmpty){
                        Text("Create a route with the + button")
                            .font(.callout)
                    }
                    ForEach(routes) {route in
                        GroupBox(label:
                                    HStack{
                            Text("Distance: " + String(format: "%.2f", route.routeDistanceMeters/distanceDivider) + unit)
                        }){
                            VStack{
                                Divider().padding([.leading, .trailing])

                                Map(initialPosition: MapCameraPosition.region(route.getZoom())){
                                    let coords = route.coordinates.map { $0.toCLLocationCoordinate() }
                                    if coords.count > 1 {
                                        MapPolyline(coordinates: coords)
                                            .stroke(.blue, lineWidth: 3)
                                    }
                                    ForEach(route.coordinates) { point in
                                        Annotation(coordinate: point.toCLLocationCoordinate(), anchor: .center){
                                                Circle().foregroundStyle(.accent).frame(width: 10, height: 10);
                                        } label: {
                                            
                                        }
                                    }
                                }.disabled(true)
                                .frame(width: 280, height: 280)
                                
                                Button {
                                    RunCoordinator.shared.runRoute = route;
                                    if(!RunCoordinator.shared.locationPermitted){
                                        RunCoordinator.shared.getLocationStatus(request: true);
                                    }
                                    if(RunCoordinator.shared.locationPermitted){
                                        RunCoordinator.shared.startRun();
                                    }
                                } label: {
                                    ZStack {
                                        Text("Start Run with Route")
                                            .bold()
                                            .foregroundStyle(Color.white)
                                            .frame(height: 50)
                                            .frame(maxWidth: .infinity)
                                            .background(.blue)
                                            .cornerRadius(14)
                                            .padding()
                                    }
                                }
                                Button {
                                    context.delete(route)
                                    do {
                                        try context.save()
                                    }catch{
                                    }
                                } label: {
                                    ZStack {
                                        Text("Delete Route")
                                            .bold()
                                            .foregroundStyle(Color.white)
                                            .frame(height: 50)
                                            .frame(maxWidth: .infinity)
                                            .background(.red)
                                            .cornerRadius(14)
                                            .padding([.leading, .trailing])
                                    }
                                }
                            }
                            
                        }.padding()
                    }.id(refreshID)
                }
            }
        }
        .padding()
        .fullScreenCover(isPresented: $routeBuilderShown){ RoutePlannerView(presented: $routeBuilderShown, modelContainer: modelContainer) }
        .onChange(of: routeBuilderShown) {
            refreshID = UUID()
        }
    }
}
struct WeightPicker: View {
    @AppStorage("weight") private var weight = 68.0
    @AppStorage("weightUnit") private var weightUnit = 0
    
    let range = 20...500
    
    var body: some View {
        VStack {
            Text("Select Your Weight")
                .font(.headline)
            
            HStack {
                Picker("Weight", selection: $weight) {
                    ForEach(range, id: \.self) { value in
                        Text("\(value)").tag(Double(value))
                    }
                }
                .pickerStyle(WheelPickerStyle())
                
                Picker("Unit", selection: $weightUnit) {
                    Text("kg").tag(0)
                    Text("lbs").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
        .padding()
    }
}

