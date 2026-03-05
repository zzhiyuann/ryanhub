import Foundation

// MARK: - CommuteTrackerViewModel

@Observable
@MainActor
final class CommuteTrackerViewModel {

    var entries: [CommuteTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?
    var goalConfig = CommuteGoalConfig()

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() {
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(bridgeBaseURL)/modules/commuteTracker/data") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([CommuteTrackerEntry].self, from: data)
            entries = decoded
            UserDefaults.standard.set(data, forKey: "dynamic_module_commuteTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: CommuteTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/commuteTracker/data/add") else { return }

        do {
            let body = try JSONEncoder().encode(entry)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: CommuteTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/commuteTracker/data?id=\(entry.id)") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    private var calendar: Calendar { Calendar.current }

    private var today: Date { Date() }

    private func isToday(_ entry: CommuteTrackerEntry) -> Bool {
        guard let d = entry.parsedDate else { return false }
        return calendar.isDateInToday(d)
    }

    private func entriesForDate(_ date: Date) -> [CommuteTrackerEntry] {
        entries.filter {
            guard let d = $0.parsedDate else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }

    private func totalMinutesForDate(_ date: Date) -> Int {
        entriesForDate(date).reduce(0) { $0 + $1.durationMinutes }
    }

    private func weekdayDates(for weekOffset: Int) -> [Date] {
        let now = today
        let weekday = calendar.component(.weekday, from: now)
        // weekday: 1=Sun, 2=Mon ... 7=Sat
        let daysFromMonday = (weekday == 1) ? 6 : weekday - 2
        guard let thisMonday = calendar.date(byAdding: .day, value: -daysFromMonday + (weekOffset * 7), to: now) else { return [] }
        return (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: thisMonday) }
    }

    private func isWeekday(_ date: Date) -> Bool {
        let wd = calendar.component(.weekday, from: date)
        return wd >= 2 && wd <= 6
    }

    // MARK: - Today

    var todayCommutes: [CommuteTrackerEntry] {
        entries.filter { isToday($0) }
            .sorted { $0.departureTime < $1.departureTime }
    }

    var todayTotalMinutes: Int {
        todayCommutes.reduce(0) { $0 + $1.durationMinutes }
    }

    var todayRoundTripComplete: Bool {
        let today = todayCommutes
        let hasToWork = today.contains { $0.direction == .toWork }
        let hasFromWork = today.contains { $0.direction == .fromWork }
        return hasToWork && hasFromWork
    }

    // MARK: - Weekly Averages

    var weeklyAverageMinutes: Double {
        let days = weekdayDates(for: 0)
        let daysWithEntries = days.filter { !entriesForDate($0).isEmpty }
        guard !daysWithEntries.isEmpty else { return 0 }
        let total = daysWithEntries.reduce(0) { $0 + totalMinutesForDate($1) }
        return Double(total) / Double(daysWithEntries.count)
    }

    var previousWeekAverageMinutes: Double {
        let days = weekdayDates(for: -1)
        let daysWithEntries = days.filter { !entriesForDate($0).isEmpty }
        guard !daysWithEntries.isEmpty else { return 0 }
        let total = daysWithEntries.reduce(0) { $0 + totalMinutesForDate($1) }
        return Double(total) / Double(daysWithEntries.count)
    }

    var trendPercentageVsLastWeek: Double {
        let last = previousWeekAverageMinutes
        guard last > 0 else { return 0 }
        return (weeklyAverageMinutes - last) / last * 100
    }

    // MARK: - Streaks

    var currentStreak: Int {
        var streak = 0
        var checkDate = today

        // If today is weekend, start from Friday
        while !isWeekday(checkDate) {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        // Check today first; if no entries today, check if yesterday counts
        if entriesForDate(checkDate).isEmpty {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = prev
            while !isWeekday(checkDate) {
                guard let p = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
                checkDate = p
            }
            if entriesForDate(checkDate).isEmpty { return 0 }
        }

        while true {
            if !isWeekday(checkDate) {
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
                continue
            }
            if entriesForDate(checkDate).isEmpty { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    var longestStreak: Int {
        guard !entries.isEmpty else { return 0 }

        let allDates = Set(entries.compactMap { $0.parsedDate }.map { calendar.startOfDay(for: $0) })
        let sorted = allDates.sorted()
        guard !sorted.isEmpty else { return 0 }

        var longest = 0
        var current = 0
        var checkDate = sorted.first!

        let end = sorted.last!
        while checkDate <= end {
            if isWeekday(checkDate) {
                if allDates.contains(checkDate) {
                    current += 1
                    longest = max(longest, current)
                } else {
                    current = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: checkDate) else { break }
            checkDate = next
        }
        return longest
    }

    // MARK: - Direction Averages

    var averageDurationByDirection: [CommuteDirection: Double] {
        var result: [CommuteDirection: Double] = [:]
        for direction in CommuteDirection.allCases {
            let subset = entries.filter { $0.direction == direction }
            if !subset.isEmpty {
                result[direction] = Double(subset.reduce(0) { $0 + $1.durationMinutes }) / Double(subset.count)
            }
        }
        return result
    }

    // MARK: - Best / Worst Day of Week

    private var avgMinutesByWeekday: [(day: String, avg: Double)] {
        let weekdays = String.orderedWeekdays
        return weekdays.compactMap { day -> (String, Double)? in
            let dayEntries = entries.filter { $0.weekdayName == day }
            guard !dayEntries.isEmpty else { return nil }
            // Group by date, sum per day, then average
            let byDate = Dictionary(grouping: dayEntries) { $0.dateOnly }
            let dailyTotals = byDate.values.map { $0.reduce(0) { $0 + $1.durationMinutes } }
            let avg = Double(dailyTotals.reduce(0, +)) / Double(dailyTotals.count)
            return (day, avg)
        }
    }

    var bestDayOfWeek: String {
        avgMinutesByWeekday.min { $0.avg < $1.avg }?.day ?? ""
    }

    var worstDayOfWeek: String {
        avgMinutesByWeekday.max { $0.avg < $1.avg }?.day ?? ""
    }

    // MARK: - Route Rankings

    var routeRankings: [CommuteRouteSummary] {
        let named = entries.filter { !$0.routeName.isEmpty }
        let grouped = Dictionary(grouping: named) { $0.routeName }
        return grouped.map { (name, trips) -> CommuteRouteSummary in
            let avg = Double(trips.reduce(0) { $0 + $1.durationMinutes }) / Double(trips.count)
            return CommuteRouteSummary(routeName: name, avgMinutes: avg, tripCount: trips.count)
        }
        .sorted { $0.avgMinutes < $1.avgMinutes }
    }

    // MARK: - Transport Mode Breakdown

    var transportModeBreakdown: [(mode: TransportMode, percentage: Double)] {
        guard !entries.isEmpty else { return [] }
        let total = Double(entries.count)
        let grouped = Dictionary(grouping: entries) { $0.transportMode }
        return TransportMode.allCases.compactMap { mode -> (TransportMode, Double)? in
            guard let count = grouped[mode]?.count, count > 0 else { return nil }
            return (mode, Double(count) / total * 100)
        }
        .sorted { $0.1 > $1.1 }
    }

    // MARK: - Monthly / Yearly Totals

    private func entriesInCurrentMonth() -> [CommuteTrackerEntry] {
        let comps = calendar.dateComponents([.year, .month], from: today)
        return entries.filter {
            guard let d = $0.parsedDate else { return false }
            let c = calendar.dateComponents([.year, .month], from: d)
            return c.year == comps.year && c.month == comps.month
        }
    }

    var monthlyTotalCostDollars: Double {
        entriesInCurrentMonth().reduce(0.0) { $0 + $1.costDollars }
    }

    var monthlyTotalHours: Double {
        Double(entriesInCurrentMonth().reduce(0) { $0 + $1.durationMinutes }) / 60.0
    }

    var yearlyTotalHours: Double {
        let year = calendar.component(.year, from: today)
        let yearEntries = entries.filter {
            guard let d = $0.parsedDate else { return false }
            return calendar.component(.year, from: d) == year
        }
        return Double(yearEntries.reduce(0) { $0 + $1.durationMinutes }) / 60.0
    }

    // MARK: - Chart Data

    var dailyChartData: [(date: Date, avgMinutes: Double)] {
        let dates = (0..<30).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }.reversed()
        return dates.compactMap { date -> (Date, Double)? in
            let dayEntries = entriesForDate(date)
            guard !dayEntries.isEmpty else { return nil }
            let avg = Double(dayEntries.reduce(0) { $0 + $1.durationMinutes }) / Double(dayEntries.count)
            return (calendar.startOfDay(for: date), avg)
        }
    }

    var dayOfWeekChartData: [(day: String, avgMinutes: Double)] {
        avgMinutesByWeekday.map { ($0.day, $0.avg) }
    }

    var departureTimeScatterData: [(departureHour: Double, durationMinutes: Int)] {
        entries.map { ($0.departureHour, $0.durationMinutes) }
    }

    // MARK: - Traffic

    var averageTrafficLevel: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.trafficLevel }) / Double(entries.count)
    }

    // MARK: - Goal Progress

    var goalProgress: Double {
        let target = Double(goalConfig.dailyTargetMinutes)
        guard target > 0 else { return 0 }
        return min(Double(todayTotalMinutes) / target, 1.0)
    }

    // MARK: - Insights

    var insightCards: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Streak milestone
        if currentStreak > 0 {
            let isPB = currentStreak >= longestStreak
            result.append(ModuleInsight(
                type: isPB ? .achievement : .trend,
                title: isPB ? "Personal Best Streak! 🏆" : "Logging Streak",
                message: "You've logged commutes for \(currentStreak) consecutive weekday\(currentStreak == 1 ? "" : "s")\(isPB ? " — personal best!" : ".")."
            ))
        }

        // Weekly trend
        if previousWeekAverageMinutes > 0 {
            let pct = abs(trendPercentageVsLastWeek)
            let faster = trendPercentageVsLastWeek < 0
            result.append(ModuleInsight(
                type: faster ? .achievement : .warning,
                title: faster ? "Commute Improving" : "Commute Slower",
                message: String(format: "Your commute averaged %.0f min/day this week — %.0f%% %@ than last week.",
                                weeklyAverageMinutes, pct, faster ? "faster" : "slower")
            ))
        }

        // Best / worst day
        let best = bestDayOfWeek
        let worst = worstDayOfWeek
        if !best.isEmpty && !worst.isEmpty && best != worst {
            let bestAvg = avgMinutesByWeekday.first { $0.day == best }?.avg ?? 0
            let worstAvg = avgMinutesByWeekday.first { $0.day == worst }?.avg ?? 0
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Best & Worst Days",
                message: String(format: "%@s are your fastest (avg %.0f min). %@s are slowest (avg %.0f min).",
                                best, bestAvg, worst, worstAvg)
            ))
        }

        // Fastest route recommendation
        if routeRankings.count >= 2 {
            let fastest = routeRankings[0]
            let slowest = routeRankings[routeRankings.count - 1]
            let saving = slowest.avgMinutes - fastest.avgMinutes
            if saving > 1 {
                result.append(ModuleInsight(
                    type: .suggestion,
                    title: "Fastest Route",
                    message: String(format: "Your \"%@\" route averages %.0f min vs \"%@\" at %.0f min — saving %.0f min per trip.",
                                    fastest.routeName, fastest.avgMinutes, slowest.routeName, slowest.avgMinutes, saving)
                ))
            }
        }

        // Optimal departure window
        let scatter = departureTimeScatterData
        if scatter.count >= 5 {
            let buckets = Dictionary(grouping: scatter) { Int($0.departureHour * 4) } // 15-min buckets
            let bestBucket = buckets.min { a, b in
                let avgA = Double(a.value.reduce(0) { $0 + $1.durationMinutes }) / Double(a.value.count)
                let avgB = Double(b.value.reduce(0) { $0 + $1.durationMinutes }) / Double(b.value.count)
                return avgA < avgB
            }
            if let bucket = bestBucket, bucket.value.count >= 3 {
                let hour = bucket.key / 4
                let minute = (bucket.key % 4) * 15
                let avgMin = Double(bucket.value.reduce(0) { $0 + $1.durationMinutes }) / Double(bucket.value.count)
                result.append(ModuleInsight(
                    type: .suggestion,
                    title: "Optimal Departure Time",
                    message: String(format: "Leaving around %d:%02d averages only %.0f min — one of your shortest commute windows.",
                                    hour, minute, avgMin)
                ))
            }
        }

        // Monthly cost
        if monthlyTotalCostDollars > 0 {
            let yearlyProjection = monthlyTotalCostDollars * 12
            result.append(ModuleInsight(
                type: .trend,
                title: "Monthly Commute Cost",
                message: String(format: "You spent $%.2f on commuting this month. At this rate, ~$%.0f/year.",
                                monthlyTotalCostDollars, yearlyProjection)
            ))
        }

        // Time cost awareness
        if yearlyTotalHours > 0 {
            let days = yearlyTotalHours / 24.0
            result.append(ModuleInsight(
                type: .trend,
                title: "Time Cost of Commuting",
                message: String(format: "You've spent %.0f hours commuting this year — equivalent to %.1f full days.",
                                yearlyTotalHours, days)
            ))
        }

        // Traffic correlation
        let highTrafficEntries = entries.filter { $0.trafficLevel >= 4 }
        let lowTrafficEntries = entries.filter { $0.trafficLevel <= 2 }
        if highTrafficEntries.count >= 3 && lowTrafficEntries.count >= 3 {
            let highAvg = Double(highTrafficEntries.reduce(0) { $0 + $1.durationMinutes }) / Double(highTrafficEntries.count)
            let lowAvg = Double(lowTrafficEntries.reduce(0) { $0 + $1.durationMinutes }) / Double(lowTrafficEntries.count)
            let diff = highAvg - lowAvg
            if diff > 2 {
                result.append(ModuleInsight(
                    type: .warning,
                    title: "Traffic Impact",
                    message: String(format: "When traffic is rated 4–5, your commute averages %.0f min longer than in light traffic.",
                                    diff)
                ))
            }
        }

        // Direction asymmetry
        let toWorkAvg = averageDurationByDirection[.toWork] ?? 0
        let fromWorkAvg = averageDurationByDirection[.fromWork] ?? 0
        if toWorkAvg > 0 && fromWorkAvg > 0 {
            let diff = abs(fromWorkAvg - toWorkAvg)
            if diff > 3 {
                let longer = fromWorkAvg > toWorkAvg ? "return" : "morning"
                result.append(ModuleInsight(
                    type: .trend,
                    title: "Direction Asymmetry",
                    message: String(format: "Your %@ commute averages %.0f min longer than the other direction.",
                                    longer, diff)
                ))
            }
        }

        // Transport mode comparison (driving vs transit)
        let drivingEntries = entries.filter { $0.transportMode == .driving }
        let transitEntries = entries.filter { $0.transportMode == .publicTransit }
        if drivingEntries.count >= 3 && transitEntries.count >= 3 {
            let drivingAvg = Double(drivingEntries.reduce(0) { $0 + $1.durationMinutes }) / Double(drivingEntries.count)
            let transitAvg = Double(transitEntries.reduce(0) { $0 + $1.durationMinutes }) / Double(transitEntries.count)
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Transit vs Driving",
                message: String(format: "Public transit trips average %.0f min vs driving at %.0f min.",
                                transitAvg, drivingAvg)
            ))
        }

