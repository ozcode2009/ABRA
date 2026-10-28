//
//  ABRAApp.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/26/24.
//

import SwiftUI
import SwiftData
import ActivityKit


@main
struct ABRAApp: App {

    
    var runDataModelContainer: ModelContainer = {
        let schema = Schema([
            RunData.self,
            RouteModel.self,
            WorkoutModel.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    init(){
        RunCoordinator.shared.getLocationStatus(request: false);
        
    }
    var body: some Scene {
        WindowGroup {
            MainView(container: runDataModelContainer)
            
        }.modelContainer(runDataModelContainer)

    }
}
