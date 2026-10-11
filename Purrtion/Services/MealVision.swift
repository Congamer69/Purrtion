import Foundation
import UIKit
import FoundationModels
import Vision

/// Recognises the components of a meal and asks the selected model for a nutrition estimate.
/// A database match is deliberately not part of the normal path: a dish component such as
/// "paniertes Hähnchen" is much more useful with its own estimate than with an arbitrary,
/// vaguely matching BLS entry.
enum MealVision {
    struct Result {
        let dish: String
        let items: [Item]
    }

    struct Item {
        let name: String
        let grams: Double
        let confidence: String
        /// Nutrients estimated by the model, per 100 g/ml, or a BLS fallback for the
        /// non-generative Apple Vision classifier.
        let food: FoodItem
        let isAIEstimate: Bool
    }

    enum VisionError: LocalizedError {
        case unavailable(String), empty, failed(String)
        var errorDescription: String? {
            switch self {
            case .unavailable(let why): why
            case .empty: "Ich konnte auf dem Foto kein Essen erkennen."
            case .failed(let msg): "Analyse fehlgeschlagen: \(msg)"
            }
        }
    }

    static func analyze(image: UIImage, hint: String?) async throws -> Result {
        let provider = AITask.photo.provider
        if provider != .apple {
            return try await CloudVision.analyze(provider: provider, image: image, hint: hint)
        }
        // 1) Apple Intelligence (on-device LLM with vision): splits the plate into components + grams.
        // Any failure there (model not downloaded, busy, guardrails …) falls back to step 2.
        if let result = try? await AppleVision.analyze(image: image, hint: hint) {
            return result
        }
        // 2) Apple's Vision classifier: recognises ~150 foods.
        return try await ClassifierVision.analyze(image: image)
    }

    static func aiItem(name: String, grams: Double, confidence: String, per100: Nutrients) -> Item? {
        guard grams > 0, per100.kcal > 0 || per100.protein + per100.carbs + per100.fat > 0 else { return nil }
        var nutrients = per100
        nutrients.normalize()
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return nil }
        let food = FoodItem(id: "ai-\(UUID().uuidString)", name: cleanedName, source: .ai,
                            per100: nutrients, unit: "g", origin: "KI-Schätzung · pro 100 g")
        return Item(name: cleanedName, grams: grams, confidence: confidence, food: food, isAIEstimate: true)
    }

    static let prompt = """
    Du bist eine erfahrene Ernährungsberaterin und analysierst ein Foto einer Mahlzeit, oft im Restaurant.
    Zerlege das Essen in seine einzelnen sichtbaren Bestandteile (inklusive Soßen, Dressing, Beilagen, Getränke) \
    und schätze für jeden die Menge in Gramm (Getränke in ml) anhand von Tellergröße, Besteck und typischen \
    Portionsgrößen. Denk an versteckte Komponenten wie Öl, Butter oder Panade. Restaurantportionen sind meist größer.
    Benenne jeden Bestandteil mit einem einfachen deutschen Lebensmittelnamen wie in einer deutschen \
    Nährwerttabelle (z. B. "Pommes frites", "Schwein Schnitzel paniert", "Eisbergsalat", "Remoulade", "Reis gekocht").
    Schätze für jeden Bestandteil außerdem die Nährwerte pro 100 g. Die Werte werden direkt in ein Ernährungstagebuch
    übernommen: Kalorien sowie Protein, Kohlenhydrate und Fett müssen daher immer angegeben werden. Mikronährstoffe
    nur dann angeben, wenn sie für das konkrete Lebensmittel sinnvoll geschätzt werden können.
    Wichtig: Schätze zuerst die gesamte essbare Mahlzeit und zerlege sie danach in sich nicht überschneidende Bestandteile.
    Die Summe aller ausgegebenen Gramm, Kalorien und Makronährstoffe muss zu deiner Schätzung für die gesamte Portion
    passen. Gib niemals zusätzlich das ganze Gericht und gleichzeitig dessen einzelne Zutaten aus; jede Zutat darf nur
    genau einmal vorkommen. Verteile Teig, Fleisch, Käse, Soßen und Beilagen realistisch auf die sichtbare Gesamtportion.
    """
}

