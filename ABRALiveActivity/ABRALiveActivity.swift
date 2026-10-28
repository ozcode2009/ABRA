//
//  ABRALiveActivityLiveActivity.swift
//  ABRALiveActivity
//
//  Created by Oliver Crumrine on 8/21/24.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct RunLiveData: ActivityAttributes {
    var test = 1;
    public struct ContentState: Codable, Hashable {
        var runDistanceMeters: Double
        var pace: Double
        var elapsedTime: String
    }
}

struct LiveMileView: View{
    let trackRun: Bool;
    let runDistanceMeters: Double;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        VStack {
            let distanceDivider: Double = trackRun ? 1 : (distanceUnit == 0) ? 1000.0 : 1609.0
            let unit = trackRun ? "meters" : (distanceUnit == 0) ? "km" : "miles"
            let formattedDist = String(format: trackRun ? "%.0f" : "%.2f", runDistanceMeters/distanceDivider)
            Text(formattedDist).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).minimumScaleFactor(0.35);
            Text(unit).font(Font.custom("HelveticaNeue-Bold", size: 18)).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 90)
    }
}
struct ExpandedView: View{
    let runDistanceMeters: Double;
    let runTime: String;
    let runPace: Double;
    let fontSize: CGFloat;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        HStack {
            Spacer()
            let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
            let unit = (distanceUnit == 0) ? "km" : "mi"
            let formattedDist = String(format: "%.2f", runDistanceMeters/distanceDivider)
            Text(formattedDist + unit).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold)
            Spacer()
            Text(runTime + "min").font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold)
            Spacer()
            let seconds = runPace.truncatingRemainder(dividingBy: 60)
            let minutes = (runPace - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String =  String(format: "%02d", Int(seconds));
            Text(formattedMin + ":" + formattedSec + "/" + unit).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1)
            Spacer()
        }
        .frame(width: 90)
    }
}
struct LiveTimeView: View {
    let fontSize: CGFloat;
    let runElapsedTimeString: String;
    var body: some View {
        VStack{
            Text(runElapsedTimeString).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
            Text("time").font(Font.custom("HelveticaNeue-Bold", size: 18)).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 135)
    }
}
struct LivePaceView: View {
    let fontSize: CGFloat;
    var avgPace: Double;
    @State private var paceMultiplier: Int = 4;
    var body: some View {
        VStack{
            let seconds = avgPace.truncatingRemainder(dividingBy: 60)
            let minutes = (avgPace - seconds) / 60;
            let formattedMin = String(format: "%.0f", minutes)
            let formattedSec: String =  String(format: "%02d", Int(seconds));
            Text(formattedMin + ":" + formattedSec).font(Font.custom("HelveticaNeue-Bold", size: fontSize)).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.35);
                Text("pace").font(Font.custom("HelveticaNeue-Bold", size: 18)).lineLimit(1).minimumScaleFactor(0.35);
        }
        .frame(width: 90)
    }
}

struct LiveActivityWidget: Widget {
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RunLiveData.self) { context in
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    LiveMileView(trackRun: false, runDistanceMeters: context.state.runDistanceMeters, fontSize: 27)
                    Spacer()
                    LiveTimeView(fontSize: 27, runElapsedTimeString: context.state.elapsedTime);
                    Spacer()
                    LivePaceView(fontSize: 27, avgPace: context.state.pace);
                    Spacer()
                }
                .padding()
                Spacer()
            }
            .activityBackgroundTint(Color(UIColor.systemBackground).opacity(0.5))
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Spacer()
                        let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
                        let unit = (distanceUnit == 0) ? "km" : "mi"
                        let formattedDist = String(format: "%.2f", context.state.runDistanceMeters/distanceDivider)
                        Text(formattedDist + unit).font(Font.custom("HelveticaNeue-Bold", size: 20)).fontWeight(.bold)
                        Spacer()
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    HStack {
                        Spacer()
                        let unit = (distanceUnit == 0) ? "km" : "mi"
                        let seconds = context.state.pace.truncatingRemainder(dividingBy: 60)
                        let minutes = (context.state.pace - seconds) / 60;
                        let formattedMin = String(format: "%.0f", minutes)
                        let formattedSec: String =  String(format: "%02d", Int(seconds));
                        Text(formattedMin + ":" + formattedSec + "/" + unit).font(Font.custom("HelveticaNeue-Bold", size: 20)).fontWeight(.bold).lineLimit(1)
                        Spacer()
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Spacer()
                        Text(context.state.elapsedTime + " time").font(Font.custom("HelveticaNeue-Bold", size: 20)).fontWeight(.bold)
                        Spacer()
                    }
                    
                }
            } compactLeading: {
                let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
                let unit = (distanceUnit == 0) ? "km" : "mi"
                let formattedDist = String(format: "%.2f", context.state.runDistanceMeters/distanceDivider)
                Text(formattedDist + unit).font(Font.custom("HelveticaNeue-Bold", size: 14)).fontWeight(.bold)
            } compactTrailing: {
                let unit = (distanceUnit == 0) ? "km" : "mi"
                let seconds = context.state.pace.truncatingRemainder(dividingBy: 60)
                let minutes = (context.state.pace - seconds) / 60;
                let formattedMin = String(format: "%.0f", minutes)
                let formattedSec: String =  String(format: "%02d", Int(seconds));
                Text(formattedMin + ":" + formattedSec + "/" + unit).font(Font.custom("HelveticaNeue-Bold", size: 14)).fontWeight(.bold).lineLimit(1)
            } minimal: {
                let distanceDivider: Double = (distanceUnit == 0) ? 1000.0 : 1609.0
                let unit = (distanceUnit == 0) ? "km" : "mi"
                let formattedDist = String(Int(context.state.runDistanceMeters/distanceDivider))
                Text(formattedDist + unit).font(Font.custom("HelveticaNeue-Bold", size: 11)).fontWeight(.bold)
            }
            .keylineTint(.green)
        }
    }
}

struct LiveActivityWidget_Previews: PreviewProvider {
    static let attributes = RunLiveData()
    static let contentState = RunLiveData.ContentState(runDistanceMeters: 1000.0, pace: 550, elapsedTime: "1:59")
    
    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Island Compact")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Island Expanded")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Notification")
    }
}
