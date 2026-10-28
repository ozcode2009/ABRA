import SwiftUI
import SwiftData
import Charts


struct Month: Identifiable {
    let id = UUID()
    let name: String
    let number: Int
    let numDays: Int
}

struct MonthlyDistance: Identifiable {
    let id = UUID()
    let month: Month
    let distance: Double
}

struct YM: Identifiable {
    let id = UUID()
    let name: String
    let number: Int
}

struct RunChartView: View {
    let months: [Month] = [
        Month(name: "January", number: 1, numDays: 31),
        Month(name: "February", number: 2, numDays: 28),
        Month(name: "March", number: 3, numDays: 31),
        Month(name: "April", number: 4, numDays: 30),
        Month(name: "May", number: 5, numDays: 31),
        Month(name: "June", number: 6, numDays: 30),
        Month(name: "July", number: 7, numDays: 31),
        Month(name: "August", number: 8, numDays: 31),
        Month(name: "September", number: 9, numDays: 30),
        Month(name: "October", number: 10, numDays: 31),
        Month(name: "November", number: 11, numDays: 30),
        Month(name: "December", number: 12, numDays: 31),
        Month(name: "December", number: 12, numDays: 31)
    ]
    let leapMonths: [Month] = [
        Month(name: "January", number: 1, numDays: 31),
        Month(name: "February", number: 2, numDays: 29),
        Month(name: "March", number: 3, numDays: 31),
        Month(name: "April", number: 4, numDays: 30),
        Month(name: "May", number: 5, numDays: 31),
        Month(name: "June", number: 6, numDays: 30),
        Month(name: "July", number: 7, numDays: 31),
        Month(name: "August", number: 8, numDays: 31),
        Month(name: "September", number: 9, numDays: 30),
        Month(name: "October", number: 10, numDays: 31),
        Month(name: "November", number: 11, numDays: 30),
        Month(name: "December", number: 12, numDays: 31),
        //(just leave it, it'll break if removed and december selected)
        Month(name: "December", number: 12, numDays: 31)
    ]
    let yearmonths: [YM] = [
        YM(name: "Years",  number: 0),
        YM(name: "Months", number: 1),
    ]

    @State var selectedItem: String?
    @State var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State var selectedX: Int = 0
    @State var linePos: CGPoint = .zero
    @State var lineSelected: Bool = false
    @State var yearOrMonthSelected: Int = 1
    
    let runs: [RunData]
    
    let isGroupView: Bool
    let groupWeeklyStats: GroupData?
    
    var body: some View {
        let selMonths = daysInFebruary(year: selectedYear) ? leapMonths : months
        let selMonth = selMonths[selectedMonth]
        
        GroupBox(label: ChartHeaderView(selectedMonth: $selectedMonth, selectedYear: $selectedYear, months: selMonths, years: getContiguousYears(runs: runs))) {
            if yearOrMonthSelected == 1 {
                MonthlyChartView(selectedMonth: selectedMonth, selectedYear: selectedYear, selMonth: selMonth, runs: runs, isGroupView: isGroupView, groupWeeklyStats: groupWeeklyStats, selectedX: $selectedX, linePos: $linePos, lineSelected: $lineSelected)
            } else {
                YearlyChartView(selectedYear: selectedYear, runs: runs, isGroupView: isGroupView)
            }
            
            ChartFooterView(selectedMonth: selectedMonth, selectedYear: selectedYear, runs: runs, isGroupView: isGroupView, yearOrMonthSelected: $yearOrMonthSelected)
        }
        .padding()
    }
    
    func longestRunPerDay(inMonth month: Int, inYear year: Int, runs: [RunData]) -> [RunData] {
        let calendar = Calendar.current
        let filteredRuns = runs.filter { run in
            let runMonth = calendar.component(.month, from: run.runStart)
            let runYear = calendar.component(.year, from: run.runStart)
            return runMonth == month && runYear == year
        }
        var runsByDate: [Date: RunData] = [:]
        for run in filteredRuns {
            let dayComponent = calendar.startOfDay(for: run.runStart)
            if let existingRun = runsByDate[dayComponent] {
                if run.runDistanceMeters > existingRun.runDistanceMeters {
                    runsByDate[dayComponent] = run
                }
            } else {
                runsByDate[dayComponent] = run
            }
        }
        return Array(runsByDate.values)
    }
    