        return result
    }

    // MARK: - View Compatibility

    var todayEntries: [CommuteTrackerEntry] { todayCommutes }

    var isActiveToday: Bool { !todayCommutes.isEmpty }

    var totalCommutes: Int { entries.count }

    var averageDurationMinutes: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.durationMinutes }) / Double(entries.count)
    }

    var totalCostDollars: Double {
        entries.reduce(0.0) { $0 + $1.costDollars }
    }

    var averageDelayMinutes: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.delayMinutes }) / Double(entries.count)
    }

    var mostUsedTransportMode: TransportMode? {
        transportModeBreakdown.first?.mode
    }

    var averageExperienceRating: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.experienceRating }) / Double(entries.count)
    }

    var toWorkCount: Int {
        entries.filter { $0.direction == .toWork }.count
    }

    var fromWorkCount: Int {
        entries.filter { $0.direction == .fromWork }.count
    }

    var delayedCommuteCount: Int {
        entries.filter { $0.hasDelay }.count
    }

    var calendarData: [Date: Double] {
        var map: [Date: Double] = [:]
        for entry in entries {
            guard let d = entry.parsedDate else { continue }
            let day = calendar.startOfDay(for: d)
            map[day, default: 0] += 1
        }
        return map
    }

    var heatmapData: [Date: Double] { calendarData }

    var weeklyChartData: [ChartDataPoint] {
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "E"
        return (0..<7).reversed().map { offset -> ChartDataPoint in
            let day = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayEntries = entriesForDate(day)
            let avg = dayEntries.isEmpty ? 0 : Double(dayEntries.reduce(0) { $0 + $1.durationMinutes }) / Double(dayEntries.count)
            return ChartDataPoint(label: displayFmt.string(from: day), value: avg)
        }
    }

    var insights: [ModuleInsight] { insightCards }
}