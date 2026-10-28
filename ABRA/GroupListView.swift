//
//  GroupView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/4/24.
//

import SwiftUI

struct GroupListView: View {
    @State private var newGroup = false;
    @State private var groupName = "";
    @State private var groupError = false;
    @State private var groupLoadingError = false;
    @State private var groupDataLoading = true;
    @State private var createGroupForbidden = false;
    @State private var groupData: [GroupData] = []
    @State private var groupReqData: [GroupRequest] = []
    @State private var shouldRefresh: Bool = false;
    @AppStorage("distanceUnit") private var distanceUnit = 1
    var body: some View {
        NavigationStack {
            VStack{
                if(groupDataLoading) {
                    ProgressView()
                }else{
                    if(groupData.count < 1){
                        VStack{
                            Text("No Groups")
                                .font(.largeTitle)
                                .foregroundColor(Color.primary.opacity(0.4))
                            Text("Press + to create a group")
                                .font(.callout)
                                .foregroundColor(Color.primary.opacity(0.4))
                        }
                    }else{
                        ScrollView {
                            ForEach(groupReqData) { groupReq in
                                GroupBox(label:
                                            HStack{
                                    VStack(alignment: .leading) {
                                        Text(groupReq.name).font(.title2).bold()
                                        Text("Owner: " + groupReq.owner_name ).font(.title3)
                                    }
                                    Spacer();
                                }){
                                    HStack(spacing: 0) {
                                        Button(action: {
                                            Task {
                                                await respond_group_request(group_id: groupReq.group_id, response: 1)
                                                await getGroupReqData()
                                                shouldRefresh = !shouldRefresh;
                                            }
                                        }) {
                                            Text("Accept")
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(10)
                                        }.padding(.trailing, 2)
                                        
                                        Button(action: {
                                            Task {
                                                await respond_group_request(group_id: groupReq.group_id, response: 0)
                                                await getGroupReqData()
                                            }
                                        }) {
                                            Text("Decline")
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .background(Color.red)
                                                .foregroundColor(.white)
                                                .cornerRadius(10)
                                        }.padding(.leading, 2)
                                    }
                                    .frame(height: 50)
                                }.padding()
                            }
                            ForEach(groupData){ group in
                                NavigationLink(destination: GroupView(group: group, shouldRefreshGroupList: $shouldRefresh)){
                                    GroupBox(label:
                                                HStack{
                                        VStack(alignment: .leading) {
                                            Text(group.group.groupName).font(.title2).bold()
                                            Text("Leaderboard").font(.title3).padding(.top)
                                            ForEach(Array(calculateIndividualDistances(groupStats: group).sorted {$0.distance > $1.distance }.enumerated()), id: \.offset){ index, user in
                                                VStack{
                                                    Divider()
                                                    HStack {
                                                        let distanceMultiplier: Float = (distanceUnit == 0) ? 1.609 : 1
                                                        let unit = (distanceUnit == 0) ? " km" : " mi"
                                                        Text(user.username).fontWeight(.bold)
                                                        Spacer()
                                                        Text(String(format: "%.2f", user.distance * distanceMultiplier) + unit).fontWeight(.bold)
                                                    }
                                                }
                                                
                                            }
                                        }
                                        Spacer();
                                    }){
                                        VStack{
                                            Divider()
                                            HStack{
                                                Text("Weekly Group Totals").font(.title3).padding([.bottom])
                                                Spacer()
                                            }.padding(.top)
                                            HStack{
                                                Spacer()
                                                GroupMiniMileView(group: group, statsType: 0, fontSize: 26)
                                                Spacer()
                                                GroupMiniFinishedTimeView(group: group, statsType: 0, fontSize: 26)
                                                Spacer()
                                                GroupMiniFinishedAvgPaceView(group: group, statsType: 0, fontSize: 26)
                                                Spacer()
                                            }
                                        }
                                        
                                    }.padding()
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar{
                ToolbarItem(placement: .automatic){
                    Button(action: {
                        if(groupData.count >= 1){
                            createGroupForbidden = true;
                        }else{
                            newGroup = true;
                        }
                    }){
                        Image(systemName: "plus")
                            .resizable()
                            .padding(6)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.accent)
                    }
                }
            }
        }.sheet(isPresented: $newGroup){
            HStack {
                Button("Cancel") {
                    newGroup = false
                }.padding(.leading)
                Spacer()
                Button("Continue") {
                    Task {
                        let status = await createGroup(name: groupName)
                        shouldRefresh = !shouldRefresh;
                        if status {
                            newGroup = false
                        } else {
                            groupError = true
                        }
                    }
                }.padding(.trailing)
            }.padding(.top)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Create a Group")
                            .font(.largeTitle)
                            .bold()
                            .padding(.top)
                            .foregroundColor(Color.primary.opacity(0.8))
                        
                        TextField("Enter a group name", text: $groupName)
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(14)
                            .shadow(radius: 2)
                        
                        Text("You can add other participants later in the group's page")
                            .font(.footnote)
                            .foregroundColor(Color.primary.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if groupError {
                            Text("Error creating group. Please try again.")
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
        .onChange(of: shouldRefresh, initial: true){
                Task{
                    await getGroupReqData();
                    await getGroupData();
                }
        }
        
        .alert("Error creating group", isPresented: $groupError) {
            Button("OK", role: .cancel) {}
        }
        .alert("Error loading groups", isPresented: $groupLoadingError){
            Button("OK", role: .cancel) {}
        }
        .alert("You may only own one group", isPresented: $createGroupForbidden){
            Button("OK", role: .cancel) {}
        }
        
    }
    
    func getGroupData() async {
        groupDataLoading = true;
        do {
            let res = try await fetchGroupsAndWeeklyStats();
            groupData = res;
        } catch {
            groupLoadingError = true;
        }
        groupDataLoading = false;
    }
    func getGroupReqData() async {
        do {
            let res = try await getGroupRequests();
            groupReqData = res;
        } catch {
            groupLoadingError = true;
        }
    }
}

