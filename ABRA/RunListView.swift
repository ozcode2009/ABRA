//
//  RunListView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/27/24.
//

import Foundation
import SwiftUI
import SwiftData
import MapKit
import Charts

struct RunListView: View {

    var years: [Int] = [Calendar.current.component(.year, from: Date())];
    
    @State var showableRuns = 5;
    @Query var runs: [RunData];
    @Environment(\.modelContext) private var context;
    @AppStorage("temperatureUnit") private var temperatureUnit: Int = 0;
    @AppStorage("distanceUnit") private var distanceUnit = 1

    var body: some View {
        NavigationStack{
            ScrollView{
                PersonalCoach()
                //One-liner for all of the run charts
                RunChartView(runs: runs, isGroupView: false, groupWeeklyStats: nil)
                VStack {
                    Capsule().fill(
                        LinearGradient(gradient: Gradient(colors: [Color(hex: 0x04da0d), Color(hex: 0x96959b), Color(hex: 0xdf4159)]), startPoint: .leading, endPoint: .trailing)
                    )
                    HStack{
                        Text("SHORTER RUNS").foregroundStyle(.gray).font(.system(size: 12, weight: .light))
                        Spacer()
                        Text("LONGER RUNS").foregroundStyle(.gray).font(.system(size: 12, weight: .light))
                    }
                }.padding()
                ForEach(Array(runs.sorted(by: { $0.runStart > $1.runStart}).enumerated()), id: \.offset) { index, run in
                    if(index < showableRuns) {
                        NavigationLink(destination: PreviousRunView(run: run)){
                                GroupBox(label:
                                            HStack{
                                    VStack(alignment: .leading) {
                                        Text(timeOfDay(for: run.runStart) + (run.workout ? " Workout in " : " Run in ") + run.locality).fontWeight(.bold)
                                        Text(run.runStart.formatted(date: .abbreviated, time: .omitted) + " at " + run.runStart.formatted(date: .omitted, time: .shortened).lowercased()).fontWeight(.regular)
                                    }
                                    Spacer();
                                    if(run.weatherImageString != "") {
                                        HStack{
                                            Spacer()
                                            Image(systemName: run.weatherImageString)
                                                .font(.system(size: 25)).bold()
                                            Spacer()
                                            let temp = (temperatureUnit == 0) ? (run.temperatureF - 32) * 5/9 : run.temperatureF
                                            let unit = (temperatureUnit == 0) ? "C" : "F"
                                            Text(String(format: "%01d", Int(temp)) + "°" + unit)
                                                .font(.system(size: 20)).bold()
                                            Spacer()
                                        }
                                        .frame(width: 120, height: 65).background(RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .foregroundStyle(.ultraThickMaterial))
                                    }
                                }){
                                    VStack{
                                        Divider().padding([.leading, .trailing]).foregroundStyle(.accent)
                                        HStack{
                                            Spacer()
                                            MiniMileView(run: run, fontSize: 26)
                                            Spacer()
                                            MiniFinishedTimeView(run: run, fontSize: 26)
                                            Spacer()
                                            MiniFinishedAvgPaceView(run: run, fontSize: 26)
                                            Spacer()
                                        }
                                    }
                                    
                                }.overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(interpolateRunColor(runDistance: run.runDistanceMeters), lineWidth: 4)
                                ).padding()
                            
                            
                        }.buttonStyle(PlainButtonStyle())
                            .onAppear(){
                                if(!run.runUploaded && run.runCoordinates.count > 0){
                                    Task{
                                        //Attempt to upload the run
                                        var locality = await sendRunAndGetLocality(runDistance: Float(run.runDistanceMeters) / 1609, runPace: Float(run.getAveragePaceMiles()), runTime: Float(run.getFinishedRunElapsedTime()), runStart: Int(run.runStart.timeIntervalSince1970), runStartCoord: run.runCoordinates[0].locationCoordinate())
                                        //Will occur if the server is offline
                                        if(locality.first == "<") {
                                            locality = "Earth"
                                        }
                                        run.locality = locality;
                                        if(locality != "Earth"){
                                            run.runUploaded = true;
                                        }
                                    }
                                    
                                }
                                if(!run.prCalculated){
                                    Task {
                                        await PRManager.shared.updatePRs(with: run)
                                        run.prCalculated = true
                                    }
                                }
                                
                            }
                    }
                }
                Button(action: {
                    if(showableRuns > 85){
                        showableRuns += 1000;
                    }else {
                        showableRuns += 10
                    }
                }) {
                    Text("Show More")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((showableRuns >= runs.count) ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }.disabled(showableRuns >= runs.count)
                    .padding([.leading, .trailing])
                PersonalBestsView()
                HStack{
                    Text("Odometer").font(.system(size: 34)).fontWeight(.black).padding().minimumScaleFactor(0.5).lineLimit(1)
                    Spacer()
                    let unit = (distanceUnit == 0) ? "km" : "mi"
                    let dist = (distanceUnit == 0) ? Int(getTotalDistance(for: runs)/1000) : Int(getTotalDistance(for: runs)/1609)
                    Text(String(dist) + unit).font(.system(size: 34)).fontWeight(.black).padding()
                }
            }
            .navigationTitle("Previous Runs")
            .onAppear() {
                if !RunCoordinator.shared.dontFetchRuns {
                    Task {
                        do {
                            try await updateRunsWithServerData(existingRuns: runs, context: context);
                        } catch {
                        }
                    }
                }
            }
            
        }
        
    }
    func interpolateRunColor(runDistance: Double) -> Color {
        let shortColor = Color(hex: 0x04da0d)
        let mediumColor = Color(hex: 0x96959b)
        let longColor = Color(hex: 0xdf4159)
        
        let recentRuns = runs.suffix(10);
        var totalRunDistance = 0.0
        for run in recentRuns {
            totalRunDistance += run.runDistanceMeters
        }
        let averageDistance = totalRunDistance / Double(recentRuns.count)
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
    
    func getTotalDistance(for runs: [RunData]) -> Double {
        var totalDistance = 0.0
        
        for run in runs {
            totalDistance += run.runDistanceMeters
        }
        
        return totalDistance
    }
}

struct PersonalBestsView: View {
    @AppStorage("personalRecords") private var prData: Data = Data()
    @State private var prs: PersonalRecords = PersonalRecords()
    
