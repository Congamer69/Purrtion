import Foundation
import SwiftData
import UserNotifications

/// Optional extras from 2.6. Every one has its own switch under Profil → Funktionen.
enum Extras {
    static let weekBudgetKey = "extras.weekBudget"
    static let weekBudgetPctKey = "extras.weekBudgetPct"
    static let timeSuggestKey = "extras.timeSuggestions"
    static let multiScanKey = "extras.multiScan"
    static let forecastKey = "extras.weightForecast"
    static let goalWeightKey = "weight.goal"
    static let reminderKey = "extras.reminder"
    static let reminderMinutesKey = "extras.reminderMinutes"
    static let shopKey = "extras.shop"

    static func bool(_ key: String, default value: Bool) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? value }
}

// MARK: - Weekly budget

/// A day that went over (or under) the goal is spread over the rest of the week, at most ±pct % of the goal per day.
/// Days that already passed keep the goal they had back then, so the history never changes afterwards.
enum WeekBudget {
    static var enabled: Bool { Extras.bool(Extras.weekBudgetKey, default: false) }
    static var pct: Double { min(max(UserDefaults.standard.object(forKey: Extras.weekBudgetPctKey) as? Double ?? 15, 5), 30) }

    private static let totalsKey = "extras.dayTotals"
    private static let adjustKey = "extras.weekAdjust"
    private static var totals: [String: Double] = UserDefaults.standard.dictionary(forKey: totalsKey) as? [String: Double] ?? [:]
    private static var recorded: [String: Double] = UserDefaults.standard.dictionary(forKey: adjustKey) as? [String: Double] ?? [:]

    private static func key(_ d: Date) -> String { String(Int(Calendar.current.startOfDay(for: d).timeIntervalSince1970)) }

    /// Eaten kcal per day of the last two weeks (the app calls this whenever data changes). Returns true when something changed.
    @discardableResult
    static func record(totals new: [Date: Double]) -> Bool {
        var changed = false
        for (day, kcal) in new where abs((totals[key(day)] ?? -1) - kcal) > 0.5 { totals[key(day)] = kcal; changed = true }
        if changed {
            let cutoff = Date().addingTimeInterval(-60 * 86400).timeIntervalSince1970
            totals = totals.filter { (Double($0.key) ?? 0) > cutoff }
            UserDefaults.standard.set(totals, forKey: totalsKey)
        }
        return changed
    }

    /// kcal added to (+) or taken from (−) the goal of `day`. `coreKcal` is the goal of a day without the budget.
    static func adjustment(for day: Date, coreKcal: (Date) -> Double) -> Double {
        guard enabled else { return 0 }
        let cal = Calendar.mondayFirst
        let today = cal.startOfDay(for: .now)
        let d = cal.startOfDay(for: day)
        if d < today { return recorded[key(d)] ?? 0 }
        guard let week = cal.dateInterval(of: .weekOfYear, for: today), d < week.end else { return 0 }
        var surplus = 0.0
        var cursor = week.start
        while cursor < today {
            if let eaten = totals[key(cursor)], eaten > 0 { surplus += eaten - (coreKcal(cursor) + (recorded[key(cursor)] ?? 0)) }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        let daysLeft = max(1, cal.dateComponents([.day], from: today, to: week.end).day ?? 1)
        let limit = coreKcal(d) * pct / 100
        let adj = (min(max(-surplus / Double(daysLeft), -limit), limit) / 5).rounded() * 5
        if d == today, abs((recorded[key(today)] ?? 0) - adj) > 0.5 {
            recorded[key(today)] = adj
            UserDefaults.standard.set(recorded, forKey: adjustKey)
        }
        return adj
    }
}

// MARK: - Suggestions for this time of day

enum TimeSuggestions {
    struct Suggestion: Identifiable {
        let id: String
        let food: FoodItem
        let quantity: Double
        let serving: ServingOption
        let kcal: Double
        let days: Int
    }

    static var enabled: Bool { Extras.bool(Extras.timeSuggestKey, default: true) }

    /// What you usually log around now: foods from the last 60 days within ±90 minutes of the current time of day, most
    /// frequent first. Things already logged today are left out.
    @MainActor
    static func suggestions(ctx: ModelContext, now: Date = .now, limit: Int = 4) -> [Suggestion] {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -60, to: now)!
        let entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.createdAt >= from }, sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        let today = cal.startOfDay(for: now)
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let loggedToday = Set(entries.filter { $0.day == today }.map(\.name))

        func minutes(_ d: Date) -> Int { cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d) }
        var groups: [String: (latest: FoodEntry, days: Set<Date>)] = [:]
        for e in entries where e.day != today && !loggedToday.contains(e.name) {
            var diff = abs(minutes(e.createdAt) - nowMinutes)
            diff = min(diff, 1440 - diff)
            guard diff <= 90 else { continue }
            var g = groups[e.name] ?? (e, [])
            g.days.insert(e.day)
            groups[e.name] = g
        }
        let ranked = groups.values.sorted { ($0.days.count, $0.latest.createdAt) > ($1.days.count, $1.latest.createdAt) }
        let frequent = ranked.filter { $0.days.count >= 2 }
        return (frequent.isEmpty ? ranked : frequent).prefix(limit).compactMap { g in
            guard let food = g.latest.food else { return nil }
            return Suggestion(id: g.latest.name, food: food, quantity: g.latest.quantity,
                              serving: ServingOption(name: g.latest.servingName, grams: g.latest.servingGrams),
                              kcal: g.latest.kcal, days: g.days.count)
        }
    }
}