    func longestRunPerDayDict(inMonth month: Int, inYear year: Int, runs: [RunData]) -> [Int: RunData] {
        let calendar = Calendar.current
        let filteredRuns = runs.filter { run in
            let runMonth = calendar.component(.month, from: run.runStart)
            let runYear = calendar.component(.year, from: run.runStart)
            return runMonth == month && runYear == year
        }
        var runsByDate: [Int: RunData] = [:]
        for run in filteredRuns {
            let dayComponent = calendar.component(.day, from: run.runStart)
            if let existingRun = runsByDate[dayComponent] {
                if run.runDistanceMeters > existingRun.runDistanceMeters {
                    runsByDate[dayComponent] = run
                }
            } else {
                runsByDate[dayComponent] = run
            }
        }
        return runsByDate
    }
    
    func longestRunOnDay(inYear year: Int, inMonth month: Int, onDay day: Int, runs: [RunData]) -> Double {
        let calendar = Calendar.current
        let filteredRuns = runs.filter { run in
            let runYear = calendar.component(.year, from: run.runStart)
            let runMonth = calendar.component(.month, from: run.runStart)
            let runDay = calendar.component(.day, from: run.runStart)
            return runYear == year && runMonth == month && runDay == day
        }
        let longestRun = filteredRuns.max(by: { $0.runDistanceMeters < $1.runDistanceMeters })
        return longestRun?.runDistanceMeters ?? 0.0
    }
    
    func getMonthlyDistances(for runs: [RunData], in year: Int) -> [Double] {
        var monthlyDistances = Array(repeating: 0.0, count: 12)
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                let runMonth = calendar.component(.month, from: run.runStart)
                monthlyDistances[runMonth - 1] += run.runDistanceMeters
            }
        }
        return monthlyDistances
    }
    
    func getMonthlyDistancesStruct(for runs: [RunData], in year: Int) -> [MonthlyDistance] {
        var monthlyDistances = Array(repeating: 0.0, count: 12)
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                let runMonth = calendar.component(.month, from: run.runStart)
                monthlyDistances[runMonth - 1] += run.runDistanceMeters
            }
        }
        var result: [MonthlyDistance] = []
        for (index, distance) in monthlyDistances.enumerated() {
            result.append(MonthlyDistance(month: months[index], distance: distance))
        }
        return result
    }
    
    func getContiguousYears(runs: [RunData]) -> Range<Int> {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let years = runs.map { run in
            calendar.component(.year, from: run.runStart)
        }
        guard let minYear = years.min() else {
            return currentYear..<currentYear + 1
        }
        return minYear..<currentYear + 1
    }
    
    func getYearlyDistance(for runs: [RunData], in year: Int) -> Double {
        var totalDistance = 0.0
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                totalDistance += run.runDistanceMeters
            }
        }
        return totalDistance
    }
    
    func daysInFebruary(year: Int) -> Bool {
        if (year % 4 == 0) {
            if (year % 100 == 0) {
                if (year % 400 == 0) {
                    return true
                } else {
                    return false
                }
            } else {
                return true
            }
        } else {
            return false
        }
    }
}

struct ChartHeaderView: View {
    @Binding var selectedMonth: Int
    @Binding var selectedYear: Int
    let months: [Month]
    let years: Range<Int>
    
    var body: some View {
        HStack {
            Text("Runs")
            Spacer()
            Picker("Month", selection: $selectedMonth) {
                ForEach(months[0..<12], id: \.number) { month in
                    Text(month.name)
                }
            }
            Picker("Year", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text(String(year))
                }
            }
        }.padding(.bottom)
    }
}

struct MonthlyChartView: View {
    @Query var allRuns: [RunData]
    let selectedMonth: Int
    let selectedYear: Int
    let selMonth: Month
    let runs: [RunData]
    let isGroupView: Bool
    let groupWeeklyStats: GroupData?
    
    @Binding var selectedX: Int
    @Binding var linePos: CGPoint
    @Binding var lineSelected: Bool
    
