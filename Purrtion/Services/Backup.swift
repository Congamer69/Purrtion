import Foundation
import SwiftData

/// Full JSON backup of all data + settings. Written automatically (about once a day) into a folder the
/// user picked once – e.g. in iCloud Drive – and restorable on any device.
enum Backup {
    static let fileName = "Purrtion-Backup.json"
    private static let bookmarkKey = "backup.folderBookmark"
    private static let lastKey = "backup.lastDate"
    static let autoKey = "backup.auto"

    /// UserDefaults keys that belong to the user's settings.
    private static let settingPrefixes = ["goal.", "profile.", "vision.", "source.", "activity.", "catPalette", "appearance", "onboarded", "health.", "friends.server"]

    struct Payload: Codable {
        var version = 1
        var createdAt = Date()
        var entries: [Entry] = []
        var saved: [Saved] = []
        var custom: [Custom] = []
        var water: [Water] = []
        var weights: [Weight] = []
        var reviews: [Review]? = nil
        var settings: [String: String] = [:]

        struct Entry: Codable {
            var day: Date; var createdAt: Date; var name: String; var brand: String?
            var quantity: Double; var servingName: String; var servingGrams: Double
            var kcal: Double; var protein: Double; var carbs: Double; var fat: Double; var foodData: Data?
            var ingredientsData: Data?
        }
        struct Saved: Codable {
            var key: String; var name: String; var brand: String?; var kcalPer100: Double; var foodData: Data?
            var lastUsed: Date; var useCount: Int; var isFavorite: Bool; var lastQuantity: Double; var lastServingName: String
        }
        struct Custom: Codable {
            var id: UUID; var name: String; var brand: String?; var isRecipe: Bool; var createdAt: Date
            var foodData: Data?; var ingredientsData: Data?; var portions: Int
        }
        struct Water: Codable { var day: Date; var ml: Int }
        struct Weight: Codable { var date: Date; var kg: Double }
        struct Review: Codable {
            var day: Date; var createdAt: Date; var rating: String; var tone: String; var pointsData: Data?
            var signature: String; var enrichedCount: Int; var providerName: String; var score: Int?
            var scoreBefore: Int?; var automatic: Bool?
        }
    }

    // MARK: Export / import

    @MainActor
    static func makePayload(_ ctx: ModelContext) throws -> Payload {
        var p = Payload()
        p.entries = try ctx.fetch(FetchDescriptor<FoodEntry>()).map {
            .init(day: $0.day, createdAt: $0.createdAt, name: $0.name, brand: $0.brand, quantity: $0.quantity,
                  servingName: $0.servingName, servingGrams: $0.servingGrams, kcal: $0.kcal, protein: $0.protein,
                  carbs: $0.carbs, fat: $0.fat, foodData: $0.foodData, ingredientsData: $0.ingredientsData)
        }
        p.saved = try ctx.fetch(FetchDescriptor<SavedFood>()).map {
            .init(key: $0.key, name: $0.name, brand: $0.brand, kcalPer100: $0.kcalPer100, foodData: $0.foodData,
                  lastUsed: $0.lastUsed, useCount: $0.useCount, isFavorite: $0.isFavorite,
                  lastQuantity: $0.lastQuantity, lastServingName: $0.lastServingName)
        }
        p.custom = try ctx.fetch(FetchDescriptor<CustomFood>()).map {
            .init(id: $0.id, name: $0.name, brand: $0.brand, isRecipe: $0.isRecipe, createdAt: $0.createdAt,
                  foodData: $0.foodData, ingredientsData: $0.ingredientsData, portions: $0.portions)
        }
        p.water = try ctx.fetch(FetchDescriptor<WaterLog>()).map { .init(day: $0.day, ml: $0.ml) }
        p.weights = try ctx.fetch(FetchDescriptor<WeightLog>()).map { .init(date: $0.date, kg: $0.kg) }
        p.reviews = try ctx.fetch(FetchDescriptor<DayReview>()).map {
            .init(day: $0.day, createdAt: $0.createdAt, rating: $0.rating, tone: $0.tone, pointsData: $0.pointsData,
                  signature: $0.signature, enrichedCount: $0.enrichedCount, providerName: $0.providerName, score: $0.score,
                  scoreBefore: $0.scoreBefore, automatic: $0.automatic)
        }
        for (k, v) in UserDefaults.standard.dictionaryRepresentation()
        where settingPrefixes.contains(where: { k.hasPrefix($0) }) && k != bookmarkKey {
            if let s = v as? String { p.settings[k] = "s:" + s }
            else if let n = v as? NSNumber { p.settings[k] = "n:" + n.stringValue }
        }
        return p
    }

