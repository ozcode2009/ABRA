//
//  PreviousRunView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/27/24.
//

import Foundation
import SwiftUI
import SwiftData
import MapKit
import Charts
import BottomSheet

struct PreviousRunView: View{
    let run: RunData;
    @Environment(\.dismiss) var dismiss
    @State var isPresented = true;
    @State var bottomSheetPosition: BottomSheetPosition = .absolute(415)
    @State var tabBarHeight: CGFloat = 83;
    @State var geoHeight: CGFloat = 25;
    @State var paceGraphView: Bool = false;
    @State var lineAnnotationIndex: Int = 0;
    @State var graphHover: Bool = false;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    
    var btnBack: some View { Button(action: {
        dismiss()
    }) {
        Image(systemName: "chevron.backward.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.gray)
            .font(.system(size: 37))
    }
    }
    
    var body: some View{
        ZStack{
            let mapCoordinates = run.getCLLocationCoordinates()
            let distanceMultiplier: Double = (distanceUnit == 0) ? 1.609 : 1
            let distanceDivider: Double = run.getTrackRun() ? 1 : (distanceUnit == 0) ? 1000 : 1609
            let unit = run.getTrackRun() ? "meters" : (distanceUnit == 0) ? "km" : "miles"
            
            ZStack{
                VStack {
                    if run.runCoordinates.count > 0 {
                        Map(initialPosition: MapCameraPosition.camera(MapCamera(centerCoordinate: run.getAverageCoordinate(), distance: 50000)),
                            bounds: MapCameraBounds(centerCoordinateBounds: MKCoordinateRegion(center: run.getAverageCoordinate(), latitudinalMeters: run.getZoomMeters(), longitudinalMeters: run.getZoomMeters()), minimumDistance: 125, maximumDistance: run.getZoomMeters()),
                            interactionModes: .all) {
                            if(graphHover){
                                Annotation(coordinate: run.getPaces()[lineAnnotationIndex].location, anchor: .bottom){
                                    let distanceString = String(format: run.getTrackRun() ? "%.0f " + unit : "%.2f " + unit, run.getPaces()[lineAnnotationIndex].dist * distanceMultiplier)
                                    RoundedRectangle(cornerRadius: 8).foregroundStyle(.ultraThinMaterial)
                                        .offset(y: -20).frame(width: 125, height: 45)
                                        .overlay(Text(distanceString).offset(y: -20));
                                } label: {
                                    
                                }
                                Annotation(coordinate: run.getPaces()[lineAnnotationIndex].location, anchor: .center){
                                    ZStack{
                                        Circle().foregroundStyle(.white).frame(width: 21, height: 21);
                                        Circle().foregroundStyle(.blue).frame(width: 14, height: 14);
                                    }
                                } label: {
                                    
                                }
                            }
                            
                            MapPolyline(coordinates: mapCoordinates)
                                .stroke(.blue, lineWidth: 2);
                        }
                            .mapControlVisibility(.hidden)
                            .ignoresSafeArea()
                    }else{
                        VStack {
                            Spacer()
                            Text("Could not draw map")
                                .font(.callout)
                                .foregroundColor(Color.primary.opacity(0.4))
                            Spacer()
                            Spacer()
                            Spacer()
                        }
                    }
                }
                    .bottomSheet(bottomSheetPosition: $bottomSheetPosition, switchablePositions: [.absolute(tabBarHeight + geoHeight + 17), .absolute(415), .absolute(525)], headerContent:{
                        VStack(alignment: .leading){
                            HStack{
                                if(paceGraphView){
                                    Image(systemName: "chevron.backward.circle.fill")
                                        .resizable()
                                        .scaledToFill()
                                        .foregroundStyle(.gray)
                                        .frame(width: 30, height: 30)
                                        .onTapGesture {
                                            withAnimation{
                                                paceGraphView = false;
                                            }
                                        }
                                }
                                Text(timeOfDay(for: run.runStart) + (run.workout ? " Workout in " : " Run in ") + run.locality).font(.system(size: 28)).bold()
                            }
                            HStack{
                                if(run.getTrackRun()) {
                                    let formattedDist = String(Int(run.runDistanceMeters))
                                    Text(formattedDist + " " + unit).font(.subheadline).foregroundColor(.secondary);
                                } else {
                                    let formattedDist = String(format: "%.2f", run.runDistanceMeters/distanceDivider)
                                    Text(formattedDist + " " + unit).font(.subheadline).foregroundColor(.secondary);
                                }
                                Spacer()
                            }
                            Divider().padding([.trailing])
                        }.padding([.leading]).overlay(
                            GeometryReader { proxy in
                                Text(String())
                                    .onAppear() {
                                        geoHeight = proxy.size.height;
                                    }
                                    .opacity(.zero)
                            }
                        )
                    }) {
                        RunSheetView(run: run, tabBarHeight: $tabBarHeight, paceGraphView: $paceGraphView, lineIndex: $lineAnnotationIndex, showSpecificPace: $graphHover)
                    }.enableSwipeToDismiss(false).enableContentDrag(false)
                    .background(TabBarAccessor { tabBar in
                        tabBarHeight = tabBar.bounds.height;
                    })
                
                
                
            }
        }.toolbarBackground(.hidden, for: .navigationBar).navigationBarBackButtonHidden(true).navigationBarItems(leading: btnBack).toolbarBackground(.visible, for: .tabBar)
        
    }
    func timeOfDay(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 4..<12:
            return "Morning"
        case 12..<17:
            return "Afternoon"
        case 17..<21:
            return "Evening"
        default:
            return "Night"
        }
    }
}