    @State private var longestRunsPerDay: [RunData] = []
    @State private var longestRunsPerDayDict: [Int: RunData] = [:]
    
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    var body: some View {
        let unit = (distanceUnit == 0) ? "km" : "miles"
        Chart(longestRunPerDay(inMonth: selectedMonth, inYear: selectedYear, runs: runs)) {
            if Int($0.runStart.formatted(Date.FormatStyle().day(.twoDigits)))! <= selMonth.numDays {
                BarMark(x: .value("Date", Int($0.runStart.formatted(Date.FormatStyle().day(.twoDigits)))!),
                        y: .value("Distance", $0.runDistanceMeters / (isGroupView ? ((distanceUnit == 0) ? 0.621 : 1) : ((distanceUnit == 0) ? 1000 : 1609)))).foregroundStyle(interpolateRunColor(runDistance: $0.runDistanceMeters))
            }
        }
        .frame(height: 215)
        .chartYAxisLabel(unit)
        .chartXScale(domain: ClosedRange(uncheckedBounds: (1, selMonth.numDays)))
        .chartXAxis {
            if !longestRunPerDay(inMonth: selectedMonth, inYear: selectedYear, runs: runs).isEmpty {
                AxisMarks { value in
                    AxisGridLine()
                    if let day = value.as(Int.self) {
                        AxisValueLabel(String(day), centered: false, anchor: .top)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geoProxy in
                Rectangle()
                    .foregroundStyle(Color.orange.gradient)
                    .frame(width: 2, height: geoProxy.size.height * 0.76)
                    .position(x: linePos.x, y: geoProxy.size.height * 0.5345)
                    .opacity(lineSelected ? 1.0 : 0.0)
                if !isGroupView {
                    NavigationLink(destination: PreviousRunView(run: longestRunPerDayDict(inMonth: selectedMonth, inYear: selectedYear, runs: runs)[selectedX] ?? RunData())) {
                        TinyRunView(run: longestRunPerDayDict(inMonth: selectedMonth, inYear: selectedYear, runs: runs)[selectedX] ?? RunData())
                    }
                    .position(x: max(linePos.x, 37), y: geoProxy.size.height * 0.204)
                    .opacity(lineSelected ? 1.0 : 0.0)
                    .disabled(!lineSelected)
                } else {
                    TinyMultiRunView(groupWeeklyStats: groupWeeklyStats!, year: selectedYear, month: selectedMonth, day: selectedX)
                        .position(x: max(linePos.x, 37), y: geoProxy.size.height * 0.204)
                        .opacity(lineSelected ? 1.0 : 0.0)
                }
                
                Rectangle().fill(.purple.opacity(0.00001))
                    .padding([.top]).padding([.top]).padding([.top]).padding([.top]).padding([.top]).padding([.top])
                    .padding([.bottom]).padding([.bottom]).padding([.bottom]).padding([.bottom])
                    .onTapGesture { location in
                        guard let value: (Int, Double) = proxy.value(at: location) else  {
                            return
                        }
                        selectedX = value.0
                        
                        if(longestRunOnDay(inYear: selectedYear, inMonth: selectedMonth, onDay: selectedX, runs: runs) != 0){
                            linePos = proxy.position(for: (x: selectedX, y: longestRunOnDay(inYear: selectedYear, inMonth: selectedMonth, onDay: selectedX, runs: runs))) ?? .zero
                            lineSelected = true;
                        }else{
                            lineSelected = false;
                        }
                    }
            }
        }.chartOverlay { _ in
            if getMonthlyDistances(for: allRuns, in: selectedYear)[selectedMonth - 1] == 0 {
                Text("No Data").foregroundStyle(.secondary).font(.system(size: 37))
            }
        }.onChange(of: selectedMonth) {
            lineSelected = false
        }
    }
    
    private func updateLongestRuns() {
        longestRunsPerDay = longestRunPerDay(inMonth: selectedMonth, inYear: selectedYear, runs: runs)
        longestRunsPerDayDict = longestRunPerDayDict(inMonth: selectedMonth, inYear: selectedYear, runs: runs)
    }
    
    
    func longestRunPerDay(inMonth month: Int, inYear year: Int, runs: [RunData]) -> [RunData] {
        let calendar = Calendar.current
        let filteredRuns = runs.filter { run in
            let runMonth = calendar.component(.month, from: run.runStart)
            let runYear = calendar.component(.year, from: run.runStart)
            return runMonth == month && runYear == year
        }
        var runsByDate: [Date: RunData] = [:]
        for run in filteredRuns {
            let dayComponent = calendar.startOfDay(for: run.runStart)
            if let existingRun = runsByDate[dayComponent] {
                if run.runDistanceMeters > existingRun.runDistanceMeters {
                    runsByDate[dayComponent] = run
                }
            } else {
                runsByDate[dayComponent] = run
            }
        }
        return Array(runsByDate.values)
    }
    func longestRunPerDayDict(inMonth month: Int, inYear year: Int, runs: [RunData]) -> [Int: RunData] {
        let calendar = Calendar.current
        let filteredRuns = runs.filter { run in
            let runMonth = calendar.component(.month, from: run.runStart)
            let runYear = calendar.component(.year, from: run.runStart)
            return runMonth == month && runYear == year
        }
        var runsByDate: [Int: RunData] = [:]
        for run in filteredRuns {
            let dayComponent = calendar.component(.day, from: run.runStart)
            if let existingRun = runsByDate[dayComponent] {
                if run.runDistanceMeters > existingRun.runDistanceMeters {
                    runsByDate[dayComponent] = run
                }
            } else {
                runsByDate[dayComponent] = run
            }
        }
        return runsByDate
    }
    
    func longestRunOnDay(inYear year: Int, inMonth month: Int, onDay day: Int, runs: [RunData]) -> Double {
        let calendar = Calendar.current
        let filteredRuns = runs.filter { run in
            let runYear = calendar.component(.year, from: run.runStart)
            let runMonth = calendar.component(.month, from: run.runStart)
            let runDay = calendar.component(.day, from: run.runStart)
            return runYear == year && runMonth == month && runDay == day
        }
        let longestRun = filteredRuns.max(by: { $0.runDistanceMeters < $1.runDistanceMeters })
        return longestRun?.runDistanceMeters ?? 0.0
    }
    func interpolateRunColor(runDistance: Double) -> Color {
        let shortColor = Color(hex: 0x04da0d)
        let mediumColor = Color(hex: 0x96959b)
        let longColor = Color(hex: 0xdf4159)
        
        let recentRuns = allRuns.suffix(10);
        var totalRunDistance = 0.0
        for run in recentRuns {
            totalRunDistance += run.runDistanceMeters
        }
        let averageDistance = totalRunDistance / Double(recentRuns.count)
        guard averageDistance > 0 else { return mediumColor }

        let normalized = runDistance / averageDistance

        let shortThreshold = 0.5
        let longThreshold = 2.0

        if normalized <= shortThreshold {
            return shortColor
        } else if normalized >= longThreshold {
            return longColor
        } else if normalized == 1.0 {
            return mediumColor
        } else {
            if normalized < 1.0 {
                let t = (normalized - shortThreshold) / (1.0 - shortThreshold)
                return blendColors(color1: shortColor, color2: mediumColor, t: t)
            } else {
                let t = (normalized - 1.0) / (longThreshold - 1.0)
                return blendColors(color1: mediumColor, color2: longColor, t: t)
            }
        }
    }

    func blendColors(color1: Color, color2: Color, t: Double) -> Color {
        let uiColor1 = UIColor(color1)
        let uiColor2 = UIColor(color2)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = CGFloat((1 - t)) * r1 + CGFloat(t) * r2
        let g = CGFloat((1 - t)) * g1 + CGFloat(t) * g2
        let b = CGFloat((1 - t)) * b1 + CGFloat(t) * b2
        let a = CGFloat((1 - t)) * a1 + CGFloat(t) * a2

        return Color(.sRGB, red: Double(r), green: Double(g), blue: Double(b), opacity: Double(a))
    }
    func getMonthlyDistances(for runs: [RunData], in year: Int) -> [Double] {
        var monthlyDistances = Array(repeating: 0.0, count: 12)
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                let runMonth = calendar.component(.month, from: run.runStart)
                monthlyDistances[runMonth - 1] += run.runDistanceMeters
            }
        }
        return monthlyDistances
    }
}

