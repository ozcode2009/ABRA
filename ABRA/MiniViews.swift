//
//  MiniViews.swift
//  ABRA
//
//  Created by Oliver Crumrine on 6/19/24.
//

import Foundation
import SwiftUI
import PhotosUI

struct FinishedAvgPaceView: View {
    let run: RunData;
    let fontSize: CGFloat;
    @State private var paceMultiplier: Int = 4;
    var body: some View {
        VStack{
            let seconds = (run.downloadedRunPace == 0) ? (run.getAveragePace() * (run.getTrackRun() ? Double(paceMultiplier) : 1)).truncatingRemainder(dividingBy: 60) : run.downloadedRunPace.truncatingRemainder(dividingBy: 60);
            let minutes = (((run.downloadedRunPace == 0) ? run.getAveragePace() * (run.getTrackRun() ? Double(paceMultiplier) : 1) : run.downloadedRunPace) - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            if(run.getTrackRun()){
                Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 13)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            if(!run.getTrackRun()){
                Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }else {
                PaceSelectorDropDown(paceMultiplier: $paceMultiplier).frame(height: 18).padding(.top, -18)
            }
        }
        .frame(width: 125)
    }
}
struct MiniFinishedAvgPaceView: View {
    let run: RunData;
    let fontSize: CGFloat;
    @State private var paceMultiplier: Int = 4;
    var body: some View {
        VStack{
            let seconds = (run.downloadedRunPace == 0) ? (run.getAveragePace() * (run.getTrackRun() ? Double(paceMultiplier) : 1)).truncatingRemainder(dividingBy: 60) : run.downloadedRunPace.truncatingRemainder(dividingBy: 60);
            let minutes = (((run.downloadedRunPace == 0) ? run.getAveragePace() * (run.getTrackRun() ? Double(paceMultiplier) : 1) : run.downloadedRunPace) - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            if(run.getTrackRun()){
                Text("400m avg").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }else {
                Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }
        }
        .frame(width: 70)
    }
}
struct GroupMiniFinishedAvgPaceView: View {
    let group: GroupData;
    let statsType: Int;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            let groupStats = calculateGroupStats(userRuns: group.userRuns, type: statsType)
            let distanceMultiplier: Float = (distanceUnit == 0) ? 1.609 : 1;
            let pace = groupStats.averagePace / distanceMultiplier;
            let seconds = pace.truncatingRemainder(dividingBy: 60);
            let minutes = (pace - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 70)
    }
}
struct UserMiniFinishedAvgPaceView: View {
    let userRun: Run;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            let distanceMultiplier: Float = (distanceUnit == 0) ? 1.609 : 1;
            let pace = userRun.avgPace / distanceMultiplier;
            let seconds = pace.truncatingRemainder(dividingBy: 60);
            let minutes = (pace - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 70)
    }
}
struct AvgPaceView: View {
    let fontSize: CGFloat;
    var avgPace: Double;
    var run: RunData
    @State private var paceMultiplier: Int = 4;
    var body: some View {
        VStack{
            let seconds = (avgPace * (run.getTrackRun() ? Double(paceMultiplier) : 1)).truncatingRemainder(dividingBy: 60)
            let minutes = ((avgPace * (run.getTrackRun() ? Double(paceMultiplier) : 1)) - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String =  String(format: "%02d", Int(seconds));
            if(run.getTrackRun()){
                Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 13)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            if(run.getTrackRun()){
                PaceSelectorDropDown(paceMultiplier: $paceMultiplier).frame(height: 18).padding(.top, -18)
            }else{
                Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }
        }
        .frame(width: 90)
    }
}
struct DarkAvgPaceView: View {
    let fontSize: CGFloat;
    var avgPace: Double;
    var run: RunData
    @State private var paceMultiplier: Int = 4;
    var body: some View {
        VStack{
            let seconds = (avgPace * (run.getTrackRun() ? Double(paceMultiplier) : 1)).truncatingRemainder(dividingBy: 60)
            let minutes = ((avgPace * (run.getTrackRun() ? Double(paceMultiplier) : 1)) - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String =  String(format: "%02d", Int(seconds));
            if(run.getTrackRun()){
                Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 13)).lineLimit(1).minimumScaleFactor(0.35);
            }
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            if(run.getTrackRun()){
                PaceSelectorDropDown(paceMultiplier: $paceMultiplier).frame(height: 18).padding(.top, -18)
            }else{
                Text("avg pace").font(Font.custom("HelveticaNeue-Bold", size: 18)).lineLimit(1).minimumScaleFactor(0.35);
            }
        }
        .frame(width: 90)
    }
}
struct SpecificPaceView: View {
    let run: RunData;
    let fontSize: CGFloat;
    @Binding var paceIndex: Int;
    @State private var paceMultiplier = 4;
    let paces: [identifiablePace];
    var body: some View {
        VStack{
            if(paces.count > 0){
                let specificPace = paces[paceIndex].pace;
                let truePace = specificPace * (run.getTrackRun() ? Double(paceMultiplier) : 60);
                let seconds = truePace.truncatingRemainder(dividingBy: 60);
                let minutes = (truePace - seconds) / 60;
                let formattedMin = String(format: "%.0f", minutes)
                let formattedSec: String = String(format: "%02d", Int(seconds));
                if(run.getTrackRun()){
                    Text("sel pace").font(Font.custom("HelveticaNeue-Bold", size: 13)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
                }
                Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1);
            }else{
                Text("0" + ":" + "00").font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            }
            if(run.getTrackRun()) {
                PaceSelectorDropDown(paceMultiplier: $paceMultiplier).frame(height: 18).padding(.top, -18)
            }else {
                Text("sel pace").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }
        }
        .frame(width: 125)
    }
}
struct CurrentPaceView: View {
    let fontSize: CGFloat;
    var pace: Double;
    var run: RunData
    @State private var paceMultiplier: Int = 4;
    var body: some View {
        VStack{
            let seconds = (pace * (run.getTrackRun() ? Double(paceMultiplier) : 1)).truncatingRemainder(dividingBy: 60)
            let minutes = ((pace * (run.getTrackRun() ? Double(paceMultiplier) : 1)) - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            if(run.getTrackRun()){
                Text("pace").font(Font.custom("HelveticaNeue-Bold", size: 13)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            if(run.getTrackRun()){
                PaceSelectorDropDown(paceMultiplier: $paceMultiplier).frame(height: 18).padding(.top, -18)
            }else {
                Text("pace").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            }
        }
        .frame(width: 90)
    }
}
struct PaceGraphView: View {
    let run: RunData;
    let fontSize: CGFloat;
    var body: some View {
        VStack{
            Image(systemName: "chart.bar.fill")
                .font(.system(size: fontSize))
                .fontWeight(.bold)
                .foregroundStyle(.blue)
                .foregroundStyle(.blue)
            Text("pace graph").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35).foregroundStyle(.accent);
        }
        
        .frame(width: 125)
    }
}
struct MileView: View{
    let run: RunData;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            let distanceDivider: Double = run.getTrackRun() ? 1 : (distanceUnit == 0) ? 1000.0 : 1609.0
            let unit = run.getTrackRun() ? "meters" : (distanceUnit == 0) ? "km" : "miles"
            let formattedDist = String(format: run.getTrackRun() ? "%.0f" : "%.2f", run.runDistanceMeters/distanceDivider)
            Text(formattedDist).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
            Text(unit).font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 90)
    }
}
struct DarkMileView: View{
    let run: RunData;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            let distanceDivider: Double = run.getTrackRun() ? 1 : (distanceUnit == 0) ? 1000.0 : 1609.0
            let unit = run.getTrackRun() ? "meters" : (distanceUnit == 0) ? "km" : "miles"
            let formattedDist = String(format: run.getTrackRun() ? "%.0f" : "%.2f", run.runDistanceMeters/distanceDivider)
            Text(formattedDist).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
            Text(unit).font(Font.custom("HelveticaNeue-Bold", size: 18)).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 90)
    }
}
struct MiniMileView: View{
    let run: RunData;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            let distanceDivider: Double = run.getTrackRun() ? 1 : (distanceUnit == 0) ? 1000.0 : 1609.0
            let unit = run.getTrackRun() ? "meters" : (distanceUnit == 0) ? "km" : "miles"
            let formattedDist = String(format: run.getTrackRun() ? "%.0f" : "%.2f", (run.workout ? run.getWorkoutDistance().reduce (0, {x,y in x+y}) : run.runDistanceMeters)/distanceDivider)
            Text(formattedDist).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
            Text(unit).font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 70)
    }
}
struct GroupMiniMileView: View{
    let group: GroupData;
    let statsType: Int;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            let distanceMultiplier: Float = (distanceUnit == 0) ? 1.609 : 1
            let unit = (distanceUnit == 0) ? "km" : "miles"
            let groupStats = calculateGroupStats(userRuns: group.userRuns, type: statsType)
            let formattedDist = String(format: "%.2f", groupStats.totalDistance * distanceMultiplier)
            Text(formattedDist).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
            Text(unit).font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 70)
    }
}
struct UserMiniMileView: View{
    let userRun: Run;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            let distanceMultiplier: Float = (distanceUnit == 0) ? 1.609 : 1
            let unit = (distanceUnit == 0) ? "km" : "miles"
            let formattedDist = String(format: "%.2f", userRun.distance * distanceMultiplier)
            Text(formattedDist).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
            Text(unit).font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 70)
    }
}
struct DateView: View{
    let run: RunData;
    let fontSize: CGFloat;
    var body: some View {
        VStack{
            Text(run.runStart.formatted(date: .omitted, time: .shortened).lowercased()).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
            Text("on " + run.runStart.formatted(date: .abbreviated, time: .omitted)).font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 180)
    }
}
struct FinishedTimeView: View {
    let run: RunData;
    let fontSize: CGFloat;
    var body: some View {
        VStack{
            Text(run.getFinishedRunElapsedTimeString()).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35).minimumScaleFactor(0.35);
            Text("time").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 135)
    }
}
struct MiniFinishedTimeView: View {
    let run: RunData;
    let fontSize: CGFloat;
    var body: some View {
        VStack{
            Text(run.getFinishedRunElapsedTimeString()).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            Text("time").font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 140)
    }
}
struct GroupMiniFinishedTimeView: View {
    let group: GroupData;
    let statsType: Int;
    let fontSize: CGFloat;
    var body: some View {
        VStack{
            let groupStats = calculateGroupStats(userRuns: group.userRuns, type: statsType);
            Text(getFinishedRunElapsedTimeString(time: groupStats.totalTime)).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            Text("time").font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 140)
    }
    func getFinishedRunElapsedTimeString(time: Float) -> String{
        if(time < 3600){
            let seconds = time.truncatingRemainder(dividingBy: 60);
            let minutes = (time - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            return formattedMin + ":" + formattedSec;
        }else{
            let seconds = time.truncatingRemainder(dividingBy: 60);
            let minutes = (time - seconds) / 60;
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
}
struct UserMiniFinishedTimeView: View {
    let userRun: Run;
    let fontSize: CGFloat;
    var body: some View {
        VStack{
            Text(getFinishedRunElapsedTimeString(time: userRun.time)).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            Text("time").font(Font.custom("HelveticaNeue-Bold", size: 15)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 140)
    }
    func getFinishedRunElapsedTimeString(time: Float) -> String{
        if(time < 3600){
            let seconds = time.truncatingRemainder(dividingBy: 60);
            let minutes = (time - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String = String(format: "%02d", Int(seconds));
            return formattedMin + ":" + formattedSec;
        }else{
            let seconds = time.truncatingRemainder(dividingBy: 60);
            let minutes = (time - seconds) / 60;
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

}
struct TimeView: View {
    let fontSize: CGFloat;
    let runElapsedTimeString: String;
    var body: some View {
        VStack{
            Text(runElapsedTimeString).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            Text("time").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 135)
    }
}
struct CalView: View {
    let run: RunData;
    let fontSize: CGFloat;
    @AppStorage("weight") private var selectedWeight: Double = 150
    @AppStorage("weightUnit") private var weightUnit = 0
    @Environment(\.modelContext) private var context
    var body: some View {
        VStack{
            if(run.runCalories != 0){
                Text(String(run.runCalories)).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            }else{
                let calories = (run.runDistanceMeters / 1000) * ((weightUnit == 0) ? selectedWeight : (selectedWeight / 2.205)) * 1.032;
                Text(String(Int(calories))).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            }
            Text("cal").font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 135)
        .onAppear(){
            if(run.runCalories == 0){
                let calories = (run.runDistanceMeters / 1000) * ((weightUnit == 0) ? selectedWeight : (selectedWeight / 2.205)) * 1.032;
                run.runCalories = Int(calories)
            }
        }
    }
}

struct TinyRunView: View{
    let run: RunData
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack{
            Text(run.runStart.formatted(date: .abbreviated, time: .omitted)).font(Font.custom("HelveticaNeue-Bold", size: 12)).fontWeight(.bold)
            HStack{
                let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
                let unit = (distanceUnit == 0) ? "km" : "mi"
                let formattedDist = String(format: "%.2f", run.runDistanceMeters/distanceDivider)
                Text(formattedDist + unit).font(.system(size: 12)).minimumScaleFactor(0.35);
                let seconds = run.getAveragePace().truncatingRemainder(dividingBy: 60);
                let minutes = (run.getAveragePace() - seconds) / 60;
                let formattedMin = String(format: "%.0f", minutes)
                let formattedSec: String = String(format: "%02d", Int(seconds));
                Text(formattedMin + ":" + formattedSec + "/" + unit).font(.system(size: 12)).minimumScaleFactor(0.35);
            }
        }.frame(width: 115, height: 40).clipShape(RoundedRectangle(cornerRadius: 9)).foregroundStyle(.blue).background(Color(.systemBackground))
    }
}

struct TinyMultiRunView: View{
    let groupWeeklyStats: GroupData
    let year: Int
    let month: Int
    let day: Int
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        let date = getRunDate(year: year, month: month, day: day)
        let userLongestRuns = getUsersLongestRunsForDay(groupStats: groupWeeklyStats, date: date)
        let distanceMultiplier: Float = (distanceUnit == 0) ? 1.609 : 1
        let unit = (distanceUnit == 0) ? "km" : "mi"
        if(userLongestRuns.count > 1){
            ScrollView {
                VStack {
                    ForEach(userLongestRuns, id: \.username) {userLongestRun in
                        VStack{
                            Text(Date(timeIntervalSince1970: TimeInterval(userLongestRun.longestRun.startTime)).formatted(date: .abbreviated, time: .omitted)).font(Font.custom("HelveticaNeue-Bold", size: 12)).fontWeight(.bold).minimumScaleFactor(0.35);
                            Text(userLongestRun.username).font(Font.custom("HelveticaNeue-Bold", size: 12)).fontWeight(.bold).minimumScaleFactor(0.35);
                            HStack{
                                let formattedDist = String(format: "%.2f", userLongestRun.longestRun.distance * distanceMultiplier)
                                Text(formattedDist + unit).font(.system(size: 12)).minimumScaleFactor(0.35);
                                let pace = userLongestRun.longestRun.avgPace / distanceMultiplier;
                                let seconds = pace.truncatingRemainder(dividingBy: 60);
                                let minutes = (pace - seconds) / 60;
                                let formattedMin = String(format: "%.0f", minutes)
                                let formattedSec: String = String(format: "%02d", Int(seconds));
                                Text(formattedMin + ":" + formattedSec + "/" + unit).font(.system(size: 12)).minimumScaleFactor(0.35);
                            }
                                Divider()
                            
                        }
                    }
                }
            }.frame(width: 115, height: 75).clipShape(RoundedRectangle(cornerRadius: 9)).background(Color(.systemBackground)).scrollBounceBehavior(.basedOnSize)
        }else{
            VStack{
                Spacer()
                ForEach(userLongestRuns, id: \.username) {userLongestRun in
                    VStack{
                        Text(Date(timeIntervalSince1970: TimeInterval(userLongestRun.longestRun.startTime)).formatted(date: .abbreviated, time: .omitted)).font(Font.custom("HelveticaNeue-Bold", size: 12)).fontWeight(.bold).minimumScaleFactor(0.35);
                        Text(userLongestRun.username).font(Font.custom("HelveticaNeue-Bold", size: 12)).fontWeight(.bold).minimumScaleFactor(0.35);
                        HStack{
                            let formattedDist = String(format: "%.2f", userLongestRun.longestRun.distance * distanceMultiplier)
                            Text(formattedDist + unit).font(.system(size: 12)).minimumScaleFactor(0.35);
                            let pace = userLongestRun.longestRun.avgPace / distanceMultiplier;
                            let seconds = pace.truncatingRemainder(dividingBy: 60);
                            let minutes = (pace - seconds) / 60;
                            let formattedMin = String(format: "%.0f", minutes)
                            let formattedSec: String = String(format: "%02d", Int(seconds));
                            Text(formattedMin + ":" + formattedSec + "/" + unit).font(.system(size: 12)).minimumScaleFactor(0.35);
                        }
                    }
                }
                Spacer()
            }.frame(width: 115, height: 75).clipShape(RoundedRectangle(cornerRadius: 9)).background(Color(.systemBackground))
        }
    }
    func getRunDate(year: Int, month: Int, day: Int) -> Date {
        let runDateComponents = DateComponents(year: year, month: month, day: day)
        let date = Calendar.current.date(from: runDateComponents)
        return date!
    }
}

struct PersonalBestView: View {
    let time: String;
    let title: String;
    let date: String;
    let fontSize: CGFloat;
    var body: some View {
        VStack{
            Text(title).font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            Text(time).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35).minimumScaleFactor(0.35);
            Text(date).font(Font.custom("HelveticaNeue-Bold", size: 18)).foregroundStyle(.gray).lineLimit(1).minimumScaleFactor(0.35);
            
        }
        .frame(width: 135)
    }
}

struct PaceSelectorDropDown: View {
    @Binding var paceMultiplier: Int
    let paces = ["100m", "200m", "400m", "1600m"]
    @State private var selectedOptionIndex = 0
    var body: some View {
        Picker(selection: $paceMultiplier){
            Text("100m").tag(1)
            Text("200m").tag(2)
            Text("400m").tag(4)
            Text("1600m").tag(16)
        }label: {
            Text("Pace")
        }.frame(minWidth: 100)
    }
}