/// Micronutrients from a model: accepts a key/value list (structured output) or a plain object (JSON mode).
struct MicroList: Decodable {
    var values: [String: Double]

    private struct Pair: Decodable { let key: String; let value: Double }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: Double].self) {
            values = dict
        } else {
            let pairs = (try? container.decode([Pair].self)) ?? []
            values = Dictionary(pairs.map { ($0.key, $0.value) }, uniquingKeysWith: { a, _ in a })
        }
    }
}

/// Cloud models with the user's own API key – used for meal photos and, text-only, for closing a day.
enum CloudVision {
    struct Payload: Decodable {
        struct Component: Decodable {
            let name: String
            let grams: Double
            let confidence: String?
            let nutrientsPer100: NutritionPayload

            enum CodingKeys: String, CodingKey {
                case name, grams, confidence
                case nutrientsPer100 = "nutrients_per_100g"
            }
        }

        struct NutritionPayload: Decodable {
            let kcal: Double
            let protein: Double
            let carbs: Double
            let fat: Double
            let micronutrients: MicroList?

            func nutrients() -> Nutrients {
                let allowed = Set(NutrientKey.allCases.map(\.rawValue))
                let extras = (micronutrients?.values ?? [:]).reduce(into: [String: Double]()) { result, pair in
                    guard allowed.contains(pair.key), pair.value.isFinite, pair.value > 0 else { return }
                    result[pair.key] = pair.value
                }
                return Nutrients(kcal: max(0, kcal), protein: max(0, protein), carbs: max(0, carbs), fat: max(0, fat), extra: extras)
            }
        }
        let dish: String
        let items: [Component]
    }

    static let micronutrientHelp = NutrientKey.allCases
        .map { "\($0.rawValue) (\($0.unit))" }
        .joined(separator: ", ")

    static let jsonInstruction = """
    Antworte ausschließlich mit JSON in genau diesem Format:
    {"dish": "kurzer deutscher Name des Gerichts", "items": [{"name": "Lebensmittel", "grams": 150, "confidence": "hoch|mittel|niedrig", "nutrients_per_100g": {"kcal": 180, "protein": 12, "carbs": 8, "fat": 9, "micronutrients": [{"key": "fiber", "value": 2}]}}]}
    Alle Nährwerte gelten pro 100 g (bei Getränken pro 100 ml). `micronutrients` ist eine Liste aus key/value-Paaren
    und enthält nur Werte, die du plausibel schätzen kannst; die gültigen Schlüssel mit ihrer Einheit sind: \(micronutrientHelp).
    Wenn kein Essen zu sehen ist, gib eine leere items-Liste zurück.
    """

    /// Micronutrients as a list of key/value pairs: unlike an object with ~35 optional properties
    /// this stays within the structured-output limits of all providers (Claude allows max. 24 optional fields).
    static let micronutrientListSchema: [String: Any] = [
        "type": "array",
        "items": [
            "type": "object",
            "properties": [
                "key": ["type": "string", "enum": NutrientKey.allCases.map(\.rawValue)],
                "value": ["type": "number"],
            ],
            "required": ["key", "value"],
            "additionalProperties": false,
        ],
    ]