struct YearlyChartView: View {
    let selectedYear: Int
    let runs: [RunData]
    let isGroupView: Bool
    
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    var body: some View {
        let unit = (distanceUnit == 0) ? "km" : "miles"
        Chart(getMonthlyDistancesStruct(for: runs, in: selectedYear)) {
            BarMark(x: .value("Month", $0.month.name), y: .value(unit, $0.distance / (isGroupView ? ((distanceUnit == 0) ? 0.621 : 1) : ((distanceUnit == 0) ? 1000 : 1609))))
        }
        .frame(height: 215)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                if let day = value.as(String.self) {
                    AxisValueLabel(day.prefix(1), centered: true, anchor: .top)
                }
            }
        }
        .chartOverlay { _ in
            if getYearlyDistance(for: runs, in: selectedYear) == 0 {
                Text("No Data").foregroundStyle(.secondary).font(.system(size: 37))
            }
        }
    }
    
    func getMonthlyDistancesStruct(for runs: [RunData], in year: Int) -> [MonthlyDistance] {
        var monthlyDistances = Array(repeating: 0.0, count: 12)
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                let runMonth = calendar.component(.month, from: run.runStart)
                monthlyDistances[runMonth - 1] += run.runDistanceMeters
            }
        }
        var result: [MonthlyDistance] = []
        for (index, distance) in monthlyDistances.enumerated() {
            result.append(MonthlyDistance(month: Month(name: calendar.monthSymbols[index], number: index + 1, numDays: 0), distance: distance))
        }
        return result
    }
    
    func getYearlyDistance(for runs: [RunData], in year: Int) -> Double {
        var totalDistance = 0.0
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                totalDistance += run.runDistanceMeters
            }
        }
        return totalDistance
    }
}

