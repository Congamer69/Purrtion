import Foundation
import SwiftData

enum FoodSource: String, Codable {
    case bls, openFoodFacts, ai, custom, swiss, restaurant
    // legacy sources from earlier versions, kept so old entries still decode
    case basic, usda

    var label: String {
        switch self {
        case .bls: "Bundeslebensmittelschlüssel 4.0"
        case .swiss: "Schweizer Nährwertdatenbank"
        case .restaurant: "Restaurantkette (offizielle Angaben)"
        case .basic: "Basis"
        case .openFoodFacts: "Open Food Facts"
        case .usda: "USDA"
        case .ai: "KI-Schätzung"
        case .custom: "Eigene"
        }
    }
}

/// A selectable amount, e.g. "1 Scheibe" = 30 g.
struct ServingOption: Codable, Hashable, Identifiable {
    var name: String
    var grams: Double
    var id: String { "\(name)-\(grams)" }

    static func base(_ unit: String) -> ServingOption { ServingOption(name: unit, grams: 1) }
}

/// A food as delivered by a database. Nutrients are always per 100 g (or 100 ml).
struct FoodItem: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var brand: String?
    var source: FoodSource
    var barcode: String?
    var imageURL: URL?
    var per100: Nutrients
    /// "g" or "ml"
    var unit: String = "g"
    var servings: [ServingOption] = []
    var usdaID: Int?
    /// Original database name when a friendlier display name is used.
    var origin: String? = nil
    /// Set when the data looks implausible (crowd-sourced databases).
    var warning: String? = nil
    /// Present for logged recipes and AI meals so their components remain editable after logging.
    var recipeIngredients: [RecipeIngredient]? = nil
    /// Missing micronutrients were filled in by the AI when the day was closed.
    var microsEstimated: Bool? = nil
    /// Which nutrient keys in `per100` were added by the AI (so the score can be shown without them).
    var aiNutrientKeys: [String]? = nil

    /// Nutrients per 100 g as they came from label / database, without AI-added values.
    var per100WithoutAI: Nutrients {
        guard let keys = aiNutrientKeys, !keys.isEmpty else { return per100 }
        var n = per100
        for k in keys { n.extra[k] = nil }
        return n
    }

    var displayName: String { name.isEmpty ? "Unbenannt" : name }

    /// Base unit + servings, deduplicated.
    var allServings: [ServingOption] {
        var out = [ServingOption.base(unit)]
        for s in servings where s.grams > 0 && !out.contains(where: { $0.name == s.name }) { out.append(s) }
        return out
    }

    var defaultServing: ServingOption { servings.first ?? .base(unit) }
    var defaultQuantity: Double { servings.isEmpty ? 100 : 1 }

    func nutrients(grams: Double) -> Nutrients { per100.scaled(grams / 100) }
}

