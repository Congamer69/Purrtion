import Foundation

/// Small summary of today that the app writes and the widgets read (via the shared App Group).
struct WidgetSnapshot: Codable {
    /// The App Group shared by the app and the widgets. SideStore re-signs with a free Apple ID and renames the group
    /// (it appends the team ID), so the name is not known at build time. Candidates, in order: what `ALTAppGroups` in the
    /// Info.plist says, the groups in the embedded provisioning profile (that is what the signature really allows) and the
    /// original name. The first one iOS gives a shared container for wins; app and widget find the same one.
    static let appGroup: String = {
        let original = "group.com.const.purrtion"
        var candidates = provisionedGroups()
        candidates += (Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String]) ?? []
        candidates.append(original)
        for group in candidates where FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil { return group }
        return original
    }()

    /// `com.apple.security.application-groups` from this bundle's embedded.mobileprovision (empty for builds without one).
    private static func provisionedGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"), let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)), let end = data.range(of: Data("</plist>".utf8)),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return [] }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }
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
    /// Goals of the next day without any activity bonus (that day has no activity yet). After midnight the widget shows
    /// these instead of today's goal, which still contained yesterday's active calories until the app was opened.
    var next: NextGoals? = nil
    /// The last days for the week view of the widget.
    var week: [DayPoint]? = nil
    /// The accent colour chosen in the app (RRGGBB); the widget cannot read the app's settings.
    var accentHex: UInt32? = nil
    var waterStep: Int? = nil

    struct NextGoals: Codable { var kcal: Double; var protein: Double; var carbs: Double; var fat: Double }
    struct DayPoint: Codable { var day: Date; var kcal: Double; var goal: Double }

    /// Values for today – a snapshot from yesterday counts as an empty day.
    var forToday: WidgetSnapshot { values(on: .now) }

    /// Values as they will be shown on `date`: anything recorded for an earlier day counts as empty.
    func values(on date: Date) -> WidgetSnapshot {
        let target = Calendar.current.startOfDay(for: date)
        guard day < target else { return self }
        var s = self
        // Yesterday becomes part of the week.
        var points = (week ?? []).filter { $0.day != day }
        points.append(DayPoint(day: day, kcal: kcal, goal: kcalGoal))
        s.week = points.filter { $0.day < target }.suffix(7).map { $0 }
        s.day = target
        s.kcal = 0; s.protein = 0; s.carbs = 0; s.fat = 0; s.waterML = 0; s.score = nil; s.entryCount = 0
        if let n = next { s.kcalGoal = n.kcal; s.proteinGoal = n.protein; s.carbsGoal = n.carbs; s.fatGoal = n.fat }
        s.next = nil
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

// MARK: Water added from the widget

extension WidgetSnapshot {
    private static let pendingKey = "widget.pendingWater"

    /// The "+ water" button of the widget: updates what the widgets show right away and queues the amount for the app,
    /// which writes it into its database the next time it opens (the database is not reachable from the widget).
    static func addWater(_ ml: Int) {
        var snapshot = load().forToday
        snapshot.waterML += ml
        snapshot.save()
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        var pending = defaults.dictionary(forKey: pendingKey) as? [String: Int] ?? [:]
        let day = String(Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970))
        pending[day, default: 0] += ml
        defaults.set(pending, forKey: pendingKey)
    }

    /// Amounts waiting for the app, by day. Clears the queue.
    static func takePendingWater() -> [(day: Date, ml: Int)] {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let pending = defaults.dictionary(forKey: pendingKey) as? [String: Int] else { return [] }
        defaults.removeObject(forKey: pendingKey)
        return pending.compactMap { key, ml in Double(key).map { (Date(timeIntervalSince1970: $0), ml) } }
    }
}
