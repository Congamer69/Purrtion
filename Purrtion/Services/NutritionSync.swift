import Foundation
import HealthKit
import SwiftData

/// Writes every logged entry as a food record (energy, macros, micronutrients) and the daily water to Apple Health.
/// Each entry has a stable sync identifier, so edits replace the record and deleted entries are removed again.
enum NutritionSync {
    static let enabledKey = "health.nutritionSync"
    private static let store = HKHealthStore()
    private static let hashKey = "health.nutritionHashes"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) && HKHealthStore.isHealthDataAvailable() }

    private static let macroTypes: [(HKQuantityTypeIdentifier, HKUnit, (Nutrients) -> Double?)] = [
        (.dietaryEnergyConsumed, .kilocalorie(), { $0.kcal }),
        (.dietaryProtein, .gram(), { $0.protein }),
        (.dietaryCarbohydrates, .gram(), { $0.carbs }),
        (.dietaryFatTotal, .gram(), { $0.fat }),
    ]

    private static let microTypes: [NutrientKey: HKQuantityTypeIdentifier] = [
        .sugar: .dietarySugar, .fiber: .dietaryFiber, .saturatedFat: .dietaryFatSaturated,
        .monoFat: .dietaryFatMonounsaturated, .polyFat: .dietaryFatPolyunsaturated, .cholesterol: .dietaryCholesterol,
        .sodium: .dietarySodium, .potassium: .dietaryPotassium, .calcium: .dietaryCalcium, .magnesium: .dietaryMagnesium,
        .iron: .dietaryIron, .zinc: .dietaryZinc, .phosphorus: .dietaryPhosphorus, .iodine: .dietaryIodine,
        .selenium: .dietarySelenium, .copper: .dietaryCopper, .manganese: .dietaryManganese,
        .vitaminA: .dietaryVitaminA, .vitaminC: .dietaryVitaminC, .vitaminD: .dietaryVitaminD, .vitaminE: .dietaryVitaminE,
        .vitaminK: .dietaryVitaminK, .vitaminB1: .dietaryThiamin, .vitaminB2: .dietaryRiboflavin, .vitaminB3: .dietaryNiacin,
        .vitaminB5: .dietaryPantothenicAcid, .vitaminB6: .dietaryVitaminB6, .biotin: .dietaryBiotin,
        .vitaminB12: .dietaryVitaminB12, .folate: .dietaryFolate, .caffeine: .dietaryCaffeine,
    ]

    private static func unit(_ key: NutrientKey) -> HKUnit {
        switch key.unit {
        case "mg": .gramUnit(with: .milli)
        case "µg": .gramUnit(with: .micro)
        default: .gram()
        }
    }

    private static var shareTypes: Set<HKSampleType> {
        var s = Set<HKSampleType>(macroTypes.map { HKQuantityType($0.0) })
        for id in microTypes.values { s.insert(HKQuantityType(id)) }
        s.insert(HKQuantityType(.dietaryWater))
        return s
    }

    static func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: [])
    }

    private static var hashes: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: hashKey) as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: hashKey) }
    }

    private static var pending: Set<Date> = []
    private static var task: Task<Void, Never>?

    /// Debounced sync of one day (called whenever the entries of a day change).
    @MainActor
    static func schedule(_ day: Date, container: ModelContainer) {
        guard isEnabled else { return }
        pending.insert(Calendar.current.startOfDay(for: day))
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            let days = pending
            pending = []
            for d in days { await sync(day: d, ctx: container.mainContext) }
        }
    }

    /// Syncs the last `days` days (on launch and when switched on).
    @MainActor
    static func syncRecent(days: Int, container: ModelContainer) async {
        guard isEnabled else { return }
        let today = Calendar.current.startOfDay(for: .now)
        for i in 0..<days {
            await sync(day: Calendar.current.date(byAdding: .day, value: -i, to: today)!, ctx: container.mainContext)
        }
    }

    private static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    @MainActor
    static func sync(day: Date, ctx: ModelContext) async {
        guard isEnabled else { return }
        let cal = Calendar.current
        let d = cal.startOfDay(for: day)
        let next = cal.date(byAdding: .day, value: 1, to: d)!
        let entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == d }))) ?? []
        let water = ((try? ctx.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.day == d }))) ?? []).reduce(0) { $0 + $1.ml }

        // What Purrtion wrote for that day so far.
        let foodPredicate = HKQuery.predicateForSamples(withStart: d, end: next)
        let ours = HKQuery.predicateForObjects(from: HKSource.default())
        let both = NSCompoundPredicate(andPredicateWithSubpredicates: [foodPredicate, ours])
        let existingFood = (try? await HKSampleQueryDescriptor(
            predicates: [.correlation(type: HKCorrelationType(.food), predicate: both)], sortDescriptors: []).result(for: store)) ?? []
        let existingWater = (try? await HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.dietaryWater), predicate: both)], sortDescriptors: []).result(for: store)) ?? []

        var stored = hashes
        var toSave: [HKObject] = []
        var keep = Set<String>()
        for e in entries {
            let syncID = "purrtion-\(e.id.uuidString)"
            keep.insert(syncID)
            let n = e.nutrients
            let time = e.createdAt >= d && e.createdAt < next ? e.createdAt : cal.date(byAdding: .hour, value: 12, to: d)!
            let hash = contentHash(n, name: e.name, time: time)
            let existing = existingFood.first { $0.metadata?[HKMetadataKeySyncIdentifier] as? String == syncID }
            if existing != nil, stored[syncID] == hash { continue }
            let version = ((existing?.metadata?[HKMetadataKeySyncVersion] as? NSNumber)?.intValue ?? 0) + 1
            if let c = correlation(n, name: e.name, time: time, syncID: syncID, version: version) {
                // Replace explicitly, so the old nutrient samples inside the record go away too.
                if let existing { try? await store.delete(Array(existing.objects) + [existing]) }
                toSave.append(c)
                stored[syncID] = hash
            }
        }
        let waterID = "purrtion-water-\(dayKey(d))"
        if water > 0 {
            keep.insert(waterID)
            let existing = existingWater.first { $0.metadata?[HKMetadataKeySyncIdentifier] as? String == waterID }
            if existing == nil || stored[waterID] != water {
                let version = ((existing?.metadata?[HKMetadataKeySyncVersion] as? NSNumber)?.intValue ?? 0) + 1
                let t = cal.date(byAdding: .hour, value: 12, to: d)!
                toSave.append(HKQuantitySample(type: HKQuantityType(.dietaryWater),
                                               quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(water)),
                                               start: t, end: t,
                                               metadata: [HKMetadataKeySyncIdentifier: waterID, HKMetadataKeySyncVersion: version]))
                stored[waterID] = water
            }
        }
        if !toSave.isEmpty { try? await store.save(toSave) }

        // Remove records of deleted entries (a food correlation is deleted together with its samples).
        let orphans: [HKObject] = (existingFood as [HKSample] + existingWater as [HKSample]).filter {
            guard let id = $0.metadata?[HKMetadataKeySyncIdentifier] as? String else { return false }
            return !keep.contains(id)
        }
        for o in orphans {
            if let c = o as? HKCorrelation { try? await store.delete(Array(c.objects) + [c]) } else { try? await store.delete(o) }
            if let id = o.metadata?[HKMetadataKeySyncIdentifier] as? String { stored[id] = nil }
        }
        hashes = stored
    }

    private static func contentHash(_ n: Nutrients, name: String, time: Date) -> Int {
        var h = Hasher()
        h.combine(name)
        h.combine(Int(time.timeIntervalSince1970))
        h.combine(Int(n.kcal * 10)); h.combine(Int(n.protein * 10)); h.combine(Int(n.carbs * 10)); h.combine(Int(n.fat * 10))
        for k in n.extra.keys.sorted() { h.combine(k); h.combine(Int((n.extra[k] ?? 0) * 100)) }
        return h.finalize()
    }

    private static func correlation(_ n: Nutrients, name: String, time: Date, syncID: String, version: Int) -> HKCorrelation? {
        var samples = Set<HKSample>()
        func add(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) {
            guard value > 0, value.isFinite else { return }
            samples.insert(HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: unit, doubleValue: value),
                                            start: time, end: time, metadata: [HKMetadataKeyFoodType: name]))
        }
        for (id, unit, get) in macroTypes { add(id, unit, get(n) ?? 0) }
        for (key, id) in microTypes { add(id, unit(key), n[key] ?? 0) }
        guard !samples.isEmpty else { return nil }
        return HKCorrelation(type: HKCorrelationType(.food), start: time, end: time, objects: samples,
                             metadata: [HKMetadataKeyFoodType: name, HKMetadataKeySyncIdentifier: syncID,
                                        HKMetadataKeySyncVersion: version])
    }
}