    static let nutritionSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "kcal": ["type": "number"],
            "protein": ["type": "number"],
            "carbs": ["type": "number"],
            "fat": ["type": "number"],
            "micronutrients": micronutrientListSchema,
        ],
        "required": ["kcal", "protein", "carbs", "fat", "micronutrients"],
        "additionalProperties": false,
    ]

    static let schema: [String: Any] = [
        "type": "object",
        "properties": [
            "dish": ["type": "string"],
            "items": ["type": "array", "items": [
                "type": "object",
                "properties": ["name": ["type": "string"], "grams": ["type": "number"],
                               "confidence": ["type": "string", "enum": ["hoch", "mittel", "niedrig"]],
                               "nutrients_per_100g": nutritionSchema],
                "required": ["name", "grams", "confidence", "nutrients_per_100g"],
                "additionalProperties": false,
            ]],
        ],
        "required": ["dish", "items"],
        "additionalProperties": false,
    ]

    static func analyze(provider: VisionProvider, image: UIImage, hint: String?) async throws -> MealVision.Result {
        let jpeg = image.resizedForUpload(maxSide: 1280).jpegData(compressionQuality: 0.75) ?? Data()
        let b64 = jpeg.base64EncodedString()
        var text = MealVision.prompt + "\n" + jsonInstruction
        if let hint, !hint.isEmpty { text += "\nZusatzinfo vom Nutzer: \(hint)" }

        let raw = try await request(provider: provider, model: AITask.photo.model, text: text, b64: b64, schema: schema)
        guard let payload = decode(Payload.self, from: raw) else { throw MealVision.VisionError.failed("Antwort nicht lesbar") }
        let items = payload.items.compactMap {
            MealVision.aiItem(name: $0.name, grams: $0.grams.rounded(), confidence: $0.confidence ?? "mittel",
                              per100: $0.nutrientsPer100.nutrients())
        }
        guard !items.isEmpty else { throw MealVision.VisionError.empty }
        return MealVision.Result(dish: payload.dish, items: items)
    }

    /// Sends one prompt (optionally with a JPEG) to the selected cloud provider and returns the raw JSON text.
    static func request(provider: VisionProvider, model: String, text: String, b64: String?, schema: [String: Any]) async throws -> String {
        let key = provider.apiKey
        guard !key.isEmpty else {
            throw MealVision.VisionError.unavailable("Bitte hinterlege unter Profil → KI-Modelle deinen \(provider.name)-Schlüssel.")
        }
        switch provider {
        case .claude: return try await claude(key: key, model: model, b64: b64, text: text, schema: schema)
        case .gemini: return try await gemini(key: key, model: model, b64: b64, text: text)
        case .openai: return try await openai(key: key, model: model, b64: b64, text: text)
        case .apple: throw MealVision.VisionError.empty
        }
    }

    /// Tolerates code fences or text around the JSON object.
    static func decode<T: Decodable>(_ type: T.Type, from raw: String) -> T? {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}") else { return nil }
        return try? JSONDecoder().decode(T.self, from: Data(raw[start...end].utf8))
    }

    private static func post(_ url: URL, headers: [String: String], body: [String: Any]) async throws -> [String: Any] {
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let err = json["error"] as? [String: Any]
            let msg = (err?["message"] as? String) ?? String(data: data, encoding: .utf8)?.prefix(200).description ?? "Unbekannter Fehler"
            throw MealVision.VisionError.failed("\(status): \(msg)")
        }
        return json
    }

    // Claude Messages API (raw HTTP – there is no official Swift SDK).
    private static func claude(key: String, model: String, b64: String?, text: String, schema: [String: Any]) async throws -> String {
        var content: [[String: Any]] = []
        if let b64 { content.append(["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": b64]]) }
        content.append(["type": "text", "text": text])
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": content]],
        ]
        var headers = ["x-api-key": key, "anthropic-version": "2023-06-01"]
        // Server-side refusal fallback is supported on the larger models only.
        if model.hasPrefix("claude-opus") || model.hasPrefix("claude-fable") {
            body["fallbacks"] = "default"
            headers["anthropic-beta"] = "server-side-fallback-2026-07-01"
        }
        let json = try await post(URL(string: "https://api.anthropic.com/v1/messages")!, headers: headers, body: body)
        if (json["stop_reason"] as? String) == "refusal" {
            throw MealVision.VisionError.failed("Claude hat die Analyse abgelehnt.")
        }
        let blocks = json["content"] as? [[String: Any]] ?? []
        return blocks.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }.joined()
    }

    // Google Gemini generateContent.
    private static func gemini(key: String, model: String, b64: String?, text: String) async throws -> String {
        var parts: [[String: Any]] = []
        if let b64 { parts.append(["inline_data": ["mime_type": "image/jpeg", "data": b64]]) }
        parts.append(["text": text])
        let body: [String: Any] = [
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["responseMimeType": "application/json", "temperature": 0.2],
        ]
        let base = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        let json: [String: Any]
        do {
            json = try await post(URL(string: base)!, headers: ["x-goog-api-key": key], body: body)
        } catch MealVision.VisionError.failed(let msg) where msg.hasPrefix("401") {
            // Some key types are only accepted as query parameter.
            var comps = URLComponents(string: base)!
            comps.queryItems = [URLQueryItem(name: "key", value: key)]
            json = try await post(comps.url!, headers: [:], body: body)
        }
        let answer = ((json["candidates"] as? [[String: Any]])?.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        return answer.compactMap { $0["text"] as? String }.joined()
    }

    // OpenAI Chat Completions.
    private static func openai(key: String, model: String, b64: String?, text: String) async throws -> String {
        var content: [[String: Any]] = [["type": "text", "text": text]]
        if let b64 { content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)"]]) }
        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [["role": "user", "content": content]],
        ]
        let json = try await post(URL(string: "https://api.openai.com/v1/chat/completions")!,
                                  headers: ["Authorization": "Bearer \(key)"], body: body)
        let message = (json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }
}

