//
//  CommunicationCoordinator.swift
//  ABRA
//
//  Created by Oliver Crumrine on 6/24/24.
//

import Foundation
import Security
import CoreLocation
import UIKit

let baseURL = "https://lasting-lark-creative.ngrok-free.app";

enum SignUpStatus{
    case success
    case usernameTaken
    case emailTaken
    case ISE
}

enum SignInStatus {
    case success
    case unauthorized
    case ISE
}

func signUp(email: String, password: String, username: String) async -> SignUpStatus{
    let url = URL(string: baseURL + "/user")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.httpMethod = "POST"
    
    let uploadData = (("{") + ("\"email\": " + "\"" + email + "\"" + ",") + ("\"password\": " + "\"" + password +  "\"" + ",") + ("\"name\": " + "\"" + username + "\"") + ("}"))
    
    do{
        let (data, response) = try await URLSession.shared.upload(for: request, from: uploadData.data(using: .utf8)!)
        guard let httpResponse = response as? HTTPURLResponse else {
            UserDefaults.standard.set(false, forKey: "signedIn");
            return .ISE
        }
        if httpResponse.statusCode == 409 {
            return .usernameTaken
        }
        if httpResponse.statusCode == 422 {
            return .emailTaken
        }
        if httpResponse.statusCode == 500 {
            return .ISE
        }
        guard let dataString = String(data: data, encoding: .utf8) else { return .ISE }
        
        KeychainManager.storeCredentials(username: email, password: password);
        try KeychainManager.saveSessionId(dataString);
    }catch {
        UserDefaults.standard.set(false, forKey: "signedIn");
        return .ISE;
    }
    
    UserDefaults.standard.set(true, forKey: "signedIn");
    
    return .success;
    
}

func signIn(email: String, password: String) async -> SignInStatus{
    
    let url = URL(string: baseURL + "/sign_in")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.httpMethod = "POST"
    
    let uploadData = (("{") + ("\"email\": " + "\"" + email + "\"" + ",") + ("\"password\": " + "\"" + password +  "\"" + ",") + ("\"name\": " + "\"" + "\"") + ("}"))
    
    do{
        let (data, response) = try await URLSession.shared.upload(for: request, from: uploadData.data(using: .utf8)!)
        guard let httpResponse = response as? HTTPURLResponse else {
            UserDefaults.standard.set(false, forKey: "signedIn");
            return .ISE
        }
        if httpResponse.statusCode == 401 {
            return .unauthorized
        }
        if httpResponse.statusCode == 500 {
            return .ISE
        }
        guard let dataString = String(data: data, encoding: .utf8) else { return .ISE }
        
        try KeychainManager.saveSessionId(dataString);
        KeychainManager.storeCredentials(username: email, password: password);
    }catch {
        UserDefaults.standard.set(false, forKey: "signedIn");
        return .ISE;
    }
    
    UserDefaults.standard.set(true, forKey: "signedIn");
    
    return .success;
    
}
func signInKeychain() async -> SignInStatus {
    let url = URL(string: baseURL + "/sign_in")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.httpMethod = "POST"
    
    guard let credentials = KeychainManager.retrieveCredentials() else {
        return .ISE
    }
    let uploadData = (("{") + ("\"email\": " + "\"" + credentials.username + "\"" + ",") + ("\"password\": " + "\"" + credentials.password +  "\"" + ",") + ("\"name\": " + "\"" + "\"") + ("}"))
    
    do{
        let (data, response) = try await URLSession.shared.upload(for: request, from: uploadData.data(using: .utf8)!)
        guard let httpResponse = response as? HTTPURLResponse else {
            UserDefaults.standard.set(false, forKey: "signedIn");
            return .ISE
        }
        if httpResponse.statusCode == 401 {
            return .unauthorized
        }
        if httpResponse.statusCode == 500 {
            return .ISE
        }
        guard let dataString = String(data: data, encoding: .utf8) else { return .ISE }
        
        try KeychainManager.saveSessionId(dataString);
    }catch {
        UserDefaults.standard.set(false, forKey: "signedIn");
        return .ISE;
    }
    
    UserDefaults.standard.set(true, forKey: "signedIn");
    
    return .success;
}