struct RunSheetView: View {
    let run: RunData;
    let fontSize: CGFloat = 34;
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context;
    @Query var runs: [RunData];
    @Binding var tabBarHeight: CGFloat;
    @Binding var paceGraphView: Bool;
    @Binding var lineIndex: Int;
    @Binding var showSpecificPace: Bool;
    @State private var offsetX: Double = 0.0

    var body: some View {
        VStack{
            if(!paceGraphView){
                ScrollView{
                    VStack{
                        HStack{
                            Spacer()
                            FinishedAvgPaceView(run: run, fontSize: fontSize)
                            Spacer();
                            PaceGraphView(run: run, fontSize: fontSize).onTapGesture {
                                withAnimation {
                                    paceGraphView = true;
                                }
                            }.disabled(run.downloadedRunPace != 0.0);
                            Spacer();
                        }
                                .frame(width: 350, height: 100).background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .foregroundStyle(Color.blue.opacity(0.1)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(interpolateRunColor(runDistance: run.runDistanceMeters), lineWidth: 4)
                                )
                                .padding([.top])
                        HStack{
                            Spacer()
                            CalView(run: run, fontSize: fontSize)
                            Spacer();
                            FinishedTimeView(run: run, fontSize: fontSize)
                            Spacer()
                        }
                        .frame(width: 350, height: 100).background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .foregroundStyle(Color.blue.opacity(0.1)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(interpolateRunColor(runDistance: run.runDistanceMeters), lineWidth: 4)
                        )
                        .padding([.top, .bottom])
                        
                        HStack{
                            Spacer();
                            MileView(run: run, fontSize: fontSize);
                            Spacer();
                            DateView(run: run, fontSize: fontSize);
                            Spacer();
                        }
                        .frame(width: 350, height: 100).background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(interpolateRunColor(runDistance: run.runDistanceMeters), lineWidth: 4)
                            )
                            .foregroundStyle(Color.blue.opacity(0.1))).padding([.bottom])
                        if(run.getTrackRun()){
                            TrackPaceDisplay(run: run)
                        }else {
                            PaceDisplay(run: run, paces: run.calculatePacesPerMile(coordinates: run.runCoordinates))
                        }
                        Button {
                            Task {
                                await deleteRun(runTime: Int64(floor(run.runStart.timeIntervalSince1970)))
                                DispatchQueue.main.async {
                                    context.delete(run)
                                    do {
                                        try context.save()
                                        dismiss()
                                    }catch{
                                    }
                                }
                            }
                        } label: {
                            ZStack {
                                Text("Delete Run")
                                    .bold()
                                    .foregroundStyle(Color.white)
                                    .frame(height: 50)
                                    .frame(maxWidth: .infinity)
                                    .background(.red)
                                    .cornerRadius(14)
                                    .padding([.leading, .trailing, .bottom])
                            }
                        }
                    }
                    
                }
            }else{
                ScrollView{
                    VStack{
                        HStack{
                            Spacer()
                            FinishedAvgPaceView(run: run, fontSize: fontSize);
                            Spacer();
                            SpecificPaceView(run: run, fontSize: fontSize, paceIndex: $lineIndex, paces: run.getPaces())
                            Spacer();
                        }
                        .frame(width: 350, height: 100).background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .foregroundStyle(Color.blue.opacity(0.1)))
                        .padding([.top])
                        VStack{
                            Chart(run.getPaces()) {
                                    LineMark(
                                        x: .value("Time", $0.paceDate),
                                        y: .value("Pace", $0.pace)
                                    )
                            }
                            .chartXAxis(.hidden)
                            .frame(width: 325, height: 200)
                            .chartOverlay { proxy in
                                GeometryReader { geoProxy in
                                    let data = run.getPaces();
                                
                                    Rectangle()
                                        .foregroundStyle(Color.orange.gradient)
                                        .frame(width: 2, height: geoProxy.size.height * 0.85)
                                        .offset(x: max(min(offsetX, geoProxy.size.width - 18), 0), y: (geoProxy.size.height * 0.15))
                                        .opacity(showSpecificPace ? 1.0 : 0.0)
    
                                    VStack(spacing: 0) {
                                        if(data.count > 1){
                                            Text("\(run.getRunElapsedTimeString(date: data[lineIndex].paceDate))")
                                        }else{
                                            Text("0:00");
                                        }
                                    }
                                    .frame(width: 68, height: 23)
                                    .offset(x: max(min(offsetX, geoProxy.size.width - 18), 0) - 34)
                                    .opacity(showSpecificPace ? 1.0 : 0.0)
                                

                                    Rectangle().fill(.clear).contentShape(Rectangle()).gesture(DragGesture()
                                        .onChanged { value in
                                            if(data.count < 1){
                                                return;
                                            }
                                            let origin = geoProxy[proxy.plotFrame!].origin
                                            let location = CGPoint(
                                                x: value.location.x - origin.x,
                                                y: value.location.y - origin.y
                                            )
                                            offsetX = location.x;
                                            let (year, _) = proxy.value(at: location, as: (Date, Double).self) ?? (Date(), 0)
                                            
                                            var closestIndex = 0
                                            let targetTime = year.millisecondsSince1970
                                            var smallestDifference = abs(data[0].paceDate.millisecondsSince1970 - targetTime)
                                            
                                            for (index, pace) in data.enumerated() {
                                                let paceTime = pace.paceDate.millisecondsSince1970
                                                let difference = abs(paceTime - targetTime)
                                                
                                                if difference < smallestDifference {
                                                    closestIndex = index
                                                    smallestDifference = difference
                                                }
                                            }
                                            lineIndex = closestIndex
                                            showSpecificPace = true;
                                        }
                                        .onEnded { _ in
                                            showSpecificPace = false;
                                        }
                                    )
                                }
                            }
                            .chartOverlay{_ in
                                if(run.runDistanceMeters == 0){
                                    Text("No Data").foregroundStyle(.secondary).font(.system(size: 37))
                                }
                            }
                        }
                        .frame(width: 350, height: 225).background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .foregroundStyle(.ultraThickMaterial))
                        
                    }
                }
            }
            Spacer().frame(width: .infinity, height: tabBarHeight)
        }.transition(.slide)
    }
    func interpolateRunColor(runDistance: Double) -> Color {
        let shortColor = Color(hex: 0x04da0d)
        let mediumColor = Color(hex: 0x96959b)
        let longColor = Color(hex: 0xdf4159)
        
        let recentRuns = runs.suffix(10);
        let averageDistance = recentRuns.map(\.runDistanceMeters).reduce(0, +) / Double(recentRuns.count)
        guard averageDistance > 0 else { return mediumColor }

        let normalized = runDistance / averageDistance

        let shortThreshold = 0.5
        let longThreshold = 2.0

        if normalized <= shortThreshold {
            return shortColor
        } else if normalized >= longThreshold {
            return longColor
        } else if normalized == 1.0 {
            return mediumColor
        } else {
            if normalized < 1.0 {
                let t = (normalized - shortThreshold) / (1.0 - shortThreshold)
                return blendColors(color1: shortColor, color2: mediumColor, t: t)
            } else {
                let t = (normalized - 1.0) / (longThreshold - 1.0)
                return blendColors(color1: mediumColor, color2: longColor, t: t)
            }
        }
    }

    func blendColors(color1: Color, color2: Color, t: Double) -> Color {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = CGFloat((1 - t)) * r1 + CGFloat(t) * r2
        let g = CGFloat((1 - t)) * g1 + CGFloat(t) * g2
        let b = CGFloat((1 - t)) * b1 + CGFloat(t) * b2
        let a = CGFloat((1 - t)) * a1 + CGFloat(t) * a2

        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
}

