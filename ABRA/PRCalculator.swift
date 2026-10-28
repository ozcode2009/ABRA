//
//  PRCalculator.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/29/24.
//

import Foundation
import CoreLocation

struct PRTuple: Codable {
    let value: Double
    let date: Date

    init(value: Double, date: Date) {
        self.value = value
        self.date = date
    }
}

struct PersonalRecords: Codable {
    var mile: PRTuple?
    var fiveK: PRTuple?
    var tenK: PRTuple?
    var halfMarathon: PRTuple?
    var marathon: PRTuple?
    var longestRun: PRTuple?

    init() {}
}

class PRManager {
    static let shared = PRManager()
    private init() {}
    
    private let userDefaults = UserDefaults.standard
    private let prKey = "personalRecords"
    
    func loadPRs() -> PersonalRecords {
        if let data = userDefaults.data(forKey: prKey),
           let prs = try? JSONDecoder().decode(PersonalRecords.self, from: data) {
            return prs
        }
        return PersonalRecords()
    }
    
    func savePRs(_ prs: PersonalRecords) {
        if let data = try? JSONEncoder().encode(prs) {
            userDefaults.set(data, forKey: prKey)
        }
    }
    
    func updatePRs(with run: RunData) async {
        var prs = loadPRs()
        
        let distances = [
            (1609.0, \PersonalRecords.mile),
            (5000.0, \PersonalRecords.fiveK),
            (10000.0, \PersonalRecords.tenK),
            (21097.5, \PersonalRecords.halfMarathon),
            (42195.0, \PersonalRecords.marathon)
        ]
        
        for (distance, prKeyPath) in distances {
            if let (time, date) = await calculateBest(for: distance, from: run) {
                if prs[keyPath: prKeyPath] == nil || prs[keyPath: prKeyPath]!.value == 0 || time < prs[keyPath: prKeyPath]!.value {
                    prs[keyPath: prKeyPath] = PRTuple(value: time, date: date)
                }
            }
        }
        
        let runDistance = run.runDistanceMeters
        if prs.longestRun == nil || runDistance > prs.longestRun!.value {
            prs.longestRun = PRTuple(value: runDistance, date: run.runStart)
        }
        
        savePRs(prs)
    }
    
    private func calculateBest(for distanceMeters: Double, from run: RunData) async -> (time: TimeInterval, start: Date)? {
        // To ensure thread safety, capture the run data in a local constant if needed
        let runCoordinates = run.runCoordinates
        let runDistanceMeters = run.runDistanceMeters
        let runFinish = run.runFinish
        let runStart = run.runStart
        
        var bestTime: TimeInterval?
        var bestStart: Date?
        
        // Handle runs without coordinates
        if runCoordinates.isEmpty {
            if runDistanceMeters >= distanceMeters {
                let totalTime = runFinish.timeIntervalSince(runStart)
                let estimatedTime = (distanceMeters / runDistanceMeters) * totalTime
                
                bestTime = estimatedTime
                bestStart = runStart
            }
        } else {
            for startIdx in 0..<runCoordinates.count {
                var cumulativeDistance: Double = 0.0
                let startTime = runCoordinates[startIdx].time
                
                for endIdx in startIdx + 1..<runCoordinates.count {
                    cumulativeDistance += distanceBetween(runCoordinates[endIdx - 1], runCoordinates[endIdx])
                    
                    if cumulativeDistance >= distanceMeters {
                        let endTime = runCoordinates[endIdx].time
                        let timeInterval = endTime.timeIntervalSince(startTime)
                        
                        if bestTime == nil || timeInterval < bestTime! {
                            bestTime = timeInterval
                            bestStart = startTime
                        }
                        break
                    }
                }
            }
        }
        
        if let bestTime = bestTime, let bestStart = bestStart {
            return (bestTime, bestStart)
        }
        
        return nil
    }
    
    private func distanceBetween(_ coord1: Coordinate, _ coord2: Coordinate) -> Double {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
}