// MARK: - SwiftData models

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var day: Date = Date()
    var createdAt: Date = Date()
    var name: String = ""
    var brand: String?
    var quantity: Double = 1
    var servingName: String = "g"
    var servingGrams: Double = 1
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    var foodData: Data?
    /// Ingredients of a logged recipe / AI meal, independent from any later recipe edits.
    var ingredientsData: Data?

    init(food: FoodItem, quantity: Double, serving: ServingOption, day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.name = food.displayName
        self.brand = food.brand
        self.foodData = try? JSONEncoder().encode(food)
        if let ingredients = food.recipeIngredients, !ingredients.isEmpty {
            let originalGrams = ingredients.reduce(0) { $0 + $1.grams }
            let loggedGrams = quantity * serving.grams
            let factor = originalGrams > 0 ? loggedGrams / originalGrams : 1
            let portionIngredients = ingredients.map {
                RecipeIngredient(food: $0.food, quantity: $0.quantity * factor, serving: $0.serving)
            }
            self.ingredientsData = try? JSONEncoder().encode(portionIngredients)
        }
        update(quantity: quantity, serving: serving, food: food)
    }

    /// Logs one scanned meal as one entry while retaining all of its editable ingredients.
    init(mealName: String, ingredients: [RecipeIngredient], source: FoodSource, day: Date) {
        let total = ingredients.reduce(Nutrients()) { $0 + $1.nutrients }
        let grams = max(ingredients.reduce(0) { $0 + $1.grams }, 1)
        let meal = FoodItem(id: "meal-\(UUID().uuidString)", name: mealName, source: source,
                            per100: total.scaled(100 / grams), unit: "g",
                            servings: [ServingOption(name: "1 Portion", grams: grams)],
                            origin: source == .ai ? "KI-Scan · \(ingredients.count) Zutaten" : "Rezept · \(ingredients.count) Zutaten",
                            recipeIngredients: ingredients)
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.name = meal.displayName
        self.brand = nil
        self.foodData = try? JSONEncoder().encode(meal)
        self.ingredientsData = try? JSONEncoder().encode(ingredients)
        update(quantity: 1, serving: meal.defaultServing, food: meal)
    }

    var food: FoodItem? { foodData.flatMap { try? JSONDecoder().decode(FoodItem.self, from: $0) } }
    var ingredients: [RecipeIngredient] {
        get { ingredientsData.flatMap { try? JSONDecoder().decode([RecipeIngredient].self, from: $0) } ?? [] }
        set { ingredientsData = try? JSONEncoder().encode(newValue) }
    }
    var isComposite: Bool { !ingredients.isEmpty }
    var grams: Double { quantity * servingGrams }

    var nutrients: Nutrients {
        food?.nutrients(grams: grams) ?? Nutrients(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
    }

    /// Same as `nutrients`, but without micronutrients the AI filled in when the day was closed.
    var nutrientsWithoutAI: Nutrients {
        if isComposite {
            let list = ingredients
            let total = list.reduce(Nutrients()) { $0 + $1.food.per100WithoutAI.scaled($1.grams / 100) }
            let ingredientGrams = list.reduce(0) { $0 + $1.grams }
            return ingredientGrams > 0 ? total.scaled(grams / ingredientGrams) : total
        }
        guard let food else { return nutrients }
        return food.per100WithoutAI.scaled(grams / 100)
    }

    func update(quantity: Double, serving: ServingOption, food: FoodItem) {
        self.quantity = quantity
        self.servingName = serving.name
        self.servingGrams = serving.grams
        let n = food.nutrients(grams: quantity * serving.grams)
        kcal = n.kcal; protein = n.protein; carbs = n.carbs; fat = n.fat
    }

    func updateCompositeIngredients(_ newIngredients: [RecipeIngredient]) {
        guard !newIngredients.isEmpty, var meal = food else { return }
        let total = newIngredients.reduce(Nutrients()) { $0 + $1.nutrients }
        let grams = max(newIngredients.reduce(0) { $0 + $1.grams }, 1)
        meal.per100 = total.scaled(100 / grams)
        meal.servings = [ServingOption(name: "1 Portion", grams: grams)]
        meal.recipeIngredients = newIngredients
        meal.origin = meal.source == .ai ? "KI-Scan · \(newIngredients.count) Zutaten" : "Rezept · \(newIngredients.count) Zutaten"
        foodData = try? JSONEncoder().encode(meal)
        ingredients = newIngredients
        update(quantity: 1, serving: meal.defaultServing, food: meal)
    }

    func replaceIngredient(_ id: UUID, food: FoodItem, quantity: Double, serving: ServingOption) {
        var list = ingredients
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        list[i].food = food
        list[i].quantity = quantity
        list[i].serving = serving
        updateCompositeIngredients(list)
    }

    func addIngredient(_ ingredient: RecipeIngredient) {
        updateCompositeIngredients(ingredients + [ingredient])
    }

    func duplicateIngredient(_ id: UUID) {
        var list = ingredients
        guard let i = list.firstIndex(where: { $0.id == id }) else { return }
        var copy = list[i]
        copy.id = UUID()
        list.insert(copy, at: i + 1)
        updateCompositeIngredients(list)
    }

    /// Removes one ingredient. Returns false when it was the last one – the caller deletes the whole entry then.
    func removeIngredient(_ id: UUID) -> Bool {
        let list = ingredients.filter { $0.id != id }
        guard !list.isEmpty else { return false }
        updateCompositeIngredients(list)
        return true
    }

    var amountText: String {
        if isComposite { return "\(ingredients.count) Zutaten · \(grams.clean) g" }
        if food?.source == .custom {
            let portions = quantity == 1 ? "1 Portion" : "\(quantity.clean) Portionen"
            // Quick entries from a nutrition table: the portion is the amount eaten.
            return servingName == "Portion" && servingGrams != 100 ? "\(portions) · \(grams.clean) \(food?.unit ?? "g")" : portions
        }
        if servingGrams == 1 { return "\(quantity.clean) \(servingName)" }
        let unit = food?.unit ?? "g"
        let single = servingName.hasPrefix("1 ") ? String(servingName.dropFirst(2)) : servingName
        let amount = quantity == 1 ? servingName : "\(quantity.clean) × \(single)"
        return "\(amount) · \(grams.clean) \(unit)"
    }
}

/// Recently used + favourite foods for one-tap logging.
@Model
final class SavedFood {
    @Attribute(.unique) var key: String = ""
    var name: String = ""
    var brand: String?
    var kcalPer100: Double = 0
    var foodData: Data?
    var lastUsed: Date = Date()
    var useCount: Int = 0
    var isFavorite: Bool = false
    var lastQuantity: Double = 1
    var lastServingName: String = "g"

    init(food: FoodItem) {
        key = food.id
        name = food.displayName
        brand = food.brand
        kcalPer100 = food.per100.kcal
        foodData = try? JSONEncoder().encode(food)
    }

    var food: FoodItem? { foodData.flatMap { try? JSONDecoder().decode(FoodItem.self, from: $0) } }

    var lastServing: ServingOption? { food?.allServings.first { $0.name == lastServingName } }
}

@Model
final class WaterLog {
    var day: Date = Date()
    var ml: Int = 0
    init(day: Date, ml: Int) {
        self.day = Calendar.current.startOfDay(for: day)
        self.ml = ml
    }
}

@Model
final class WeightLog {
    var date: Date = Date()
    var kg: Double = 0
    init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

extension ModelContext {
    /// Records that a food was used so it shows up in "Zuletzt".
    func remember(_ food: FoodItem, quantity: Double, serving: ServingOption) {
        let key = food.id
        let existing = try? fetch(FetchDescriptor<SavedFood>(predicate: #Predicate { $0.key == key })).first
        let saved = existing ?? SavedFood(food: food)
        if existing == nil { insert(saved) }
        saved.foodData = try? JSONEncoder().encode(food)
        saved.lastUsed = .now
        saved.useCount += 1
        saved.lastQuantity = quantity
        saved.lastServingName = serving.name
    }

    func log(_ food: FoodItem, quantity: Double, serving: ServingOption, day: Date) {
        insert(FoodEntry(food: food, quantity: quantity, serving: serving, day: day))
        remember(food, quantity: quantity, serving: serving)
        try? save()
    }
}