/// Fallback: Vision's built-in image classifier + typical portion sizes.
private enum ClassifierVision {
    /// Vision identifier -> (German search term for the BLS, typical portion in g/ml)
    static let foods: [String: (String, Double)] = [
        "apple": ("Apfel roh", 180), "avocado": ("Avocado roh", 140), "bacon": ("Frühstücksspeck", 30),
        "bagel": ("Weizenbrötchen", 90), "banana": ("Banane roh", 120), "bean": ("Bohne", 150), "beer": ("Pilsner Bier", 500),
        "bell_pepper": ("Gemüsepaprika rot, roh", 160), "blackberry": ("Brombeere roh", 100), "blueberry": ("Heidelbeere roh", 100),
        "bread": ("Roggenmischbrot", 90), "white_bread": ("Weizentoastbrot", 50), "broccoli": ("Broccoli gekocht", 150),
        "brownie": ("Brownie", 60), "burrito": ("Burrito", 300), "butter": ("Süßrahmbutter", 10),
        "cake": ("Rührkuchen", 100), "cake_regular": ("Rührkuchen", 100), "birthday_cake": ("Buttercremetorte", 120),
        "wedding_cake": ("Buttercremetorte", 120), "cheesecake": ("Käsekuchen", 120), "candy": ("Fruchtgummi", 30),
        "carrot": ("Karotte/Möhre, roh", 80), "cereal": ("Knuspermüslimischung", 60), "cheese": ("Gouda", 40),
        "cherry": ("Süßkirsche roh", 100), "chocolate": ("Vollmilchschokolade", 25), "cookie": ("Kekse", 30),
        "corn": ("Zuckermais gekocht", 150), "crab": ("Krabbe", 100), "crepe": ("Crêpe", 120), "croissant": ("Croissant", 60),
        "cucumber": ("Gurke roh", 100), "cupcake": ("Muffin", 80), "curry": ("Curry", 350), "donut": ("Berliner", 70),
        "dumpling": ("Knödel", 150), "egg": ("Hühnerei gekocht", 60), "fried_egg": ("Spiegelei gebraten", 50),
        "scrambled_eggs": ("Rührei gebraten", 120), "omelet": ("Omelett", 150), "eggplant": ("Aubergine gebraten", 150),
        "fish": ("Köhler/Seelachs, gegrillt", 150), "fried_chicken": ("Hähnchen paniert", 200), "fries": ("Pommes frites", 150),
        "grape": ("Weintraube roh", 100), "grapefruit": ("Grapefruit roh", 200), "green_beans": ("Grüne Bohnen gekocht", 150),
        "grilled_chicken": ("Hähnchen Brustfilet, gegrillt", 150), "ham": ("Kochschinken", 50), "hamburger": ("Hamburger", 220),
        "honey": ("Honig", 20), "ice_cream": ("Cremeeis", 120), "frozen_dessert": ("Cremeeis", 120), "juice": ("Orangensaft", 250),
        "kebab": ("Döner Kebab", 400), "kiwi": ("Kiwi roh", 75), "lemon": ("Zitrone roh", 60), "lettuce": ("Kopfsalat roh", 80),
        "lobster": ("Hummer", 200), "mango": ("Mango roh", 200), "meatball": ("Frikadelle", 120), "melon": ("Honigmelone roh", 200),
        "honeydew": ("Honigmelone roh", 200), "milkshake": ("Milchshake", 300), "muffin": ("Muffin", 80),
        "mushroom": ("Champignon gebraten", 100), "mussel": ("Miesmuschel", 150), "oatmeal": ("Hafer Flocken, gekocht", 250),
        "oranges": ("Orange roh", 150), "citrus_fruit": ("Orange roh", 150), "paella": ("Paella", 400), "pancake": ("Pfannkuchen", 150),
        "pasta": ("Teigwaren eifrei, gekocht", 250), "spaghetti": ("Teigwaren eifrei, gekocht", 300), "peach": ("Pfirsich roh", 150),
        "peanut": ("Erdnuss geröstet", 30), "pear": ("Birne roh", 180), "pepperoni": ("Salami", 30), "pie": ("Obstkuchen", 120),
        "pierogi": ("Teigtaschen", 200), "pineapple": ("Ananas roh", 150), "pizza": ("Pizza Margherita", 350),
        "popcorn": ("Popcorn", 40), "potato": ("Kartoffel geschält, gekocht", 200), "pretzel": ("Laugengebäck mit Hagelsalz", 80),
        "pudding": ("Pudding", 150), "pumpkin": ("Kürbis gekocht", 200), "ramen": ("Reisnudeln gekocht", 300), "raspberry": ("Himbeere roh", 100),
        "red_wine": ("Rotwein trocken", 200), "white_wine": ("Weißwein trocken", 200), "wine": ("Rotwein trocken", 200),
        "sparkling_wine": ("Sekt", 100), "rice": ("Reis gekocht", 200), "risotto": ("Risotto", 350), "salad": ("Gemischter Salat", 200),
        "salmon": ("Lachs gegrillt", 150), "sandwich": ("Sandwich", 200), "sausage": ("Bratwurst gebraten", 100),
        "shellfish_prepared": ("Garnele", 120), "seafood": ("Garnele", 120), "smoothie": ("Smoothie", 300), "soda": ("Colagetränk", 330),
        "soup": ("Gemüsesuppe", 300), "spinach": ("Spinat gedünstet", 150), "steak": ("Rind Steak (Rücken) gegrillt", 200),
        "strawberry": ("Erdbeere roh", 150), "sushi": ("Sushi mit Lachs", 200), "taco": ("Weizentortilla", 80), "tea_drink": ("Schwarztee (Getränk)", 250),
        "coffee": ("Kaffee (Getränk)", 200), "tiramisu": ("Tiramisu", 120), "tomato": ("Tomate roh", 120), "tuna": ("Thunfisch", 120),
        "waffle": ("Waffel", 80), "watermelon": ("Wassermelone roh", 300), "yogurt": ("Joghurt mild, mind. 3,5 % Fett", 150),
        "zucchini": ("Zucchini gedünstet", 150), "nut": ("Walnuss", 30), "almond": ("Mandel süß", 30), "coconut": ("Kokos Fruchtfleisch", 50),
        "fig": ("Feige roh", 50), "cranberry": ("Moosbeere roh", 40), "chestnut": ("Edelkastanie/Marone, gebacken", 60), "cocktail": ("Cocktail", 200),
        "gingerbread": ("Lebkuchen", 50), "fruitcake": ("Früchtekuchen", 80), "garlic": ("Knoblauch roh", 5), "onion": ("Speisezwiebel roh", 50),
        "radish": ("Radieschen roh", 50), "passionfruit": ("Maracuja roh", 50), "starfruit": ("Karambole roh", 100),
    ]

