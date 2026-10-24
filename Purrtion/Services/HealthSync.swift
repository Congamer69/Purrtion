import Foundation
import HealthKit
import SwiftData
import WidgetKit

/// Two-way weight sync with Apple Health.
enum HealthSync {
    static let enabledKey = "health.weightSync"
    private static let store = HKHealthStore()
    private static let bodyMass = HKQuantityType(.bodyMass)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static let accessTypes: Set<HKSampleType> = [bodyMass]

    static func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [bodyMass], read: [bodyMass])
    }

    /// Asks again only if iOS has no answer yet (see `NutritionSync.requestAuthorizationIfNeeded`).
    static func requestAuthorizationIfNeeded() async {
        guard isEnabled, isAvailable,
              let status = try? await store.statusForAuthorizationRequest(toShare: [bodyMass], read: [bodyMass]),
              status == .shouldRequest else { return }
        try? await requestAuthorization()
    }

    /// Imports weights from Health that aren't in the app yet (same day = same value).
    @MainActor
    static func importWeights(into ctx: ModelContext) async {
        guard isEnabled, isAvailable else { return }
        let start = Calendar.current.date(byAdding: .year, value: -2, to: .now)!
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMass, predicate: HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: store) else { return }
        let existing = (try? ctx.fetch(FetchDescriptor<WeightLog>())) ?? []
        let existingDays = Set(existing.map { Calendar.current.startOfDay(for: $0.date) })
        var added = Set<Date>()
        for s in samples {
            // skip what we wrote ourselves
            if s.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier { continue }
            let day = Calendar.current.startOfDay(for: s.startDate)
            guard !existingDays.contains(day), !added.contains(day) else { continue }
            added.insert(day)
            let kg = s.quantity.doubleValue(for: .gramUnit(with: .kilo))
            ctx.insert(WeightLog(date: s.startDate, kg: (kg * 10).rounded() / 10))
        }
        if !added.isEmpty { try? ctx.save() }
    }

    static func save(kg: Double, date: Date) {
        guard isEnabled, isAvailable else { return }
        let sample = HKQuantitySample(type: bodyMass, quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                                      start: date, end: date)
        store.save(sample) { _, _ in }
    }
}

/// Writes today's summary for the widgets.
enum WidgetBridge {
    @MainActor
    static func update(_ ctx: ModelContext, goals: Goals) {
        // Water tapped in the widget since the app was last open goes into the database first.
        for (day, ml) in WidgetSnapshot.takePendingWater() where ml > 0 { ctx.insert(WaterLog(day: day, ml: ml)) }
        try? ctx.save()
        let today = Calendar.current.startOfDay(for: .now)
        let entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == today }))) ?? []
        let water = (try? ctx.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.day == today }))) ?? []
        var s = WidgetSnapshot()
        s.day = today
        s.kcal = entries.reduce(0) { $0 + $1.kcal }
        s.protein = entries.reduce(0) { $0 + $1.protein }
        s.carbs = entries.reduce(0) { $0 + $1.carbs }
        s.fat = entries.reduce(0) { $0 + $1.fat }
        let target = goals.target(for: today)
        s.kcalGoal = target.kcal
        s.proteinGoal = target.protein; s.carbsGoal = target.carbs; s.fatGoal = target.fat
        let tomorrow = goals.target(for: Calendar.current.date(byAdding: .day, value: 1, to: today)!)
        s.next = .init(kcal: tomorrow.kcal, protein: tomorrow.protein, carbs: tomorrow.carbs, fat: tomorrow.fat)
        s.accentHex = ThemeSetting.accent.hex
        s.waterStep = goals.waterStep
        // The last seven days for the week view.
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -6, to: today)!
        let recent = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day >= from && $0.day <= today }))) ?? []
        let byDay = Dictionary(grouping: recent, by: \.day)
        s.week = (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i - 6, to: today) else { return nil }
            return WidgetSnapshot.DayPoint(day: d, kcal: (byDay[d] ?? []).reduce(0) { $0 + $1.kcal }, goal: goals.target(for: d).kcal)
        }
        s.waterML = water.reduce(0) { $0 + $1.ml }
        s.waterGoal = goals.waterML
        s.waterEnabled = goals.waterEnabled
        s.entryCount = entries.count
        s.paletteID = UserDefaults.standard.string(forKey: "catPalette") ?? "ginger"
        if goals.healthScoreEnabled, !entries.isEmpty {
            let score = HealthScore(entries: entries, goalKcal: target.kcal, goalProtein: target.protein)
            s.score = score.isPreliminary ? nil : score.score
        }
        s.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