    var body: some View {
        GroupBox(label: HStack {
            Text("Personal Bests").fontWeight(.bold)
            Spacer()
        }) {
            VStack {
                Divider().padding([.leading, .trailing]).foregroundStyle(.accent)
                VStack {
                    HStack {
                        Spacer()
                        PersonalBestView(time: getTime(time: prs.mile?.value), title: "1 Mile", date: (prs.mile?.value == 0) ? "-" : prs.mile?.date.formatted(date: .abbreviated, time: .omitted) ?? "-", fontSize: 26)
                        Spacer()
                        PersonalBestView(time: getTime(time: prs.fiveK?.value), title: "5 KM", date: (prs.fiveK?.value == 0) ? "-" : prs.fiveK?.date.formatted(date: .abbreviated, time: .omitted) ?? "-", fontSize: 26)
                        Spacer()
                    }
                    Divider()
                    HStack {
                        Spacer()
                        PersonalBestView(time: getTime(time: prs.halfMarathon?.value), title: "1/2 Marathon", date: (prs.halfMarathon?.value == 0) ? "-" : prs.halfMarathon?.date.formatted(date: .abbreviated, time: .omitted) ?? "-", fontSize: 26)
                        Spacer()
                        PersonalBestView(time: getTime(time: prs.tenK?.value), title: "10 KM", date: (prs.tenK?.value == 0) ? "-" : prs.tenK?.date.formatted(date: .abbreviated, time: .omitted) ?? "-", fontSize: 26)
                        Spacer()
                    }
                    Divider()
                    HStack {
                        Spacer()
                        PersonalBestView(time: getTime(time: prs.marathon?.value), title: "Marathon", date: (prs.marathon?.value == 0) ? "-" : prs.marathon?.date.formatted(date: .abbreviated, time: .omitted) ?? "-", fontSize: 26)
                        Spacer()
                        PersonalBestView(time: String(format: "%.2f", (prs.longestRun?.value ?? 0) / 1609) + "mi", title: "Longest Run", date: (prs.longestRun?.value == 0) ? "-" : prs.longestRun?.date.formatted(date: .abbreviated, time: .omitted) ?? "-", fontSize: 26)
                        Spacer()
                    }
                }
            }
        }.padding()
        .onAppear {
            loadPRs()
        }
    }
    func getTime(time: TimeInterval?) -> String{
        if time == 0.0 {
            return "-"
        }
        guard let runTime = time else{
            return "-"
        }
        if(runTime < 3600){
            let seconds = runTime.truncatingRemainder(dividingBy: 60);
            let minutes = (runTime - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            return formattedMin + ":" + formattedSec;
        }else{
            let seconds = runTime.truncatingRemainder(dividingBy: 60);
            let minutes = (runTime - seconds) / 60;
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
    
    private func loadPRs() {
        if let loadedPRs = try? JSONDecoder().decode(PersonalRecords.self, from: prData) {
            prs = loadedPRs
        }
    }
}

struct GradientOutlinedRectangle<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple, .red]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            content
                .padding()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 135)
        .padding(.horizontal)
    }
}
struct OutlinedRectangle<Content: View>: View {
    let color: Color
    let content: Content
    