    static func analyze(image: UIImage) async throws -> MealVision.Result {
        guard let cg = image.resizedForUpload(maxSide: 1024).cgImage else { throw MealVision.VisionError.empty }
        let observations: [VNClassificationObservation] = try await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            #if targetEnvironment(simulator)
            // The simulator has no Neural Engine – run on the CPU.
            if let cpu = try? request.supportedComputeStageDevices[.main]?.first(where: { "\($0)".contains("CPU") }) {
                request.setComputeDevice(cpu, for: .main)
            }
            #endif
            try VNImageRequestHandler(cgImage: cg).perform([request])
            return request.results ?? []
        }.value

        var items: [MealVision.Item] = []
        var seenTerms = Set<String>()
        for obs in observations where obs.confidence > 0.12 {
            guard let (term, grams) = foods[obs.identifier], seenTerms.insert(term).inserted else { continue }
            let candidates = BLSDatabase.shared.search(term, limit: 6)
            guard !candidates.isEmpty else { continue }
            let confidence = obs.confidence > 0.6 ? "hoch" : obs.confidence > 0.3 ? "mittel" : "niedrig"
            // This is only reached when Apple Intelligence itself is unavailable. Keep the
            // old BLS lookup as a useful, fully offline fallback in that case.
            items.append(MealVision.Item(name: candidates[0].name, grams: grams, confidence: confidence,
                                         food: candidates[0], isAIEstimate: false))
            if items.count == 4 { break }
        }
        guard !items.isEmpty else { throw MealVision.VisionError.empty }
        return MealVision.Result(dish: items.map(\.name).joined(separator: ", "), items: items)
    }
}

