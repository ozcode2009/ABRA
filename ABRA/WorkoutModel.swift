//
//  WorkoutModel.swift
//  ABRA
//
//  Created by Oliver Crumrine on 12/29/24.
//

import Foundation
import SwiftData

@Model
final class WorkoutModel {
    @Attribute(.unique)
    var id = UUID()
    var name: String
    var workouts: [WorkoutFragment]
    
    init(name: String, workouts: [WorkoutFragment]) {
        self.name = name
        self.workouts = workouts
    }
}

struct WorkoutFragment: Codable, Identifiable {
    let id: UUID = UUID()
    var rest: Bool
    var trackWorkout: Bool
    var suggestedDistanceMeters: Double
    var suggestedDistanceActive: Bool
    var suggestedTime: Double
    var suggestedTimeActive: Bool
}