struct PaceDisplay: View {
    let run: RunData
    let paces: [Double]
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(paces.enumerated()), id: \.offset) { index, pace in
                if(((index == paces.count - 1) ? ((distanceUnit == 0) ? (run.runDistanceMeters / 1000) : (run.runDistanceMeters / 1609)).truncatingRemainder(dividingBy: 1) : Double(index + 1)) > 0.01){
                    PaceRow(mile: (index == paces.count - 1) ? ((distanceUnit == 0) ? (run.runDistanceMeters / 1000) : (run.runDistanceMeters / 1609)).truncatingRemainder(dividingBy: 1) : Double(index + 1), pace: pace)
                }
            }
        }
        .padding().padding(.top)
    }
}

struct TrackPaceDisplay: View {
    let run: RunData
    
    private func groupPaces(_ paces: [identifiablePace]) -> [GroupedPace] {
        var groupedPaces: [GroupedPace] = []
        var currentGroup: [identifiablePace] = []
        
        for pace in paces {
            if pace.rest {
                if !currentGroup.isEmpty {
                    groupedPaces.append(GroupedPace(paces: currentGroup))
                    currentGroup = []
                }
                groupedPaces.append(GroupedPace(paces: [pace]))
            } else {
                currentGroup.append(pace)
            }
        }
        
        if !currentGroup.isEmpty {
            groupedPaces.append(GroupedPace(paces: currentGroup))
        }
        
        return groupedPaces
    }
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(groupPaces(run.getFullTrackPaces())) { groupedPace in
                if groupedPace.paces.count == 1 && groupedPace.paces[0].rest {
                    PaceRow(
                        mile: groupedPace.paces[0].dist,
                        pace: groupedPace.paces[0].restPace,
                        track: true,
                        rest: true
                    )
                } else {
                    PaceRow(
                        mile: groupedPace.totalDistance,
                        pace: groupedPace.averagePace,
                        track: true,
                        rest: false
                    )
                }
            }
        }
        .padding().padding(.top)
    }
}

