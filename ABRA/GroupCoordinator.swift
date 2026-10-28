//
//  GroupCoordinator.swift
//  ABRA
//
//  Created by Oliver Crumrine on 7/5/24.
//

import Foundation

struct Group: Codable {
    let ownerOrNot: Int
    let ownerName: String
    let groupId: Int
    let groupName: String
    let usernames: [String]
    
    enum CodingKeys: String, CodingKey {
        case ownerOrNot = "onwer_or_not"
        case ownerName = "owner_name"
        case groupId = "group_id"
        case groupName = "group_name"
        case usernames
    }
}

struct Run: Codable, Identifiable {
    let id = UUID()
    let distance: Float
    let avgPace: Float
    let time: Float
    let startTime: Int64
    let locality: String
    
    enum CodingKeys: String, CodingKey {
        case distance
        case avgPace = "avg_pace"
        case time
        case startTime = "start_time"
        case locality
    }
}

struct UserRuns: Codable, Identifiable {
    let username: String
    let runs: [Run]
    @CodableIgnored
    var id = UUID()
}

struct GroupData: Identifiable {
    let id = UUID()
    let group: Group
    let userRuns: [UserRuns]
}

struct GroupRuns {
    let group: Group
    let userRuns: [UserRuns]
}

struct UserAndDistance: Identifiable {
    let id = UUID()
    let username: String
    let distance: Float
}
struct UserLongestRun: Identifiable {
    let id = UUID()
    let username: String
    let longestRun: Run
}

struct Stats {
    let totalDistance: Float
    let totalTime: Float
    let averagePace: Float
}

