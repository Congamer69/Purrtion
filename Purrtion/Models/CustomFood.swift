import Foundation
import SwiftData

/// One ingredient of a recipe: a food plus the amount used.
struct RecipeIngredient: Codable, Hashable, Identifiable {
    var id = UUID()
    var food: FoodItem
    var quantity: Double
    var serving: ServingOption

    var grams: Double { quantity * serving.grams }
    var nutrients: Nutrients { food.nutrients(grams: grams) }

    /// Same wording as a normal log entry, e.g. "2 × Scheibe · 60 g".
    var amountText: String {
        if serving.grams == 1 { return "\(quantity.clean) \(serving.name)" }
        let single = serving.name.hasPrefix("1 ") ? String(serving.name.dropFirst(2)) : serving.name
        let amount = quantity == 1 ? serving.name : "\(quantity.clean) × \(single)"
        return "\(amount) · \(grams.clean) \(food.unit)"
    }
}

/// A food or recipe created by the user.
@Model
final class CustomFood {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String?
    var isRecipe: Bool = false
    var createdAt: Date = Date()
    /// Simple food: nutrition per 100 g/ml + servings.
    var foodData: Data?
    /// Recipe: ingredients + how many portions the whole recipe makes.
    var ingredientsData: Data?
    var portions: Int = 1

    init(name: String, food: FoodItem) {
        self.name = name
        self.brand = food.brand
        self.isRecipe = false
        self.foodData = try? JSONEncoder().encode(food)
    }

    init(recipeName: String, ingredients: [RecipeIngredient], portions: Int) {
        self.name = recipeName
        self.isRecipe = true
        self.portions = max(1, portions)
        self.ingredientsData = try? JSONEncoder().encode(ingredients)
    }

    var ingredients: [RecipeIngredient] {
        get { ingredientsData.flatMap { try? JSONDecoder().decode([RecipeIngredient].self, from: $0) } ?? [] }
        set { ingredientsData = try? JSONEncoder().encode(newValue) }
    }

    var totalGrams: Double { ingredients.reduce(0) { $0 + $1.grams } }

    /// Loggable food item.
    var food: FoodItem {
        if !isRecipe, let data = foodData, var f = try? JSONDecoder().decode(FoodItem.self, from: data) {
            f.id = "custom-\(id.uuidString)"
            f.name = name
            return f
        }
        let total = ingredients.reduce(Nutrients()) { $0 + $1.nutrients }
        let grams = max(totalGrams, 1)
        let portionGrams = (grams / Double(max(portions, 1)) * 10).rounded() / 10
        return FoodItem(id: "recipe-\(id.uuidString)", name: name, brand: nil, source: .custom,
                        per100: total.scaled(100 / grams), unit: "g",
                        servings: [ServingOption(name: "1 Portion", grams: portionGrams),
                                   ServingOption(name: "Ganzes Rezept (\(portions) Port.)", grams: grams.rounded())],
                        origin: "Rezept · \(ingredients.count) Zutaten", recipeIngredients: ingredients)
    }
}
