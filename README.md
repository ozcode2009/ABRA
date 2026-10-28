# ABRA: A Better Running App
This repository holds the source code for the application ABRA: A Better Running App.
It can be downloaded here on the App Store: https://apps.apple.com/us/app/abra-a-better-running-app/id6499472110

## Architecture
The state of the app is handled by the @StateObject RunCoordinator.shared. The RunCoordinator handles the state of the app, including recieving GPS coordinates and rejecting those which are too close to each other (preventing tiny position changes from accumulating), determining the user's position on a 400m track, handling run pauses, and publishing information such as the current pace to the RunningView and Live Activities

The RunManager is the SwiftData model for the run. It also handles calculation of the current pace, average pace, run distance, etc., as well as the implementation of the Kalman filter for coordinate smoothing.

Runs and logins are sent to the server using methods from CommunicationCoordinator.swift

Communication for the server for running groups is handled in GroupCoordinator.swift

Music and Weather integration is handled in MusicCoordinator.swift and WeatherStuff.swfit respectively

The WorkoutModel and RouteModel are used for storing portions of workouts (eg. separating interval training into time spent running on the track and time spent resting/recovering), and storing run routes respectively

Live Activities are handled in the separate ABRALiveActivity target.

## Views
MainView: Implements the TabView; shows the run overlay if the RunCoordinator indicates a run is currently happening.

RoutePlannerView: Helps the user plan a route. If "Start Run With Route" is selected from the list of available routes, the route will overlay itself onto the user's running screen.

TrackPlanner: Shown as soon as the "Track Run" toggle is set to on, and allows the user to pick 4 coordinates which represent the 100, 200, 300, and 400 meter marks on the track. These are then used by the RunCoordinator to determine the user's position on the 400m track.

GroupListView: Lists the running groups the user is a part of. Allows the user to create and join groups as well.

GroupView: Shows group run data, including leaderboards, group totals, and each group member's run on each day. Allows the user to create an view Upcoming Runs, where groups can coordinate their running schedule.

RunChartView: Shows the user a chart of their runs over time.

SignInView: Allows the user to sign up/in

MiniViews: A collection of views for showing data such as pace, mileage, time, etc.

StartRunView: The screen the user first sees after logging into the app, allowing them to start a run, define a route, see the waether, and adjust their settings

RunningView: The view the user sees while they're running, including route overlays, views for distance and pace, and their current music.

RunListView: Shows a list of the user's previous runs, a motivational phrase, and their run history. Allows users to expand each run into the PreviousRunView, showing more information.

PreviousRunView: Shows detailed data for each run including statistics such as calories, time, miles, average pace, as well as a pace graph.

## Server
The server is built in Rust using Rocket and uses Apache CouchDB.

## Dependencies
The server has many dependencies as laid out in its Cargo.toml

The ABRA iOS app makes use of BottomSheet, licensed under the MIT License:

MIT License

Copyright (c) 2021-2022 Lucas Zischka

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
