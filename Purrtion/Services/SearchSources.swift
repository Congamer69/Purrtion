import Foundation

/// Which databases the food search uses (Einstellungen → Datenquellen).
enum SearchSource: String, CaseIterable, Identifiable {
    case bls, swiss, restaurants, openFoodFacts, ai

    var id: String { rawValue }
    var storageKey: String { "source.\(rawValue)" }

    var isEnabled: Bool { UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true }

    var title: String {
        switch self {
        case .bls: "Bundeslebensmittelschlüssel 4.0"
        case .swiss: "Schweizer Nährwertdatenbank"
        case .restaurants: "Restaurantketten"
        case .openFoodFacts: "Open Food Facts"
        case .ai: "KI-Schätzung"
        }
    }

    var detail: String {
        switch self {
        case .bls: "7.140 Lebensmittel und Gerichte, bis zu 138 Nährstoffe, im Labor analysiert. Offline."
        case .swiss: "1.216 Lebensmittel, darunter 150 fertige Gerichte wie Burger, Kebab, Pizza oder Gratins. Offline."
        case .restaurants: "McDonald's und Burger King mit den offiziellen Nährwerten der Ketten, inklusive Portionsgröße. Offline."
        case .openFoodFacts: "Barcodes & Markenprodukte, deutsche Produkte bevorzugt. Braucht Internet."
        case .ai: "Für alles, was keine Datenbank kennt – Restaurantgerichte oder ganze Sätze wie „2 Eier und ein Toast“. Nutzt den Anbieter der Foto-Erkennung."
        }
    }

    var icon: String {
        switch self {
        case .bls: "leaf.fill"
        case .swiss: "mountain.2.fill"
        case .restaurants: "takeoutbag.and.cup.and.straw.fill"
        case .openFoodFacts: "cart.fill"
        case .ai: "sparkles"
        }
    }
}