private enum AppleVision {
    @Generable
    struct MealGuess {
        @Guide(description: "Kurzer deutscher Name des Gerichts, z. B. 'Schnitzel mit Pommes und Salat'")
        var dish: String
        @Guide(description: "Alle sichtbaren Bestandteile, inklusive Soßen, Dressing und Getränke", .maximumCount(10))
        var items: [Component]
    }

    @Generable
    struct Component {
        @Guide(description: "Einfacher deutscher Lebensmittelname wie in einer Nährwerttabelle, z. B. 'Pommes frites', 'Schwein Schnitzel paniert', 'Eisbergsalat', 'Remoulade'")
        var name: String
        @Guide(description: "Geschätzte Menge in Gramm (bei Getränken ml)", .range(1...1500))
        var grams: Int
        @Guide(description: "Wie sicher die Erkennung ist", .anyOf(["hoch", "mittel", "niedrig"]))
        var confidence: String
        @Guide(description: "Geschätzte Nährwerte dieses Lebensmittels pro 100 g, nicht für die ganze Portion")
        var nutrientsPer100: NutritionEstimate
    }

    /// Apple Intelligence gets the same core nutrition task as the cloud providers. The
    /// smaller set of common micronutrients keeps the on-device schema reliable; cloud
    /// providers can additionally return every nutrient supported by the app.
    @Generable
    struct NutritionEstimate {
        @Guide(description: "Kilokalorien pro 100 g", .range(0...1200)) var kcal: Int
        @Guide(description: "Protein in Gramm pro 100 g", .range(0...100)) var protein: Int
        @Guide(description: "Kohlenhydrate in Gramm pro 100 g", .range(0...100)) var carbs: Int
        @Guide(description: "Fett in Gramm pro 100 g", .range(0...100)) var fat: Int
        @Guide(description: "Ballaststoffe in Gramm pro 100 g, nur wenn sinnvoll schätzbar") var fiber: Int?
        @Guide(description: "Zucker in Gramm pro 100 g, nur wenn sinnvoll schätzbar") var sugar: Int?
        @Guide(description: "Gesättigte Fettsäuren in Gramm pro 100 g, nur wenn sinnvoll schätzbar") var saturatedFat: Int?
        @Guide(description: "Salz in Gramm pro 100 g, nur wenn sinnvoll schätzbar") var salt: Int?
        @Guide(description: "Kalium in mg pro 100 g, nur wenn sinnvoll schätzbar") var potassium: Int?
        @Guide(description: "Calcium in mg pro 100 g, nur wenn sinnvoll schätzbar") var calcium: Int?
        @Guide(description: "Eisen in mg pro 100 g, nur wenn sinnvoll schätzbar") var iron: Int?
        @Guide(description: "Vitamin C in mg pro 100 g, nur wenn sinnvoll schätzbar") var vitaminC: Int?
    }

