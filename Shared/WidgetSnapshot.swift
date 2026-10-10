import Foundation

/// Small summary of today that the app writes and the widgets read (via the shared App Group).
struct WidgetSnapshot: Codable {
    static let appGroup = "group.com.const.purrtion"
    static let key = "widget.snapshot"

    var day: Date = Calendar.current.startOfDay(for: .now)
    var kcal: Double = 0
    var kcalGoal: Double = 2000
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var proteinGoal: Double = 120
    var carbsGoal: Double = 220
    var fatGoal: Double = 70
    var waterML: Int = 0
    var waterGoal: Int = 2500
    var waterEnabled = true
    var score: Int?
    var paletteID = "ginger"
    var entryCount = 0

    /// Values for today – a snapshot from yesterday counts as an empty day.
    var forToday: WidgetSnapshot {
        guard !Calendar.current.isDateInToday(day) else { return self }
        var s = self
        s.day = Calendar.current.startOfDay(for: .now)
        s.kcal = 0; s.protein = 0; s.carbs = 0; s.fat = 0; s.waterML = 0; s.score = nil; s.entryCount = 0
        return s
    }

    var remaining: Double { kcalGoal - kcal }
    var progress: Double { kcal / max(kcalGoal, 1) }

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key),
              let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return s
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.appGroup)?.set(data, forKey: Self.key)
    }
}