func getGroups(recursive: Bool = false) async throws -> [Group] {
    guard let url = URL(string: "\(baseURL)/get_groups") else {
        throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
    }
    
    var request = URLRequest(url: url)
    request.addValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    if httpResponse.statusCode == 401 && recursive == false{
        await signInKeychain()
        return try await getGroups(recursive: true)
        
    }else if httpResponse.statusCode == 401 && recursive == true {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    
    return try JSONDecoder().decode([Group].self, from: data)
}

func getGroupRuns(groupId: Int, recursive: Bool = false) async throws -> [UserRuns] {
    guard let url = URL(string: "\(baseURL)/get_group_runs") else {
        throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    
    let body = ["group_id": groupId]
    request.httpBody = try? JSONEncoder().encode(body)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    if httpResponse.statusCode == 401 && recursive == false{
        await signInKeychain()
        return try await getGroupRuns(groupId: groupId, recursive: true)
        
    }else if httpResponse.statusCode == 401 && recursive == true {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    return try JSONDecoder().decode([UserRuns].self, from: data)
    
    
}



func getGrouopData(group: Group, userRuns: [UserRuns]) -> GroupData {
    return GroupData(
        group: group,
        userRuns: userRuns
    )
}

func fetchGroupsAndWeeklyStats() async throws -> [GroupData] {
    async let groupsTask = getGroups()
    
    let groups = try await groupsTask
    
    return try await withThrowingTaskGroup(of: GroupRuns.self) { group in
        for groupInfo in groups {
            group.addTask {
                let userRuns = try await getGroupRuns(groupId: groupInfo.groupId)
                return GroupRuns(group: groupInfo, userRuns: userRuns)
            }
        }
        
        var groupsWithRuns: [GroupRuns] = []
        for try await result in group {
            groupsWithRuns.append(result)
        }
        
        return groupsWithRuns.map { groupWithRuns in
            getGrouopData(group: groupWithRuns.group, userRuns: groupWithRuns.userRuns)
        }
    }
}

func calculateIndividualDistances(groupStats: GroupData) -> [UserAndDistance] {
    let oneWeekAgo = Int(Date().addingTimeInterval(-7 * 24 * 60 * 60).timeIntervalSince1970)
    var results: [UserAndDistance] = []
    
    for userRun in groupStats.userRuns {
        var totalDistance: Float = 0
        
        for run in userRun.runs {
            if run.startTime >= oneWeekAgo {
                totalDistance += run.distance
            }
        }
        
        results.append(UserAndDistance(username: userRun.username, distance: totalDistance))
    }
    
    return results
}

@propertyWrapper
public struct CodableIgnored<T>: Codable {
    public var wrappedValue: T?
        
    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        self.wrappedValue = nil
    }
    
    public func encode(to encoder: Encoder) throws {
    }
}

extension KeyedDecodingContainer {
    public func decode<T>(
        _ type: CodableIgnored<T>.Type,
        forKey key: Self.Key) throws -> CodableIgnored<T>
    {
        return CodableIgnored(wrappedValue: nil)
    }
}

extension KeyedEncodingContainer {
    public mutating func encode<T>(
        _ value: CodableIgnored<T>,
        forKey key: KeyedEncodingContainer<K>.Key) throws
    {
    }
}


func sumGroupRunsToRunDataByDay(groupStats: GroupData) -> [RunData] {
    let calendar = Calendar.current
    var dailyRuns: [Date: (distance: Float, time: Float, startTime: Int64)] = [:]
    
    for userRuns in groupStats.userRuns {
        for run in userRuns.runs {
            let date = calendar.startOfDay(for: Date(timeIntervalSince1970: TimeInterval(run.startTime)))
            
            if let existingData = dailyRuns[date] {
                dailyRuns[date] = (
                    distance: existingData.distance + run.distance,
                    time: existingData.time + run.time,
                    startTime: min(existingData.startTime, run.startTime)
                )
            } else {
                dailyRuns[date] = (distance: run.distance, time: run.time, startTime: run.startTime)
            }
        }
    }
    
    return dailyRuns.map { (date, runData) in
        return RunData(
            runStart: date,
            runFinish: Date(),
            runCoordinates: [],
            runDistanceMeters: Double(runData.distance),
            weatherImageString: "",
            temperatureF: 0
        )
    }.sorted { $0.runStart < $1.runStart }
}
func getUsersLongestRunsForDay(groupStats: GroupData, date: Date) -> [UserLongestRun] {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let startTimestamp = Int64(startOfDay.timeIntervalSince1970)
    let endTimestamp = Int64(endOfDay.timeIntervalSince1970)
    
    var usersLongestRuns: [UserLongestRun] = []
    
    for userRuns in groupStats.userRuns {
        let runsForDay = userRuns.runs.filter { run in
            run.startTime >= startTimestamp && run.startTime < endTimestamp
        }
        
        if let longestRun = runsForDay.max(by: { $0.distance < $1.distance }) {
            let userLongestRun = UserLongestRun(username: userRuns.username, longestRun: longestRun)
            usersLongestRuns.append(userLongestRun)
        }
    }
    
    return usersLongestRuns
}

func sumRunsLastWeek(_ runs: [Run]) -> (totalDistance: Float, totalTime: Float) {
    let now = Date().timeIntervalSince1970
    let oneWeekAgo = now - 7 * 24 * 60 * 60
    
    let lastWeekRuns = runs.filter { run in
        Double(run.startTime) > oneWeekAgo
    }
    
    let totalDistance = lastWeekRuns.reduce(0) { $0 + $1.distance }
    let totalTime = lastWeekRuns.reduce(0) { $0 + $1.time }
    
    return (totalDistance, totalTime)
}

func calculatePreviousMonthStats(userRuns: [UserRuns]) -> Stats {
    let now = Date()
    let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now)!.timeIntervalSince1970
    
    let (totalDistance, totalTime, runCount) = userRuns.flatMap { $0.runs }.reduce(into: (distance: Float(0), time: Float(0), count: 0)) { result, run in
        assert(!run.time.isNaN)
        if Double(run.startTime) >= oneMonthAgo {
            result.distance += run.distance
            result.time += run.time
            result.count += 1
        }
    }
    
    let averagePace = calculateAveragePace(distance: totalDistance, time: totalTime, count: runCount)
    
    return Stats(totalDistance: totalDistance, totalTime: totalTime, averagePace: averagePace)
}

func calculateAllTimeStats(userRuns: [UserRuns]) -> Stats {
    let (totalDistance, totalTime, runCount) = userRuns.flatMap { $0.runs }.reduce(into: (distance: Float(0), time: Float(0), count: 0)) { result, run in
        assert(!run.time.isNaN)
        result.distance += run.distance
        result.time += run.time
        result.count += 1
    }
    
    let averagePace = calculateAveragePace(distance: totalDistance, time: totalTime, count: runCount)
    
    return Stats(totalDistance: totalDistance, totalTime: totalTime, averagePace: averagePace)
}

func calculatePreviousWeekStats(userRuns: [UserRuns]) -> Stats {
    let now = Date()
    let oneWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now)!.timeIntervalSince1970
    
    let (totalDistance, totalTime, runCount) = userRuns.flatMap { $0.runs }.reduce(into: (distance: Float(0), time: Float(0), count: 0)) { result, run in
        assert(!run.time.isNaN)
        if Double(run.startTime) >= oneWeekAgo {
            result.distance += run.distance
            result.time += run.time
            result.count += 1
        }
    }
    
    let averagePace = calculateAveragePace(distance: totalDistance, time: totalTime, count: runCount)
    
    return Stats(totalDistance: totalDistance, totalTime: totalTime, averagePace: averagePace)
}

func calculateGroupStats(userRuns: [UserRuns], type: Int) -> Stats {
    if(type == 0){
        return calculatePreviousWeekStats(userRuns: userRuns)
    }else if(type == 1){
        return calculatePreviousMonthStats(userRuns: userRuns)
    }else{
        return calculateAllTimeStats(userRuns: userRuns)
    }
}

func getGroupStatTitle(type: Int) -> String {
    if(type == 0){
        return "Weekly"
    }else if(type == 1){
        return "Monthly"
    }else{
        return "All-Time"
    }
}

