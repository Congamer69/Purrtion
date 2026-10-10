import Foundation

/// Open Food Facts – the largest open product database (barcodes, brands, serving sizes, micronutrients).
enum OpenFoodFacts {
    static let userAgent = "Purrtion/1.0 (iOS; calorie tracker)"
    private static let fields = "code,product_name,product_name_de,generic_name_de,brands,nutriments,serving_size,serving_quantity,product_quantity,quantity,image_front_small_url,nutrition_data_per"

    static func product(barcode: String) async throws -> FoodItem? {
        let code = barcode.trimmingCharacters(in: .whitespaces)
        var c = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json")!
        c.queryItems = [.init(name: "fields", value: fields), .init(name: "lc", value: "de")]
        let json = try await fetchJSON(c.url!)
        guard (json["status"] as? Int) == 1, let p = json["product"] as? [String: Any] else { return nil }
        guard var food = parse(p, fallbackCode: code) else { return nil }
        food.warning = plausibilityWarning(food.per100)
        return food
    }

    /// Searches products sold in Germany first (falls back to worldwide), then re-ranks by
    /// relevance, popularity (scan count), completeness and data plausibility.
    static func search(_ query: String) async throws -> [FoodItem] {
        async let german = hits(for: "\(query) countries_tags:\"en:germany\"")
        async let world = hits(for: query)
        var all = try await german
        if all.count < 10 { all += (try? await world) ?? [] }

        var seen = Set<String>()
        var ranked: [(FoodItem, Double)] = []
        for (index, hit) in all.enumerated() {
            guard var food = parse(hit, fallbackCode: nil) else { continue }
            let key = "\(food.name.lowercased())|\((food.brand ?? "").lowercased())"
            guard seen.insert(food.id).inserted, seen.insert(key).inserted else { continue }
            food.warning = plausibilityWarning(food.per100)
            let scans = OpenFoodFacts.number(hit["unique_scans_n"]) ?? 0
            let completeness = OpenFoodFacts.number(hit["completeness"]) ?? 0.5
            let german = (hit["countries_tags"] as? [String])?.contains("en:germany") ?? false
            var score = -Double(index) * 2 + log2(scans + 1) * 3 + completeness * 8 + (german ? 15 : 0)
            if food.warning != nil { score -= 40 }
            ranked.append((food, score))
        }
        return ranked.sorted { $0.1 > $1.1 }.map(\.0)
    }

    private static func hits(for q: String) async throws -> [[String: Any]] {
        var c = URLComponents(string: "https://search.openfoodfacts.org/search")!
        c.queryItems = [
            .init(name: "q", value: q),
            .init(name: "page_size", value: "40"),
            .init(name: "langs", value: "de,en"),
            .init(name: "fields", value: fields + ",unique_scans_n,completeness,countries_tags"),
        ]
        let json = try await fetchJSON(c.url!)
        return json["hits"] as? [[String: Any]] ?? []
    }

    /// Crowd-sourced data can be wrong – flag values that don't add up.
    static func plausibilityWarning(_ n: Nutrients) -> String? {
        let macros = n.protein + n.carbs + n.fat
        if n.kcal <= 0 && macros <= 0 { return "Keine Nährwerte hinterlegt" }
        if macros > 102 || n.kcal > 920 { return "Werte unplausibel" }
        let computed = n.protein * 4 + n.carbs * 4 + n.fat * 9 + (n[.fiber] ?? 0) * 2 + (n[.alcohol] ?? 0) * 7
        if n.kcal > 0, computed > 0, abs(computed - n.kcal) > max(35, n.kcal * 0.25) {
            return "Kalorien passen nicht zu den Makros"
        }
        return nil
    }

    private static func fetchJSON(_ url: URL) async throws -> [String: Any] {
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return [:] }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: Parsing

