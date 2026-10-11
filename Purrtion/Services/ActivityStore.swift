import Foundation
import HealthKit

/// Active energy per day from Apple Health (Fitness rings), cached so past days work offline.
enum ActivityStore {
    private static let cacheKey = "activity.cache"
    /// Manually added activity (e.g. workouts without a watch), per day.
    private static let manualKey = "activity.manual"
    private static let store = HKHealthStore()
    private static let type = HKQuantityType(.activeEnergyBurned)
    private static let basalType = HKQuantityType(.basalEnergyBurned)
    private static let basalKey = "activity.basalCache"

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static var cache: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: cacheKey) }
    }

    /// Active energy from Apple Health.
    static func kcal(for day: Date) -> Double { cache[formatter.string(from: day)] ?? 0 }

    /// Resting energy from Apple Health (0 when unknown).
    static func basal(for day: Date) -> Double { basalCache[formatter.string(from: day)] ?? 0 }

    private static var basalCache: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: basalKey) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: basalKey) }
    }

    static func manual(for day: Date) -> Double { manualStore[formatter.string(from: day)] ?? 0 }

    static func setManual(_ kcal: Double, for day: Date) {
        var m = manualStore
        m[formatter.string(from: day)] = kcal > 0 ? kcal.rounded() : nil
        manualStore = m
    }

    private static var manualStore: [String: Double] {
        get { UserDefaults.standard.dictionary(forKey: manualKey) as? [String: Double] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: manualKey) }
    }

    #if DEBUG
    /// Simulator testing: plausible active energy for the last weeks.
    static func seedDemo() {
        var c = cache
        var b = basalCache
        for i in 0..<40 {
            let day = Calendar.current.date(byAdding: .day, value: -i, to: .now)!
            c[formatter.string(from: day)] = Double([420, 310, 650, 280, 520, 380, 720][i % 7])
            b[formatter.string(from: day)] = Double([1690, 1710, 1680, 1700, 1720, 1695, 1705][i % 7])
        }
        cache = c
        basalCache = b
    }
    #endif

    static func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: [type, basalType])
    }

    /// Loads daily sums for the last `days` days into the cache.
    @discardableResult
    static func refresh(days: Int = 120) async -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-fakeActivity") { seedDemo(); return true }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))!
        let start = cal.date(byAdding: .day, value: -days, to: end)!
        func sums(_ t: HKQuantityType) async -> [String: Double]? {
            let descriptor = HKStatisticsCollectionQueryDescriptor(
                predicate: .quantitySample(type: t, predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
                options: .cumulativeSum, anchorDate: start, intervalComponents: DateComponents(day: 1))
            guard let collection = try? await descriptor.result(for: store) else { return nil }
            var out: [String: Double] = [:]
            collection.enumerateStatistics(from: start, to: end) { stats, _ in
                out[formatter.string(from: stats.startDate)] = (stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0).rounded()
            }
            return out
        }
        guard let active = await sums(type) else { return false }
        var c = cache
        c.merge(active) { _, new in new }
        if let basal = await sums(basalType) {
            var b = basalCache
            b.merge(basal) { _, new in new }
            basalCache = b
        }
        cache = c
        return true
    }
}
