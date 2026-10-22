import Foundation
import SwiftData

/// Day streak with Duolingo-style freezes.
/// - A day counts when something is logged.
/// - A missed day is bridged automatically by a freeze (if one is left and the streak was alive the day before).
/// - Every 7 logged days in a row earns a freeze; at most `maxFreezes` are kept. New installs of 2.0 start with one.
/// - Frozen days keep the streak alive but don't add to the count.
enum Streak {
    static let maxFreezes = 2
    static let daysPerFreeze = 7

    struct State: Equatable {
        var count = 0
        var best = 0
        var freezes = 0
        var frozen: Set<Date> = []
        var loggedToday = false
    }

    private enum Key {
        static let freezes = "streak.freezes"
        static let frozen = "streak.frozen"
        static let evaluated = "streak.evaluated"
        static let milestone = "streak.milestone"
        static let best = "streak.best"
    }

    /// Brings freezes and the count up to date. Safe to call often.
    static func refresh(ctx: ModelContext, defaults: UserDefaults = .standard) -> State {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let from = cal.date(byAdding: .day, value: -800, to: today)!
        var fetch = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day >= from })
        fetch.propertiesToFetch = [\.day]
        let logged = Set((try? ctx.fetch(fetch))?.map(\.day) ?? [])

        var freezes = defaults.object(forKey: Key.freezes) as? Int ?? 1
        var frozen = Set((defaults.array(forKey: Key.frozen) as? [Double] ?? []).map { Date(timeIntervalSince1970: $0) })
        let firstRun = defaults.object(forKey: Key.evaluated) == nil
        let evaluated = (defaults.object(forKey: Key.evaluated) as? Double).map { Date(timeIntervalSince1970: $0) } ?? yesterday

        // Past days since the last check: freeze what can be saved.
        var d = cal.date(byAdding: .day, value: 1, to: evaluated)!
        while d <= yesterday {
            if !logged.contains(d), freezes > 0 {
                let before = cal.date(byAdding: .day, value: -1, to: d)!
                if logged.contains(before) || frozen.contains(before) {
                    frozen.insert(d)
                    freezes -= 1
                }
            }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }

        // Count back from today (or yesterday while today is still empty).
        let loggedToday = logged.contains(today)
        var day = loggedToday ? today : yesterday
        var count = 0
        while logged.contains(day) || frozen.contains(day) {
            if logged.contains(day) { count += 1 }
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }

        // Earn a freeze for every full week reached since the last milestone.
        let reached = count / daysPerFreeze * daysPerFreeze
        var milestone = defaults.object(forKey: Key.milestone) as? Int ?? reached
        if firstRun { milestone = reached }
        if reached > milestone { freezes = min(maxFreezes, freezes + (reached - milestone) / daysPerFreeze) }
        milestone = reached
        freezes = min(freezes, maxFreezes)

        let best = max(defaults.integer(forKey: Key.best), count)
        defaults.set(freezes, forKey: Key.freezes)
        defaults.set(frozen.map(\.timeIntervalSince1970), forKey: Key.frozen)
        defaults.set(yesterday.timeIntervalSince1970, forKey: Key.evaluated)
        defaults.set(milestone, forKey: Key.milestone)
        defaults.set(best, forKey: Key.best)
        return State(count: count, best: best, freezes: freezes, frozen: frozen, loggedToday: loggedToday)
    }
}