    init(color: Color, @ViewBuilder content: () -> Content) {
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            color,
                            lineWidth: 2
                        )
                )
            
            content
        }
        .frame(height: 135)
        .padding(.horizontal)
    }
}
struct PersonalCoach: View {
    @AppStorage("currentCoachPhrase") private var currentCoachPrase: String = "It's time to break in those running shoes!";
    @AppStorage("coachPhraseUpdate") private var coachPhraseUpdate: TimeInterval = 0;
    
    @State private var coachText = "You've been running less than this point last week.";
    
    let sentences = [
        "It's time to break in those running shoes!",
        "Your legs are waiting for a workout!",
        "The road is calling your name!",
        "Your running streak starts now!",
        "Time to put some miles on those legs!",
        "Your running goals are waiting for you!",
        "The trail misses you – get back out there!",
        "Your running shoes are feeling neglected!",
        "Let's make this week count!",
        "A run a day keeps the doctor away!",
        "The finish line is waiting for you!",
        "Time to outrun your excuses!",
        "The only bad workout is the one that didn't happen.",
        "Time to hit the road!",
        "Your running shoes miss you!",
        "The perfect time to run is always now!",
        "Let's make this week better than the last!"
    ]
    func getRandomSentence() -> String {
        return sentences.randomElement() ?? "Time to go for a run!"
    }
    
    let goodSentences = [
        "Your running shoes are getting a good workout!",
        "Your legs are loving the activity!",
        "The road is your second home!",
        "Your running streak is impressive!",
        "You're racking up those miles!",
        "You're crushing your running goals!",
        "The trail is your playground!",
        "Your running shoes are well-loved!",
        "You're making every week count!",
        "Running is clearly part of your routine!",
        "You're no stranger to the finish line!",
        "You're outrunning those excuses!",
        "You're proving that consistency pays off!",
        "The road is your happy place!",
        "Your running shoes are getting plenty of attention!",
        "You're making the most of your running time!",
        "Each week, you're raising the bar!"
    ]

    func getRandomGoodSentence() -> String {
        return goodSentences.randomElement() ?? "You're doing great with your running!"
    }
    
    @Query var runs: [RunData];
    var body: some View {
        GradientOutlinedRectangle {
            Text(getText())
                .multilineTextAlignment(.center)
        }
    }
    
    func getLastWeekTraining() -> Double {
        let calendar = Calendar.current
        let today = Date()
            
        guard let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
                let startOfPreviousWeek = calendar.date(byAdding: .day, value: -7, to: startOfThisWeek),
              let thisTimePreviousWeek = calendar.date(byAdding: .day, value: -7, to: .now),
              let endOfDayLastWeek = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: thisTimePreviousWeek) else {
            return 0;
        }
            