    /// OFF stores micronutrients in grams; convert to the unit of our catalog.
    private static let nutrientMap: [(String, NutrientKey, Double)] = [
        ("sugars", .sugar, 1), ("fiber", .fiber, 1), ("saturated-fat", .saturatedFat, 1),
        ("monounsaturated-fat", .monoFat, 1), ("polyunsaturated-fat", .polyFat, 1), ("omega-3-fat", .omega3, 1), ("trans-fat", .transFat, 1),
        ("cholesterol", .cholesterol, 1000), ("salt", .salt, 1), ("sodium", .sodium, 1000),
        ("potassium", .potassium, 1000), ("calcium", .calcium, 1000), ("magnesium", .magnesium, 1000),
        ("iron", .iron, 1000), ("zinc", .zinc, 1000), ("phosphorus", .phosphorus, 1000),
        ("iodine", .iodine, 1_000_000), ("selenium", .selenium, 1_000_000),
        ("copper", .copper, 1000), ("manganese", .manganese, 1000), ("pantothenic-acid", .vitaminB5, 1000),
        ("biotin", .biotin, 1_000_000),
        ("vitamin-a", .vitaminA, 1_000_000), ("vitamin-c", .vitaminC, 1000), ("vitamin-d", .vitaminD, 1_000_000),
        ("vitamin-e", .vitaminE, 1000), ("vitamin-k", .vitaminK, 1_000_000), ("vitamin-b1", .vitaminB1, 1000),
        ("vitamin-b2", .vitaminB2, 1000), ("vitamin-pp", .vitaminB3, 1000), ("vitamin-b6", .vitaminB6, 1000),
        ("vitamin-b12", .vitaminB12, 1_000_000), ("vitamin-b9", .folate, 1_000_000), ("folates", .folate, 1_000_000),
        ("caffeine", .caffeine, 1000), ("alcohol", .alcohol, 0.789), // alcohol is % vol -> g per 100 ml
    ]

    static func parse(_ p: [String: Any], fallbackCode: String?) -> FoodItem? {
        let code = (p["code"] as? String) ?? fallbackCode ?? UUID().uuidString
        let name = [p["product_name_de"], p["product_name"], p["generic_name_de"]]
            .compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let name else { return nil }

        let brand: String? = {
            if let s = p["brands"] as? String { return s.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) } }
            if let a = p["brands"] as? [String] { return a.first?.trimmingCharacters(in: .whitespaces) }
            return nil
        }()

        let nm = p["nutriments"] as? [String: Any] ?? [:]
        func value(_ key: String) -> Double? { number(nm["\(key)_100g"]) }

        var n = Nutrients()
        n.kcal = value("energy-kcal") ?? value("energy").map { $0 / 4.184 } ?? 0
        n.protein = value("proteins") ?? 0
        n.carbs = value("carbohydrates") ?? 0
        n.fat = value("fat") ?? 0
        for (key, target, factor) in nutrientMap {
            if let v = value(key), v >= 0, n[target] == nil { n[target] = v * factor }
        }
        if (n[.alcohol] ?? 0) == 0 { n[.alcohol] = nil }
        n.normalize()

        let quantityString = (p["quantity"] as? String)?.lowercased() ?? ""
        let servingString = (p["serving_size"] as? String)?.lowercased() ?? ""
        let isLiquid = quantityString.contains("ml") || quantityString.contains(" l") || quantityString.hasSuffix("l")
            || servingString.contains("ml")
        let unit = isLiquid ? "ml" : "g"

        var servings: [ServingOption] = []
        if let sq = number(p["serving_quantity"]), sq > 0 {
            let label = (p["serving_size"] as? String).map(cleanServing) ?? "Portion"
            servings.append(ServingOption(name: label.isEmpty ? "Portion" : label, grams: sq))
        }
        if let pq = number(p["product_quantity"]), pq > 0, pq < 5000 {
            servings.append(ServingOption(name: "Packung (\(pq.clean) \(unit))", grams: pq))
        }

        guard n.kcal > 0 || n.protein + n.carbs + n.fat > 0 else { return nil }
        return FoodItem(id: "off-\(code)", name: name, brand: brand, source: .openFoodFacts, barcode: code,
                        imageURL: (p["image_front_small_url"] as? String).flatMap(URL.init(string:)),
                        per100: n, unit: unit, servings: servings)
    }

    private static func cleanServing(_ s: String) -> String {
        // "1 Cube (6.52 g)" -> "1 Cube"; the gram weight is shown separately.
        var t = s.replacingOccurrences(of: #"\s*\([^)]*\d[^)]*\)"#, with: "", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespaces)
        if t.isEmpty || t.range(of: #"^[\d.,]+\s*(g|ml)$"#, options: [.regularExpression, .caseInsensitive]) != nil { return "Portion" }
        return t.count > 28 ? String(t.prefix(28)) + "…" : t
    }

    static func number(_ any: Any?) -> Double? {
        switch any {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s.replacingOccurrences(of: ",", with: "."))
        default: return nil
        }
    }
}
