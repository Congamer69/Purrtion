import Foundation

extension CatMood {
    /// The cat that fits the day best: time of day, how much of the goal is eaten, protein, water, activity, alcohol.
    static func of(entries: [FoodEntry], target: DayTarget, waterML: Int, goals: Goals, day: Date,
                   promille: Double = 0, now: Date = .now) -> CatMood {
        let cal = Calendar.current
        let isToday = cal.isDate(day, inSameDayAs: now)
        let hour = cal.component(.hour, from: now)
        let night = isToday && (hour >= 23 || hour < 5)
        if isToday, promille >= 0.2 { return .tipsy }
        if entries.isEmpty {
            guard isToday, !night else { return .sleeping }
            return hour < 11 ? .yawning : .hungry
        }
        let kcal = entries.reduce(0) { $0 + $1.kcal }
        let protein = entries.reduce(0) { $0 + $1.protein }
        let ratio = kcal / max(target.kcal, 1)
        let proteinOK = protein >= target.protein * 0.9
        if ratio > 1.15 { return .stuffed }
        if ratio > 1.05 { return .full }
        if night { return .sleeping }
        if ratio >= 0.95 { return proteinOK ? .proud : .content }
        if ratio >= 0.85 { return proteinOK ? .proud : .happy }
        guard isToday else { return .idle }
        if target.activeKcal >= 600 { return .sporty }
        if goals.waterEnabled, hour >= 15, Double(waterML) < Double(goals.waterML) * 0.4 { return .thirsty }
        if (hour >= 13 && ratio < 0.35) || (hour >= 18 && ratio < 0.6) { return .hungry }
        return .idle
    }
}