        let lastWeekRuns = runs.filter { run in
            run.runStart >= startOfPreviousWeek && run.runStart <= endOfDayLastWeek
        }
            
        guard !lastWeekRuns.isEmpty else {
            return 0
        }
            
        let totalDistance = lastWeekRuns.reduce(0, { x, y in x + y.runDistanceMeters})
        
        return totalDistance / 1609;
    }
    func getThisWeekTraining() -> Double {
        let calendar = Calendar.current
        let today = Date()

        guard let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let now = calendar.date(byAdding: .day, value: 0, to: .now) else {
            return 0;
        }
            
        let thisWeekRuns = runs.filter { run in
            run.runStart >= startOfThisWeek && run.runStart <= now
        }
            
        guard !thisWeekRuns.isEmpty else {
            return 0
        }
            
        let totalDistance = thisWeekRuns.reduce(0, { x, y in x + y.runDistanceMeters})

        return totalDistance / 1609;
    }
    func getThisWeekNumRuns() -> Int {
        let calendar = Calendar.current
        let today = Date()
            
        guard let startOfThisWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
              let now = calendar.date(byAdding: .day, value: 0, to: .now) else {
            return 0;
        }
            
        let thisWeekRuns = runs.filter { run in
            run.runStart >= startOfThisWeek && run.runStart <= now
        }
        
        return thisWeekRuns.count
    }
    
    func getText() -> String{
        if(getThisWeekNumRuns() < 1) {
            if(!sentences.contains(currentCoachPrase) || coachPhraseUpdate + 3600 < Date().timeIntervalSince1970) {
                currentCoachPrase = getRandomSentence();
                coachPhraseUpdate = Date().timeIntervalSince1970;
                return "You haven't run this week. " + currentCoachPrase
            } else {
                return "You haven't run this week. " + currentCoachPrase
            }
        }
        let percentDifference = getThisWeekTraining() / getLastWeekTraining()
        
        if(percentDifference > 1.2) {
            if(!goodSentences.contains(currentCoachPrase) || coachPhraseUpdate + 3600 < Date().timeIntervalSince1970) {
                currentCoachPrase = getRandomGoodSentence();
                coachPhraseUpdate = Date().timeIntervalSince1970;
                return "You're running more than this point last week. " + currentCoachPrase
            } else {
                return "You're running more than this point last week. " + currentCoachPrase
            }
        }
        if(percentDifference < 0.8){
            if(!sentences.contains(currentCoachPrase) || coachPhraseUpdate + 3600 < Date().timeIntervalSince1970) {
                currentCoachPrase = getRandomSentence();
                coachPhraseUpdate = Date().timeIntervalSince1970;
                return "You're running less than this point last week. " + currentCoachPrase
            } else {
                return "You're running less than this point last week. " + currentCoachPrase
            }
        }
        if(!goodSentences.contains(currentCoachPrase) || coachPhraseUpdate + 3600 < Date().timeIntervalSince1970) {
            currentCoachPrase = getRandomGoodSentence();
            coachPhraseUpdate = Date().timeIntervalSince1970;
            return "You're running about the same as last week. " + currentCoachPrase
        } else {
            return "You're running about the same as last week. " + currentCoachPrase
        }
    }
}

func updateRunsWithServerData(existingRuns: [RunData], context: ModelContext) async throws {
    let serverRuns = try await getRuns()
    
    let existingStartTimes = Set(existingRuns.map { Int($0.runStart.timeIntervalSince1970) })
    
    for serverRun in serverRuns {
        if !existingStartTimes.contains(Int(serverRun.startTime)) {
            let newRun = RunData();
            
            newRun.runStart = Date(timeIntervalSince1970: TimeInterval(serverRun.startTime))
            newRun.runFinish = newRun.runStart.addingTimeInterval(TimeInterval(serverRun.time))
            newRun.runDistanceMeters = Double(serverRun.distance * 1609)
            newRun.locality = serverRun.locality
            newRun.downloadedRunPace = Double(serverRun.avgPace)
            newRun.runUploaded = true

            context.insert(newRun)
        }else{
        }
    }
    
    do {
        try context.save()
    } catch {
        throw error
    }
}