struct GroupedPace: Identifiable {
    let id = UUID()
    let paces: [identifiablePace]
    
    var totalDistance: Double {
        return Double(paces.count * 100)
    }
    
    var averagePace: Double {
        let totalPace = paces.reduce(0) { $0 + $1.restPace }
        return totalPace
    }
}
struct PaceRow: View {
    let mile:  Double
    let pace:  Double
    var track: Bool = false;
    var rest:  Bool = false;
    
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    var body: some View {
        Capsule()
            .fill(Color.blue.opacity(0.1))
            .overlay(
                HStack {
                    let unit = (distanceUnit == 0) ? "Kilometer" : "Mile"
                    if(track){
                        if(rest) {
                            Text("Rest")
                                .font(.headline)
                                .padding(.leading)
                        }else{
                            Text("\(String(format: "%.0f", mile))m")
                                .font(.headline)
                                .padding(.leading)
                        }
                    }else {
                        Text("\(unit) \(String(format: mile.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f", mile))")
                                .font(.headline)
                                .padding(.leading)
                    }
                    Spacer()
                    Text(formattedPace)
                        .font(.subheadline)
                        .padding(.trailing)
                }
            )
            .frame(height: 50)
    }
    
    var formattedPace: String {
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


struct TabBarAccessor: UIViewControllerRepresentable {
    var callback: (UITabBar) -> Void
    private let proxyController = ViewController()
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<TabBarAccessor>) ->
    UIViewController {
        proxyController.callback = callback
        return proxyController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: UIViewControllerRepresentableContext<TabBarAccessor>) {
    }
    
    typealias UIViewControllerType = UIViewController
    
    private class ViewController: UIViewController {
        var callback: (UITabBar) -> Void = { _ in }
        
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if let tabBar = self.tabBarController {
                self.callback(tabBar.tabBar)
            }
        }
    }
}