// MARK: - Weight forecast

enum WeightForecast {
    static var enabled: Bool { Extras.bool(Extras.forecastKey, default: true) }
    static var goalWeight: Double { UserDefaults.standard.double(forKey: Extras.goalWeightKey) }

    struct Result {
        enum Outcome { case reached, onTrack(date: Date, earliest: Date, latest: Date?), wrongDirection, flat, needsData }
        let outcome: Outcome
        let trendKg: Double?
        let perWeek: Double?
    }

    /// Fit through the last six weeks (robust against water-weight spikes). The date comes from today's trend weight and
    /// the slope; the range from the standard error of the slope. Needs three weigh-ins over at least ten days.
    static func forecast(weights: [(date: Date, kg: Double)], goal: Double, now: Date = .now) -> Result {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -42, to: now)!
        let recent = weights.filter { $0.date >= start }.sorted { $0.date < $1.date }
        guard goal > 0, recent.count >= 3, let first = recent.first, now.timeIntervalSince(first.date) >= 10 * 86400 else {
            return Result(outcome: .needsData, trendKg: nil, perWeek: nil)
        }
        let pts = recent.map { (x: $0.date.timeIntervalSince(start) / 86400, y: $0.kg) }
        guard let fit = Expenditure.robustSlope(pts) else { return Result(outcome: .needsData, trendKg: nil, perWeek: nil) }
        let xNow = now.timeIntervalSince(start) / 86400
        let trend = fit.intercept + fit.slope * xNow
        let perWeek = fit.slope * 7
        if (goal <= trend && fit.slope <= 0 && trend - goal < 0.2) || (goal >= trend && fit.slope >= 0 && goal - trend < 0.2) {
            return Result(outcome: .reached, trendKg: trend, perWeek: perWeek)
        }
        // Tiny slopes are noise: under ~50 g a week nothing can be predicted.
        guard abs(perWeek) >= 0.05 else { return Result(outcome: .flat, trendKg: trend, perWeek: perWeek) }
        let needed = goal - trend
        guard needed * fit.slope > 0 else { return Result(outcome: .wrongDirection, trendKg: trend, perWeek: perWeek) }
        func date(_ slope: Double) -> Date? {
            guard slope != 0, needed / slope > 0, needed / slope < 3 * 365 else { return nil }
            return cal.date(byAdding: .day, value: Int((needed / slope).rounded()), to: now)
        }
        let central = date(fit.slope)
        let fast = date(fit.slope + (fit.slope > 0 ? 1 : -1) * 1.0 * fit.slopeSE)
        let slow = date(fit.slope - (fit.slope > 0 ? 1 : -1) * 1.0 * fit.slopeSE)
        guard let central else { return Result(outcome: .flat, trendKg: trend, perWeek: perWeek) }
        return Result(outcome: .onTrack(date: central, earliest: fast ?? central, latest: slow), trendKg: trend, perWeek: perWeek)
    }
}

// MARK: - Gentle reminder

/// A quiet notification from the cat at a chosen time, only while nothing is logged yet. A notification cannot look at the
/// data when it fires, so the ones for the next days are planned ahead and today's is cancelled as soon as something is logged.
@MainActor
enum GentleReminder {
    static var enabled: Bool { Extras.bool(Extras.reminderKey, default: false) }
    static var minutes: Int { UserDefaults.standard.object(forKey: Extras.reminderMinutesKey) as? Int ?? 12 * 60 + 30 }
    private static let prefix = "gentle-"

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Plans the next seven days (skipping today when something is logged already). Safe to call often.
    static func reschedule(ctx: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard enabled else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let loggedToday = ((try? ctx.fetchCount(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == today }))) ?? 0) > 0
        let lines = ["Mochi hat Hunger. Heute ist noch nichts im Napf.", "Der Napf ist noch leer. Magst du etwas eintragen?",
                     "Mochi schnurrt dir zu: Was gab es heute zu essen?", "Kleiner Check-in: Trag kurz ein, was du gegessen hast."]
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  let fire = cal.date(byAdding: .minute, value: minutes, to: day), fire > .now else { continue }
            if offset == 0 && loggedToday { continue }
            let content = UNMutableNotificationContent()
            content.title = "Purrtion 🐾"
            content.body = lines[(cal.ordinality(of: .day, in: .year, for: day) ?? 0) % lines.count]
                .replacingOccurrences(of: "Mochi", with: Pet.isDog ? "Buddy" : "Mochi")
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            try? await center.add(UNNotificationRequest(identifier: prefix + "\(Int(day.timeIntervalSince1970))", content: content,
                                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }
}