struct ChartFooterView: View {
    let selectedMonth: Int
    let selectedYear: Int
    let runs: [RunData]
    let isGroupView: Bool
    @Binding var yearOrMonthSelected: Int
    @AppStorage("distanceUnit") private var distanceUnit = 1
    
    var body: some View {
        HStack {
            Text(footerText).bold()
            Spacer()
            Picker("YM", selection: $yearOrMonthSelected) {
                ForEach(yearMonths, id: \.number) { ym in
                    Text(ym.name)
                }
            }.pickerStyle(.segmented)
        }
    }
    
    private var footerText: String {
        let unit = (distanceUnit == 0) ? "km" : "mi"
        if yearOrMonthSelected == 1 {
            return "\(months[selectedMonth - 1]) Total: \(Int(getMonthlyDistances(for: runs, in: selectedYear)[selectedMonth - 1] / (isGroupView ? ((distanceUnit == 0) ? 0.621 : 1) : ((distanceUnit == 0) ? 1000 : 1609))))" + unit
        } else {
            return "\(selectedYear) Total: \(Int(getYearlyDistance(for: runs, in: selectedYear) / (isGroupView ? ((distanceUnit == 0) ? 0.621 : 1) : ((distanceUnit == 0) ? 1000 : 1609))))" + unit
        }
    }
    
    private let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    
    private let yearMonths = [
        YM(name: "Years", number: 0),
        YM(name: "Months", number: 1)
    ]
    
    func getMonthlyDistances(for runs: [RunData], in year: Int) -> [Double] {
        var monthlyDistances = Array(repeating: 0.0, count: 12)
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                let runMonth = calendar.component(.month, from: run.runStart)
                monthlyDistances[runMonth - 1] += run.runDistanceMeters
            }
        }
        return monthlyDistances
    }
    
    func getYearlyDistance(for runs: [RunData], in year: Int) -> Double {
        var totalDistance = 0.0
        let calendar = Calendar.current
        for run in runs {
            let runYear = calendar.component(.year, from: run.runStart)
            if runYear == year {
                totalDistance += run.runDistanceMeters
            }
        }
        return totalDistance
    }
}