    @MainActor
    static func data(_ ctx: ModelContext) throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys]
        return try enc.encode(makePayload(ctx))
    }

    /// Replaces all local data with the backup.
    @MainActor
    static func restore(from data: Data, into ctx: ModelContext) throws -> Payload {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let p = try dec.decode(Payload.self, from: data)

        try ctx.delete(model: FoodEntry.self)
        try ctx.delete(model: SavedFood.self)
        try ctx.delete(model: CustomFood.self)
        try ctx.delete(model: WaterLog.self)
        try ctx.delete(model: WeightLog.self)
        try ctx.delete(model: DayReview.self)

        for e in p.entries {
            let entry = FoodEntry(food: FoodItem(id: "restored", name: e.name, source: .custom, per100: Nutrients()),
                                  quantity: e.quantity, serving: ServingOption(name: e.servingName, grams: e.servingGrams), day: e.day)
            entry.createdAt = e.createdAt; entry.name = e.name; entry.brand = e.brand
            entry.kcal = e.kcal; entry.protein = e.protein; entry.carbs = e.carbs; entry.fat = e.fat
            entry.foodData = e.foodData
            entry.ingredientsData = e.ingredientsData
            ctx.insert(entry)
        }
        for s in p.saved {
            let item = SavedFood(food: FoodItem(id: s.key, name: s.name, source: .custom, per100: Nutrients()))
            item.name = s.name; item.brand = s.brand; item.kcalPer100 = s.kcalPer100; item.foodData = s.foodData
            item.lastUsed = s.lastUsed; item.useCount = s.useCount; item.isFavorite = s.isFavorite
            item.lastQuantity = s.lastQuantity; item.lastServingName = s.lastServingName
            ctx.insert(item)
        }
        for c in p.custom {
            let item = CustomFood(name: c.name, food: FoodItem(id: "x", name: c.name, source: .custom, per100: Nutrients()))
            item.id = c.id; item.brand = c.brand; item.isRecipe = c.isRecipe; item.createdAt = c.createdAt
            item.foodData = c.foodData; item.ingredientsData = c.ingredientsData; item.portions = c.portions
            ctx.insert(item)
        }
        for w in p.water { ctx.insert(WaterLog(day: w.day, ml: w.ml)) }
        for w in p.weights { ctx.insert(WeightLog(date: w.date, kg: w.kg)) }
        for r in p.reviews ?? [] {
            let review = DayReview(day: r.day)
            review.createdAt = r.createdAt; review.rating = r.rating; review.tone = r.tone; review.pointsData = r.pointsData
            review.signature = r.signature; review.enrichedCount = r.enrichedCount; review.providerName = r.providerName
            review.score = r.score
            review.scoreBefore = r.scoreBefore
            review.automatic = r.automatic ?? false
            ctx.insert(review)
        }
        try ctx.save()

        for (k, v) in p.settings {
            if v.hasPrefix("s:") { UserDefaults.standard.set(String(v.dropFirst(2)), forKey: k) }
            else if v.hasPrefix("n:"), let d = Double(v.dropFirst(2)) {
                if d == d.rounded(), !k.contains("kcal"), !k.contains("weight"), !k.contains("height") {
                    UserDefaults.standard.set(Int(d), forKey: k)
                } else {
                    UserDefaults.standard.set(d, forKey: k)
                }
            }
        }
        return p
    }

    // MARK: Backup folder (e.g. iCloud Drive)

    static var lastBackup: Date? { UserDefaults.standard.object(forKey: lastKey) as? Date }

    static var folderName: String? { resolveFolder()?.lastPathComponent }

    static func setFolder(_ url: URL) throws {
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }

    static func clearFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    private static func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { try? setFolder(url) }
        return url
    }

    /// Writes the backup into the chosen folder.
    @MainActor
    static func writeToFolder(_ ctx: ModelContext) throws {
        guard let folder = resolveFolder() else { throw CocoaError(.fileNoSuchFile) }
        let ok = folder.startAccessingSecurityScopedResource()
        defer { if ok { folder.stopAccessingSecurityScopedResource() } }
        let data = try data(ctx)
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: folder.appendingPathComponent(fileName), options: .forReplacing, error: &coordError) { url in
            do { try data.write(to: url, options: .atomic) } catch { writeError = error }
        }
        if let e = coordError ?? writeError { throw e }
        UserDefaults.standard.set(Date(), forKey: lastKey)
    }

    /// Called when the app becomes active: backs up if the last backup is older than ~a day.
    @MainActor
    static func autoBackupIfNeeded(_ ctx: ModelContext) {
        guard UserDefaults.standard.bool(forKey: autoKey), resolveFolder() != nil else { return }
        if let last = lastBackup, Date().timeIntervalSince(last) < 20 * 3600 { return }
        try? writeToFolder(ctx)
    }
}