func sendRunAndGetLocality(runDistance: Float, runPace: Float, runTime: Float, runStart: Int, runStartCoord: CLLocationCoordinate2D, recursive: Bool = false) async -> String{
    let url = URL(string: baseURL + "/new_run")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    
    let uploadData = (("{") + ("\"distance\": " + String(runDistance) + ",") + ("\"avg_pace\": " + String(runPace) + ",") + ("\"time\": " + String(runTime) + ",") + ("\"start_time\": " + String(runStart) + ",") + ("\"lat\": " + String(runStartCoord.latitude) + ",") + ("\"lon\": " + String(runStartCoord.longitude)) + ("}"))
    
    do{
        let (data, response) = try await URLSession.shared.upload(for: request, from: uploadData.data(using: .utf8)!)
        guard let httpResponse = response as? HTTPURLResponse else {
            return "Earth"
        }
        if httpResponse.statusCode == 401 && recursive == false{
            await signInKeychain()
            return await sendRunAndGetLocality(runDistance: runDistance, runPace: runPace, runTime: runTime, runStart: runStart, runStartCoord: runStartCoord, recursive: true)
            
        }else if httpResponse.statusCode == 401 && recursive == true {
            return "Earth"
        }
        if httpResponse.statusCode == 500 {
            return "Earth"
        }
        guard let dataString = String(data: data, encoding: .utf8) else { return "Earth" }
        
        return dataString
    }catch {
        return "Earth";
    }
    
    
}

func createGroup(name: String, recursive: Bool = false) async -> Bool{
    let url = URL(string: baseURL + "/new_group")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    
    let uploadData = (("{") + ("\"name\": " + "\"" + name + "\"") + ("}"))
    
    do{
        let (_, response) = try await URLSession.shared.upload(for: request, from: uploadData.data(using: .utf8)!)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        if httpResponse.statusCode == 401 && recursive == false{
            await signInKeychain()
            return await createGroup(name: name, recursive: true)
            
        }else if httpResponse.statusCode == 401 && recursive == true {
            return false
        }
        if httpResponse.statusCode == 200{
            return true
        }
        
    }catch {
        return false
    }
    return false
}

struct GetGroupResponse: Codable {
    let ownerOrNot: Int
    let ownerName: String
    let groupID: Int
    let groupName: String
    let usernames: [String]
    
    enum CodingKeys: String, CodingKey {
        case ownerOrNot = "owner_or_not"
        case groupID = "group_id"
        case ownerName = "owner_name"
        case groupName = "group_name"
        case usernames
    }
}




func signOut(recursive: Bool = false) async {
    let url = URL(string: baseURL + "/sign_out")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    
    do{
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if(!recursive) {
                throw URLError(.badServerResponse)
            }else{
                await signInKeychain()
                return await signOut(recursive: false)
                
            }
        }
        UserDefaults.standard.set(false, forKey: "signedIn");
        await KeychainManager.deleteCredentials()
        try await KeychainManager.deleteSessionId()
    }catch {
    }
}
func deleteAccount(recursive: Bool = false) async {
    let url = URL(string: baseURL + "/delete_account")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    
    do{
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if(recursive) {
                throw URLError(.badServerResponse)
            }else{
                await signInKeychain()
                return await deleteAccount(recursive: true)
            }
        }
    }catch {
    }
}
func deleteRun(runTime: Int64, recursive: Bool = false) async {
    let url = URL(string: baseURL + "/delete_run")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    
    let uploadData = (("{") + ("\"start_time\": " + String(runTime)) + ("}"))
    
    do{
        let (data, response) = try await URLSession.shared.upload(for: request, from: uploadData.data(using: .utf8)!)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if(recursive) {
                throw URLError(.badServerResponse)
            }else{
                await signInKeychain()
                return await deleteRun(runTime: runTime, recursive: true)
            }
        }
    }catch {
    }
}

func getRuns() async throws -> [Run] {
    let url = URL(string: baseURL + "/get_runs")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "GET"
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let runs = try decoder.decode([Run].self, from: data)
        return runs
    } catch {
        throw error
    }
}
