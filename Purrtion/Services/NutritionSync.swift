import Foundation
import HealthKit
import CryptoKit
import SwiftData

/// Writes every logged entry as a food record (energy, macros, micronutrients) and the daily water to Apple Health.
/// Each entry has a stable sync identifier, so edits replace the record and deleted entries are removed again.
enum NutritionSync {
    static let enabledKey = "health.nutritionSync"
    private static let store = HKHealthStore()
    private static let hashKey = "health.nutritionHashes.v2"

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

    static var shareTypes: Set<HKSampleType> {
        var s = Set<HKSampleType>(macroTypes.map { HKQuantityType($0.0) })
        for id in microTypes.values { s.insert(HKQuantityType(id)) }
        s.insert(HKQuantityType(.dietaryWater))
        return s
    }

    static func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: [])
    }

    /// Asks again only if iOS has no answer yet. A re-signed app (SideStore refresh, new profile) can lose its answer,
    /// and then every write fails quietly until the question is asked again. Shows nothing when access is already decided.
    static func requestAuthorizationIfNeeded() async {
        guard isEnabled,
              let status = try? await store.statusForAuthorizationRequest(toShare: shareTypes, read: []),
              status == .shouldRequest else { return }
        try? await requestAuthorization()
    }

    /// The last error when writing to Apple Health failed (shown in the settings), nil when the last write worked.
    static let lastErrorKey = "health.lastError"

    private static var hashes: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: hashKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: hashKey) }
    }

    private static var pending: Set<Date> = []
    private static var task: Task<Void, Never>?
    /// All writes run one after another. Two syncs of the same day at once would both see "nothing there yet" and
    /// both write – that is how entries ended up in Apple Health several times.
    private static var queue: Task<Void, Never>?

    @MainActor
    private static func serialized(_ work: @escaping @MainActor () async -> Void) async {
        let previous = queue
        let next = Task { @MainActor in
            await previous?.value
            await work()
        }
        queue = next
        await next.value
    }

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

    /// Syncs the last `days` days (on launch and when switched on). Repairs older duplicates once.
    @MainActor
    static func syncRecent(days: Int, container: ModelContainer) async {
        guard isEnabled else { return }
        if !UserDefaults.standard.bool(forKey: repairKey) {
            await repair(container: container)
            return
        }
        let today = Calendar.current.startOfDay(for: .now)
        for i in 0..<days {
            await sync(day: Calendar.current.date(byAdding: .day, value: -i, to: today)!, ctx: container.mainContext)
        }
    }

    // MARK: Repair (1.7.2)

    private static let repairKey = "health.nutritionRepaired.v2"
    @MainActor static private(set) var repairStatus: String?

    /// Versions before 1.7.2 wrote entries again on every app start, so Apple Health holds the same food many times.
    /// Removes everything Purrtion ever wrote there (only its own data, nothing from other apps) and writes every
    /// logged day once again, cleanly.
    @MainActor
    static func repair(container: ModelContainer) async {
        guard isEnabled else { return }
        await serialized {
            repairStatus = "Bereinige Apple Health …"
            let ours = HKQuery.predicateForObjects(from: HKSource.default())
            for type in shareTypes { _ = try? await store.deleteObjects(of: type, predicate: ours) }
            _ = try? await store.deleteObjects(of: HKCorrelationType(.food), predicate: ours)
            hashes = [:]
            let ctx = container.mainContext
            let days = Set(((try? ctx.fetch(FetchDescriptor<FoodEntry>())) ?? []).map(\.day))
                .union(((try? ctx.fetch(FetchDescriptor<WaterLog>())) ?? []).map(\.day))
            for (i, d) in days.sorted().enumerated() {
                repairStatus = "Schreibe Tag \(i + 1) von \(days.count) neu …"
                await write(day: d, ctx: ctx, existingFood: [], existingWater: [])
            }
            UserDefaults.standard.set(true, forKey: repairKey)
            repairStatus = nil
        }
    }

    private static func dayKey(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    @MainActor
    static func sync(day: Date, ctx: ModelContext) async {
        guard isEnabled else { return }
        await serialized {
            let cal = Calendar.current
            let d = cal.startOfDay(for: day)
            let next = cal.date(byAdding: .day, value: 1, to: d)!
            // What Purrtion wrote for that day so far.
            let both = NSCompoundPredicate(andPredicateWithSubpredicates: [
                HKQuery.predicateForSamples(withStart: d, end: next), HKQuery.predicateForObjects(from: HKSource.default())])
            let existingFood = (try? await HKSampleQueryDescriptor(
                predicates: [.correlation(type: HKCorrelationType(.food), predicate: both)], sortDescriptors: []).result(for: store)) ?? []
            let existingWater = (try? await HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: HKQuantityType(.dietaryWater), predicate: both)], sortDescriptors: []).result(for: store)) ?? []
            await write(day: d, ctx: ctx, existingFood: existingFood, existingWater: existingWater)
        }
    }

    /// Writes one day: new and changed entries, removes deleted ones and any duplicates.
    @MainActor
    private static func write(day d: Date, ctx: ModelContext, existingFood: [HKCorrelation], existingWater: [HKQuantitySample]) async {
        let cal = Calendar.current
        let next = cal.date(byAdding: .day, value: 1, to: d)!
        let entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day == d }))) ?? []
        let water = ((try? ctx.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.day == d }))) ?? []).reduce(0) { $0 + $1.ml }
        func id(_ o: HKObject) -> String? { o.metadata?[HKMetadataKeySyncIdentifier] as? String }

        var stored = hashes
        var toSave: [HKObject] = []
        var toDelete: [HKObject] = []
        var keep = Set<String>()
        // Versions only ever grow, so Apple Health always takes the newest write.
        let version = Int(Date().timeIntervalSince1970 * 1000)
        for e in entries {
            let syncID = "purrtion-\(e.id.uuidString)"
            keep.insert(syncID)
            let n = e.nutrients
            let time = e.createdAt >= d && e.createdAt < next ? e.createdAt : cal.date(byAdding: .hour, value: 12, to: d)!
            let hash = contentHash(n, name: e.name, time: time)
            let existing = existingFood.filter { id($0) == syncID }
            if existing.count == 1, stored[syncID] == hash { continue }
            // Replace explicitly (also every duplicate), so the old nutrient samples inside the record go away too.
            for c in existing { toDelete += Array(c.objects) + [c] }
            if let c = correlation(n, name: e.name, time: time, syncID: syncID, version: version) {
                toSave.append(c)
                stored[syncID] = hash
            }
        }
        let waterID = "purrtion-water-\(dayKey(d))"
        let waterHash = "w\(water)"
        let existingW = existingWater.filter { id($0) == waterID }
        if water > 0 {
            keep.insert(waterID)
            if existingW.count != 1 || stored[waterID] != waterHash {
                toDelete += existingW
                let t = cal.date(byAdding: .hour, value: 12, to: d)!
                toSave.append(HKQuantitySample(type: HKQuantityType(.dietaryWater),
                                               quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(water)),
                                               start: t, end: t,
                                               metadata: [HKMetadataKeySyncIdentifier: waterID, HKMetadataKeySyncVersion: version]))
                stored[waterID] = waterHash
            }
        }
        // Records of deleted entries (a food correlation is deleted together with its samples).
        for o in existingFood where !keep.contains(id(o) ?? "") { toDelete += Array(o.objects) + [o]; stored[id(o) ?? ""] = nil }
        for o in existingWater where !keep.contains(id(o) ?? "") { toDelete.append(o); stored[id(o) ?? ""] = nil }

        // Only a write that worked counts as synced, so a failed one (no permission) is tried again next time.
        do {
            if !toDelete.isEmpty { try await store.delete(toDelete) }
            if !toSave.isEmpty { try await store.save(toSave) }
            hashes = stored
            UserDefaults.standard.removeObject(forKey: lastErrorKey)
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: lastErrorKey)
        }
    }

    /// Stable across app starts (Swift's Hasher is seeded randomly per launch, which made every entry look changed).
    private static func contentHash(_ n: Nutrients, name: String, time: Date) -> String {
        var parts = [name, "\(Int(time.timeIntervalSince1970))", "\(Int(n.kcal * 10))", "\(Int(n.protein * 10))",
                     "\(Int(n.carbs * 10))", "\(Int(n.fat * 10))"]
        for k in n.extra.keys.sorted() { parts.append("\(k)=\(Int((n.extra[k] ?? 0) * 100))") }
        return SHA256.hash(data: Data(parts.joined(separator: "|").utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func correlation(_ n: Nutrients, name: String, time: Date, syncID: String, version: Int) -> HKCorrelation? {
        var samples = Set<HKSample>()
        func add(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ value: Double) {
            guard value > 0, value.isFinite else { return }
            // Each nutrient value has its own sync identifier too: even if a write is repeated, Apple Health replaces
            // it instead of adding it a second time.
            samples.insert(HKQuantitySample(type: HKQuantityType(id), quantity: HKQuantity(unit: unit, doubleValue: value),
                                            start: time, end: time,
                                            metadata: [HKMetadataKeyFoodType: name, HKMetadataKeySyncIdentifier: "\(syncID)-\(id.rawValue)",
                                                       HKMetadataKeySyncVersion: version]))
        }
        for (id, unit, get) in macroTypes { add(id, unit, get(n) ?? 0) }
        for (key, id) in microTypes { add(id, unit(key), n[key] ?? 0) }
        guard !samples.isEmpty else { return nil }
        return HKCorrelation(type: HKCorrelationType(.food), start: time, end: time, objects: samples,
                             metadata: [HKMetadataKeyFoodType: name, HKMetadataKeySyncIdentifier: syncID,
                                        HKMetadataKeySyncVersion: version])
    }
}

/// Asks for every Apple Health permission Purrtion can use in ONE request, so iOS shows a single sheet with weight,
/// nutrition and activity together (separate requests could leave one of them out), and says what went wrong in plain words.
enum HealthAccess {
    private static let store = HKHealthStore()

    private static var shareTypes: Set<HKSampleType> { HealthSync.accessTypes.union(NutritionSync.shareTypes) }
    private static var readTypes: Set<HKObjectType> { Set(HealthSync.accessTypes).union(ActivityStore.readTypes) }

    @MainActor
    static func requestAll() async -> String {
        guard HKHealthStore.isHealthDataAvailable() else { return "Apple Health gibt es auf diesem Gerät nicht." }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            return "Anfrage fehlgeschlagen: \(error.localizedDescription) Das passiert, wenn die App ohne Health-Berechtigung installiert wurde (SideStore ohne HealthKit)."
        }
        return "Angefragt. Fragt iOS nichts mehr, sind die Rechte schon entschieden. Ändern kannst du sie in der Health-App unter Teilen → Apps → Purrtion."
    }

    /// At launch: asks only for what an enabled feature needs and iOS has no answer for yet. Shows nothing otherwise.
    static func requestIfNeeded(activityEnabled: Bool) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        var share = Set<HKSampleType>()
        var read = Set<HKObjectType>()
        if HealthSync.isEnabled { share.formUnion(HealthSync.accessTypes); read.formUnion(HealthSync.accessTypes) }
        if NutritionSync.isEnabled { share.formUnion(NutritionSync.shareTypes) }
        if activityEnabled { read.formUnion(ActivityStore.readTypes) }
        guard !share.isEmpty || !read.isEmpty,
              let status = try? await store.statusForAuthorizationRequest(toShare: share, read: read), status == .shouldRequest else { return }
        try? await store.requestAuthorization(toShare: share, read: read)
    }
}
