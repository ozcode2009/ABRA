//
//  ContentView.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/26/24.
//

import SwiftUI
import SwiftData

struct MainView: View {
    let container: ModelContainer
    @StateObject var runCoordinator = RunCoordinator.shared;
    @AppStorage("signedIn") var signedIn: Bool = false
    var body: some View {
        if(!signedIn){
            SignInView().animation(.easeInOut, value: signedIn );
        }else{
            ZStack{
                if(runCoordinator.runScreen){
                    RunningView(container: container)
                }else{
                    TabView {
                        StartRunView(modelContainer: container)
                            .tabItem {
                                Label("Run", systemImage: "figure.run")
                            }
                            .transition(.blurReplace)
                        
                        RunListView()
                            .tabItem {
                                Label("Runs", systemImage: "figure.run.square.stack.fill")
                            }
                        GroupListView()
                            .tabItem{
                                Label("Groups", systemImage: "person.3")
                            }
                        
                    }
                    
                }
            }.animation(.easeInOut, value: signedIn )
        }
    }
}
