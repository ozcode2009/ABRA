//
//  WeatherStuff.swift
//  ABRA
//
//  Created by Oliver Crumrine on 5/30/24.
//

import Foundation
import WeatherKit
import CoreLocation

class WeatherStuff: ObservableObject {
    static let shared = WeatherStuff();
    
    var currentLocation: CLLocation?;
    let weatherService = WeatherService();
    @Published var currentWeather: CurrentWeather?;
    @Published var weatherAttribution: WeatherAttribution?;
    
    init(){
    }
    func getWeather() async {
        guard self.currentLocation != nil else {
            return
        }
        Task.detached(priority: .userInitiated) {
            do {
                let weatherReq = try await self.weatherService.weather(for: self.currentLocation!, including: .current)
                let weatherAttribution = try await self.weatherService.attribution;
                DispatchQueue.main.async {
                    self.currentWeather = weatherReq;
                    self.weatherAttribution = weatherAttribution;
                }
            } catch {
                
            }
        }
    }
}
