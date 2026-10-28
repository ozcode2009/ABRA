//
//  GroupView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/5/24.
//

import SwiftUI

struct GroupView: View {
    let group: GroupData
    @State private var addUserError: Bool = false;
    @State private var addUserPresented: Bool = false;
    @State private var tooManyUsers: Bool = false;
    @State private var userEmail: String = "";
    @State private var sendInvitePresented: Bool = false;
    @State private var runInvites: [RunInvite] = [];
    @State private var addingInProgress: Bool = false;
    @State private var leavingGroup: Bool = false;
    @Environment(\.dismiss) var dismiss
    @Binding var shouldRefreshGroupList: Bool;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    private let yearMonths = [
        YM(name: "Weeks", number: 0),
        YM(name: "Months", number: 1),
        YM(name: "All", number: 2)
    ]
    @State private var yearOrMonthSelected: Int = 0
    var body: some View {
        ScrollView {
            
            GroupBox(label:
                        HStack{
                Text("Upcoming Runs").padding([.top, .leading, .bottom]).bold()
                Spacer()
                Button(action: {
                    sendInvitePresented = true;
                }){
                    Image(systemName: "plus")
                        .resizable()
                        .padding(6)
                        .frame(width: 32, height: 32)
                        .foregroundColor(.accentColor)
                }
            }
            ) {
                ForEach(runInvites) { runInvite in
                    InviteCell(invite: runInvite)
                }
            }.padding([.leading, .trailing])
            RunChartView(runs: sumGroupRunsToRunDataByDay(groupStats: group), isGroupView: true, groupWeeklyStats: group)
            

            
            GroupBox(label: Text("Leaderboard").padding(.bottom)) {
                
                Divider()
                ForEach(group.userRuns, id: \.username) { userRun in
                    NavigationLink(destination: PersonRunView(runs: userRun)){
                        VStack {
                            HStack{
                                let distanceMultiplier: Float = (distanceUnit == 0) ? 1.609 : 1
                                let unit = (distanceUnit == 0) ? "km" : "mi"
                                Text(userRun.username).font(.title3).bold().padding(.leading)
                                Spacer()
                                Text(String(format: "%.2f", sumRunsLastWeek(userRun.runs).totalDistance * distanceMultiplier) + unit + " this week")
                                Image(systemName: "chevron.forward.circle.fill")
                                    .resizable()
                                    .scaledToFill()
                                    .foregroundStyle(.gray)
                                    .frame(width: 20, height: 20)
                                    .padding(.trailing)
                            }.padding([.top, .bottom])
                            Divider()
                        }
                    }.buttonStyle(PlainButtonStyle())
                }
                if(group.group.ownerOrNot != 0) {
                    Button {
                        if group.group.usernames.count >= 4{
                            tooManyUsers = true;
                        }else{
                            addUserPresented = true;
                        }
                    } label: {
                        ZStack {
                            Text("Invite User")
                                .bold()
                                .foregroundStyle(Color.white)
                                .frame(height: 50)
                                .frame(maxWidth: .infinity)
                                .background(.blue)
                                .cornerRadius(14)
                                .padding()
                        }
                    }
                }
            }.padding()
            GroupBox(label:
                        HStack {
                Picker("YM", selection: $yearOrMonthSelected) {
                    ForEach(yearMonths, id: \.number) { ym in
                        Text(ym.name)
                    }
                }.pickerStyle(.segmented)
            } ){
                VStack{
                    Divider()
                    HStack{
                        Text(getGroupStatTitle(type: yearOrMonthSelected) + " Group Totals").font(.title3).padding([.bottom])
                        Spacer()
                    }.padding(.top)
                    HStack{
                        Spacer()
                        GroupMiniMileView(group: group, statsType: yearOrMonthSelected, fontSize: 26)
                        Spacer()
                        GroupMiniFinishedTimeView(group: group, statsType: yearOrMonthSelected, fontSize: 26)
                        Spacer()
                        GroupMiniFinishedAvgPaceView(group: group, statsType: yearOrMonthSelected, fontSize: 26)
                        Spacer()
                    }
                }
                
            }.padding()
            
            Button(action: {
                leavingGroup = true
            }) {
                Text("Leave Group")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding()
            }
            .alert(isPresented: $leavingGroup) {
                Alert(
                    title: Text("Leave This Group?"),
                    message: Text("Are you sure you want to leave this group? If you are the owner, it will be deleted."),
                    primaryButton: .destructive(Text("Delete")) {
                        Task {
                            do {
                                try await leaveGroup(groupId: group.group.groupId)
                                shouldRefreshGroupList = !shouldRefreshGroupList;
                            }catch{
                                
                            }
                        }
                        dismiss()
                    },
                    secondaryButton: .cancel()
                )
            }
        }.sheet(isPresented: $addUserPresented){
            HStack {
                Button("Cancel") {
                    addUserPresented = false
                }.padding(.leading)
                Spacer()
                Button("Add User") {
                    Task {
                        addingInProgress = true
                        let status = await addUserToGroup(email: userEmail, groupId: group.group.groupId)
                        addingInProgress = false
                        if status {
                            addUserPresented = false
                        } else {
                            addUserError = true
                        }
                    }
                }.padding(.trailing)
            }.padding(.top)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Add a User")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)
                            .foregroundColor(Color.primary.opacity(0.8))
                        
                        Text("Enter the email of the user you would like to add:")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                        
                        TextField("Enter a user's email", text: $userEmail)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(14)
                            .shadow(radius: 2)
                        
                        if addingInProgress {
                            ProgressView()
                        }
                        
                        if addUserError {
                            Text("Error adding user. Please try again.")
                                .foregroundColor(.red)
                                .font(.callout)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(35)
                }
            }
            .padding()
        }
        .sheet(isPresented: $sendInvitePresented) { RunInviteSheet(isPresented: $sendInvitePresented, group: group) }
        .alert("Error communicating with the server", isPresented: $addUserError) {
            Button("OK", role: .cancel) {}
        }
        .alert("A group may only have 5 users", isPresented: $tooManyUsers) {
            Button("OK", role: .cancel) {}
        }
        .task{
            do{
                runInvites = try await getRunInvites(groupId: group.group.groupId)
            }catch{
                
            }
        }
    }
}