func calculateAveragePace(distance: Float, time: Float, count: Int) -> Float {
    if count > 0 {
        let pace = time / distance
        return pace > 3600 ? 0 : pace
    }
    return 0
}

struct AddGroupRequest: Codable {
    let email: String
    let group_id: Int
}
func addUserToGroup(email: String, groupId: Int, recursive: Bool = false) async -> Bool {
    let url = URL(string: baseURL + "/group_add_request")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    
    let addGroupRequest = AddGroupRequest(email: email, group_id: groupId)
    
    do {
        let encoder = JSONEncoder()
        let uploadData = try encoder.encode(addGroupRequest)
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: uploadData)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        if httpResponse.statusCode == 401 && recursive == false{
            await signInKeychain()
            return await addUserToGroup(email: email, groupId: groupId, recursive: true)
            
        }else if httpResponse.statusCode == 401 && recursive == true {
            return false
        }
        if httpResponse.statusCode == 200 {
            return true
        }
    } catch {
        return false
    }
    return false
}

struct GroupRequest: Codable, Identifiable {
    let id = UUID()
    let name: String
    let group_id: Int
    let owner_name: String
}


func getGroupRequests(recursive: Bool = false) async throws -> [GroupRequest] {
    guard let url = URL(string: "\(baseURL)/fetch_group_requests") else {
        throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")

    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    if httpResponse.statusCode == 401 && recursive == false{
        await signInKeychain()
        return try await getGroupRequests(recursive: true)
        
    }else if httpResponse.statusCode == 401 && recursive == true {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    return try JSONDecoder().decode([GroupRequest].self, from: data)
}

struct GroupRequestResponse: Codable {
    let group_id: Int
    let response: Int
}

func respond_group_request(group_id: Int, response: Int, recursive: Bool = false) async -> Bool{
    let url = URL(string: baseURL + "/respond_group_request")!
    var request = URLRequest(url: url);
    request.setValue("application/json", forHTTPHeaderField: "Content-Type");
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    
    let grr = GroupRequestResponse(group_id: group_id, response: response)
    
    let grrData: Data;
    
    do {
        grrData = try JSONEncoder().encode(grr)
    }catch {
        return false;
    }
    
    
    do{
        let (_, requestResponse) = try await URLSession.shared.upload(for: request, from: grrData)
        guard let httpResponse = requestResponse as? HTTPURLResponse else {
            return false
        }
        if httpResponse.statusCode == 401 && recursive == false{
            await signInKeychain()
            return await respond_group_request(group_id: group_id, response: response, recursive: true)
            
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

struct CreateRunInvite: Codable {
    let group_id: Int
    let time: Int64
    let place: String
    let notes: String
}

func sendRunInvite(groupId: Int, time: Int64, place: String, notes: String, recursive: Bool = false) async -> Bool {
    let url = URL(string: baseURL + "/create_run_invite")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    
    let runInviteRequest = CreateRunInvite(group_id: groupId, time: time, place: place, notes: notes)
    
    do {
        let encoder = JSONEncoder()
        let uploadData = try encoder.encode(runInviteRequest)
        
        let (_, response) = try await URLSession.shared.upload(for: request, from: uploadData)
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        if httpResponse.statusCode == 401 && recursive == false{
            await signInKeychain()
            return await sendRunInvite(groupId: groupId, time: time, place: place, notes: notes, recursive: true)
            
        }else if httpResponse.statusCode == 401 && recursive == true {
            return false
        }
        if httpResponse.statusCode == 200 {
            return true
        }
    } catch {
        return false
    }
    return false
}


struct RunInvite: Codable, Identifiable {
    let id = UUID()
    let creator: String
    let time: Int64
    let place: String
    let notes: String
}

func getRunInvites(groupId: Int, recursive: Bool = false) async throws -> [RunInvite] {
    let url = URL(string: baseURL + "/get_run_invites")!
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    request.httpMethod = "POST"
    
    let runInviteRequest = "{\"group_id\": " + String(groupId) + "}"

        
    let (data, response) = try await URLSession.shared.upload(for: request, from: runInviteRequest.data(using: .utf8)!)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    if httpResponse.statusCode == 401 && recursive == false{
        await signInKeychain()
        return try await getRunInvites(groupId: groupId, recursive: true)
        
    }else if httpResponse.statusCode == 401 && recursive == true {
        throw NSError(domain: "", code: 0, userInfo: nil)
    }
    return try JSONDecoder().decode([RunInvite].self, from: data)
}

func leaveGroup(groupId: Int) async throws{
    guard let url = URL(string: "\(baseURL)/leave_group") else {
        throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer " + (KeychainManager.retrieveSessionId() ?? ""), forHTTPHeaderField: "Authorization")
    
    let body = ["group_id": groupId]
    request.httpBody = try? JSONEncoder().encode(body)
    
    let _ = try await URLSession.shared.data(for: request)
}