    static let instructions = MealVision.prompt

    static func analyze(image: UIImage, hint: String?) async throws -> MealVision.Result {
        guard let cg = image.resizedForUpload(maxSide: 1024).cgImage else { throw MealVision.VisionError.empty }

        // Private Cloud Compute would need a special Apple entitlement – the on-device model is free for everyone.
        let model = SystemLanguageModel.default
        guard model.isAvailable, model.capabilities.contains(.vision) else {
            throw MealVision.VisionError.unavailable("on-device model unavailable")
        }
        let session = LanguageModelSession(model: model, instructions: instructions)

        let extra = (hint?.isEmpty == false) ? "\nZusatzinfo: \(hint!)" : ""
        let guess: MealGuess
        do {
            guess = try await session.respond(generating: MealGuess.self) {
                Attachment(cg)
                "Was ist auf diesem Foto zu sehen? Liste alle Bestandteile mit geschätzter Menge.\(extra)"
            }.content
        } catch {
            throw MealVision.VisionError.failed(error.localizedDescription)
        }

        let items = guess.items.compactMap { component in
            var extras: [String: Double] = [:]
            if let value = component.nutrientsPer100.fiber, value > 0 { extras[NutrientKey.fiber.rawValue] = Double(value) }
            if let value = component.nutrientsPer100.sugar, value > 0 { extras[NutrientKey.sugar.rawValue] = Double(value) }
            if let value = component.nutrientsPer100.saturatedFat, value > 0 { extras[NutrientKey.saturatedFat.rawValue] = Double(value) }
            if let value = component.nutrientsPer100.salt, value > 0 { extras[NutrientKey.salt.rawValue] = Double(value) }
            if let value = component.nutrientsPer100.potassium, value > 0 { extras[NutrientKey.potassium.rawValue] = Double(value) }
            if let value = component.nutrientsPer100.calcium, value > 0 { extras[NutrientKey.calcium.rawValue] = Double(value) }
            if let value = component.nutrientsPer100.iron, value > 0 { extras[NutrientKey.iron.rawValue] = Double(value) }
            if let value = component.nutrientsPer100.vitaminC, value > 0 { extras[NutrientKey.vitaminC.rawValue] = Double(value) }
            let nutrition = Nutrients(kcal: Double(component.nutrientsPer100.kcal),
                                     protein: Double(component.nutrientsPer100.protein),
                                     carbs: Double(component.nutrientsPer100.carbs),
                                     fat: Double(component.nutrientsPer100.fat), extra: extras)
            return MealVision.aiItem(name: component.name, grams: Double(component.grams),
                                     confidence: component.confidence, per100: nutrition)
        }
        guard !items.isEmpty else { throw MealVision.VisionError.empty }
        return MealVision.Result(dish: guess.dish, items: items)
    }
}

extension UIImage {
    func resizedForUpload(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