struct PersonRunView: View{
    let runs: UserRuns
    var body: some View{
        ScrollView {
            ForEach(runs.runs.sorted(by: { $0.startTime > $1.startTime})){ run in
                GroupBox(label:
                            HStack{
                    VStack(alignment: .leading) {
                        let runDate = Date(timeIntervalSince1970: TimeInterval(run.startTime))
                        Text(timeOfDay(for: runDate) + " Run in " + run.locality).fontWeight(.bold)
                        Text(runDate.formatted(date: .abbreviated, time: .omitted) + " at " + runDate.formatted(date: .omitted, time: .shortened).lowercased()).fontWeight(.regular)
                    }
                    Spacer();
                }){
                    VStack{
                        Divider().padding([.leading, .trailing])
                        HStack{
                            
                            Spacer()
                            UserMiniMileView(userRun: run, fontSize: 26)
                            Spacer()
                            UserMiniFinishedTimeView(userRun: run, fontSize: 26)
                            Spacer()
                            UserMiniFinishedAvgPaceView(userRun: run, fontSize: 26)
                            Spacer()
                            
                        }
                    }
                    
                }.padding()
            }
        }.navigationTitle(runs.username + "'s Runs")
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

struct RunInviteSheet: View {
    @Binding var isPresented: Bool
    @State private var selectedDate = Date()
    @State private var meetupLocation = ""
    @State private var notes = ""
    @State private var sendingInProgress = false
    
    let group: GroupData
    
    var body: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }.padding(.leading)
            Spacer()
            Button("Send") {
                Task {
                    sendingInProgress = true
                    await sendRunInvite(groupId: group.group.groupId, time: Int64(selectedDate.timeIntervalSince1970), place: meetupLocation, notes: notes, recursive: true)
                    sendingInProgress = false
                    isPresented = false
                }
            }.padding(.trailing)
        }.padding(.top)
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Send an Invite")
                        .font(.largeTitle)
                        .bold()
                        .padding(.top)
                        .foregroundColor(Color.primary.opacity(0.8))
                    
                    Text("Choose details for your run")
                        .font(.callout)
                    
                    DatePicker("Date and Time", selection: $selectedDate)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(14)
                        .shadow(radius: 2)
                    
                    TextField("Meetup Location", text: $meetupLocation)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(14)
                        .shadow(radius: 2)
                    
                    TextField("Additional Notes", text: $notes)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(14)
                        .shadow(radius: 2)
                    
                    if sendingInProgress {
                        ProgressView()
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(35)
        .padding()
    }
}


struct InviteCell: View {
    let invite: RunInvite
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.purple)
                Text(invite.creator)
                    .font(.headline)
                Spacer()
                Text(Date(timeIntervalSince1970: TimeInterval(invite.time)), style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Text(Date(timeIntervalSince1970: TimeInterval(invite.time)), style: .time)
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.red)
                Text(invite.place)
                    .font(.subheadline)
            }
            
            if !invite.notes.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(.green)
                    Text(invite.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