/// CSV export for Excel & co (semicolon separated, German decimal comma).
enum CSVExport {
    @MainActor
    static func files(_ ctx: ModelContext) throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Purrtion-Export", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter(); tf.dateFormat = "HH:mm"
        func num(_ v: Double?) -> String {
            guard let v else { return "" }
            return v.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(Locale(identifier: "de_DE")))
        }
        func esc(_ s: String?) -> String {
            let s = s ?? ""
            return s.contains(";") || s.contains("\"") || s.contains("\n") ? "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\"" : s
        }

        let extraKeys: [NutrientKey] = [.fiber, .sugar, .saturatedFat, .salt, .potassium, .calcium, .magnesium, .iron,
                                        .zinc, .vitaminC, .vitaminD, .vitaminB12, .folate]
        var rows = [(["Datum", "Uhrzeit", "Lebensmittel", "Marke", "Menge", "Portion", "Gramm/ml", "kcal", "Protein g", "Kohlenhydrate g", "Fett g"]
                     + extraKeys.map { "\($0.name) \($0.unit)" }).joined(separator: ";")]
        let entries = try ctx.fetch(FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.day), SortDescriptor(\.createdAt)]))
        for e in entries {
            let n = e.nutrients
            rows.append(([df.string(from: e.day), tf.string(from: e.createdAt), esc(e.name), esc(e.brand), num(e.quantity),
                          esc(e.servingName), num(e.grams), num(e.kcal), num(e.protein), num(e.carbs), num(e.fat)]
                         + extraKeys.map { num(n[$0]) }).joined(separator: ";"))
        }
        let foodURL = dir.appendingPathComponent("Purrtion-Essen.csv")
        try ("\u{FEFF}" + rows.joined(separator: "\n")).write(to: foodURL, atomically: true, encoding: .utf8)

        // Daily summary
        var days = ["Datum;kcal;Protein g;Kohlenhydrate g;Fett g;Wasser ml"]
        let water = Dictionary(grouping: try ctx.fetch(FetchDescriptor<WaterLog>()), by: \.day).mapValues { $0.reduce(0) { $0 + $1.ml } }
        for (day, list) in Dictionary(grouping: entries, by: \.day).sorted(by: { $0.key < $1.key }) {
            days.append([df.string(from: day), num(list.reduce(0) { $0 + $1.kcal }), num(list.reduce(0) { $0 + $1.protein }),
                         num(list.reduce(0) { $0 + $1.carbs }), num(list.reduce(0) { $0 + $1.fat }), "\(water[day] ?? 0)"].joined(separator: ";"))
        }
        let dayURL = dir.appendingPathComponent("Purrtion-Tage.csv")
        try ("\u{FEFF}" + days.joined(separator: "\n")).write(to: dayURL, atomically: true, encoding: .utf8)

        var weights = ["Datum;Gewicht kg"]
        for w in try ctx.fetch(FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date)])) {
            weights.append("\(df.string(from: w.date));\(num(w.kg))")
        }
        let weightURL = dir.appendingPathComponent("Purrtion-Gewicht.csv")
        try ("\u{FEFF}" + weights.joined(separator: "\n")).write(to: weightURL, atomically: true, encoding: .utf8)

        return [foodURL, dayURL, weightURL]
    }
}
