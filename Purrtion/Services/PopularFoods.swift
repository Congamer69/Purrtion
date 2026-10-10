import Foundation

/// Hand-picked everyday foods: friendly names, search aliases and realistic portion sizes,
/// mapped onto the matching BLS entry (which provides all nutrient values).
enum PopularFoods {
    struct Entry {
        let code: String
        let name: String
        let aliases: [String]
        let servings: [ServingOption]
        let unit: String?

        var searchTerms: [String] { ([name] + aliases).map(BLSDatabase.fold) }
        var searchText: String { searchTerms.joined(separator: " ") }
    }

    private static func e(_ code: String, _ name: String, _ servings: [(String, Double)], aka: [String] = [], unit: String? = nil) -> Entry {
        Entry(code: code, name: name, aliases: aka, servings: servings.map { ServingOption(name: $0.0, grams: $0.1) }, unit: unit)
    }

    static let all: [Entry] = [
        // Obst
        e("F110100", "Apfel", [("1 mittel", 180), ("1 klein", 130), ("1 groß", 230)], aka: ["Äpfel"]),
        e("F503100", "Banane", [("1 mittel", 120), ("1 klein", 100), ("1 groß", 140)], aka: ["Bananen"]),
        e("F130100", "Birne", [("1 mittel", 180)]),
        e("F603100", "Orange", [("1 mittel", 150)], aka: ["Apfelsine"]),
        e("F606100", "Mandarine", [("1 Stück", 75)], aka: ["Clementine"]),
        e("F301100", "Erdbeeren", [("1 Schale", 250), ("1 Handvoll", 80), ("1 Stück", 12)], aka: ["Erdbeere"]),
        e("F304100", "Heidelbeeren", [("1 Handvoll", 70), ("1 Schale", 125)], aka: ["Blaubeeren", "Heidelbeere"]),
        e("F302100", "Himbeeren", [("1 Handvoll", 60), ("1 Schale", 125)], aka: ["Himbeere"]),
        e("F310100", "Weintrauben", [("1 Handvoll", 80), ("1 Traube", 5)], aka: ["Trauben"]),
        e("F514100", "Kiwi", [("1 Stück", 75)]),
        e("F516100", "Mango", [("1 Stück (ohne Kern)", 300), ("1 Schnitz", 100)]),
        e("F501100", "Ananas", [("1 Scheibe", 80)]),
        e("F535100", "Wassermelone", [("1 Scheibe", 280)], aka: ["Melone"]),
        e("F502100", "Avocado", [("1 Stück (ohne Kern)", 140), ("½ Stück", 70)]),
        // Gemüse
        e("G561100", "Tomate", [("1 mittel", 120), ("1 Cherrytomate", 15)], aka: ["Tomaten"]),
        e("G520100", "Gurke", [("1 Stück", 400), ("1 Scheibe", 8)], aka: ["Salatgurke"]),
        e("G543100", "Paprika rot", [("1 Stück", 160)], aka: ["Paprika"]),
        e("G620100", "Karotte", [("1 mittel", 60)], aka: ["Möhre", "Karotten", "Möhren"]),
        e("G312100", "Brokkoli", [("1 Portion", 150), ("1 Röschen", 15)], aka: ["Broccoli"]),
        e("G211100", "Spinat", [("1 Portion", 150), ("1 Handvoll", 30)], aka: ["Blattspinat"]),
        e("G582100", "Zucchini", [("1 Stück", 250)]),
        e("K110132", "Kartoffeln gekocht", [("1 mittel", 90), ("1 Portion", 200)], aka: ["Kartoffel", "Salzkartoffeln"]),
        e("K420162", "Süßkartoffel gebacken", [("1 mittel", 150)], aka: ["Süßkartoffel"]),
        e("G480100", "Zwiebel", [("1 mittel", 110)]),
        e("K701100", "Champignons", [("1 Portion", 100), ("1 Stück", 15)], aka: ["Pilze"]),
        e("G103100", "Eisbergsalat", [("1 Schüssel", 100)], aka: ["Salat"]),
        e("G570902", "Mais (Dose)", [("1 kleine Dose", 140), ("1 EL", 15)], aka: ["Mais"]),
        // Getreide & Beilagen
        e("X820162", "Reis gekocht", [("1 Portion", 200), ("1 Tasse", 160)], aka: ["Reis"]),
        e("C352000", "Reis ungekocht", [("1 Portion", 75)]),
        e("E401032", "Nudeln gekocht", [("1 Portion", 250), ("1 Tasse", 140)], aka: ["Pasta", "Spaghetti", "Nudeln"]),
        e("E401000", "Nudeln ungekocht", [("1 Portion", 100)], aka: ["Spaghetti roh"]),
        e("C133000", "Haferflocken", [("1 EL", 10), ("1 Portion", 50)], aka: ["Porridge", "Hafer"]),
        e("B111000", "Vollkornbrot", [("1 Scheibe", 50)], aka: ["Brot"]),
        e("B271000", "Mischbrot", [("1 Scheibe", 45)], aka: ["Brot", "Roggenmischbrot"]),
        e("B314000", "Toast", [("1 Scheibe", 25)], aka: ["Toastbrot"]),
        e("B511000", "Brötchen", [("1 Stück", 55)], aka: ["Semmel", "Weckle", "Schrippe"]),
        e("B723000", "Laugenbrezel", [("1 Stück", 80)], aka: ["Brezel", "Breze"]),
        e("D771600", "Croissant", [("1 Stück", 60)]),
        e("C514200", "Müsli (Knuspermüsli)", [("1 Portion", 60)], aka: ["Müsli", "Granola"]),
        e("C118032", "Quinoa gekocht", [("1 Portion", 185)], aka: ["Quinoa"]),
        e("C119232", "Couscous gekocht", [("1 Portion", 160)], aka: ["Couscous"]),
        // Milchprodukte & Eier
        e("E111100", "Ei", [("1 Ei (M)", 58), ("1 Ei (L)", 65)], aka: ["Eier", "Hühnerei"]),
        e("E111132", "Ei gekocht", [("1 Ei (M)", 58), ("1 Ei (L)", 65)], aka: ["Frühstücksei"]),
        e("Y710142", "Spiegelei", [("1 Ei", 50)]),
        e("Y720143", "Rührei", [("aus 2 Eiern", 120), ("aus 3 Eiern", 180)]),
        e("M111200", "Milch 1,5 %", [("1 Glas", 200), ("1 Tasse", 150), ("Schuss", 30)], aka: ["Milch"], unit: "ml"),
        e("M111300", "Milch 3,5 %", [("1 Glas", 200), ("Schuss", 30)], aka: ["Vollmilch", "Milch"], unit: "ml"),
        e("C660000", "Hafermilch", [("1 Glas", 200), ("Schuss", 30)], aka: ["Haferdrink"], unit: "ml"),
        e("M141300", "Joghurt natur 3,5 %", [("1 Becher", 150), ("1 EL", 20)], aka: ["Joghurt"]),
        e("M710100", "Skyr", [("1 Becher", 150), ("1 Portion", 200)]),
        e("M713100", "Magerquark", [("1 Packung", 250), ("1 EL", 30)], aka: ["Quark"]),
        e("M711100", "Hüttenkäse", [("1 Becher", 200)], aka: ["Körniger Frischkäse", "Cottage Cheese"]),
        e("M402600", "Gouda", [("1 Scheibe", 25)], aka: ["Käse"]),
        e("M032100", "Mozzarella", [("1 Kugel", 125)]),
        e("M012200", "Feta", [("1 Portion", 50)], aka: ["Schafskäse"]),
        e("M306400", "Parmesan", [("1 EL gerieben", 6)]),
        e("Q630000", "Butter", [("1 TL", 5), ("1 EL", 12), ("für 1 Brot", 8)]),
        // Fleisch & Fisch
        e("V416172", "Hähnchenbrust", [("1 Filet", 150), ("1 Portion", 125)], aka: ["Hühnchen", "Hähnchen", "Hühnerbrust"]),
        e("U010100", "Rinderhackfleisch", [("1 Portion", 125)], aka: ["Hackfleisch", "Hack"]),
        e("U131172", "Rindersteak", [("1 Steak", 200)], aka: ["Steak"]),
        e("U541172", "Schweineschnitzel", [("1 Schnitzel", 150)], aka: ["Schnitzel"]),
        e("T410100", "Lachs", [("1 Filet", 125)]),
        e("T121902", "Thunfisch (Dose, eigener Saft)", [("1 Dose", 150)], aka: ["Thunfisch"]),
        e("W140000", "Salami", [("1 Scheibe", 8)]),
        e("W424000", "Kochschinken", [("1 Scheibe", 20)], aka: ["Schinken"]),
        e("Y021312", "Bratwurst", [("1 Stück", 100)]),
        // Pflanzlich, Nüsse
        e("H861000", "Tofu", [("1 Packung", 200), ("1 Portion", 100)]),
        e("G770432", "Kichererbsen gekocht", [("1 Dose", 240), ("1 EL", 15)], aka: ["Kichererbsen"]),
        e("H730132", "Linsen gekocht", [("1 Portion", 200)], aka: ["Linsen"]),
        e("H742902", "Kidneybohnen (Dose)", [("1 Dose", 250)], aka: ["Kidneybohnen"]),
        e("H210100", "Mandeln", [("1 Handvoll", 30), ("1 Stück", 1.2)]),
        e("H120100", "Walnüsse", [("1 Handvoll", 30)]),
        e("H110600", "Erdnüsse", [("1 Handvoll", 30)]),
        e("H880200", "Erdnussbutter", [("1 EL", 16), ("1 TL", 6)]),
        e("Q120000", "Olivenöl", [("1 EL", 12), ("1 TL", 4)], aka: ["Öl"], unit: "ml"),
        // Süßes & Snacks
        e("S539900", "Vollmilchschokolade", [("1 Riegel", 25), ("1 Stück", 5), ("1 Tafel", 100)], aka: ["Schokolade"]),
        e("S570000", "Zartbitterschokolade", [("1 Stück", 5), ("1 Tafel", 100)], aka: ["Bitterschokolade"]),
        e("S361000", "Gummibärchen", [("1 Handvoll", 25), ("1 Tüte", 200)], aka: ["Fruchtgummi"]),
        e("K280100", "Chips", [("1 Handvoll", 25), ("1 Tüte", 175)], aka: ["Kartoffelchips"]),
        e("S145000", "Nuss-Nougat-Creme", [("1 TL", 8), ("1 EL", 20)], aka: ["Nutella"]),
        e("S120000", "Honig", [("1 TL", 7), ("1 EL", 21)]),
        e("S132000", "Marmelade", [("1 TL", 10), ("1 EL", 20)], aka: ["Konfitüre"]),
        e("S111000", "Zucker", [("1 TL", 4), ("1 Stück", 3)]),
        // Gerichte & Fast Food
        e("X912033", "Pizza Margherita", [("1 Pizza", 350), ("1 Stück (⅛)", 45)], aka: ["Pizza"]),
        e("Y921062", "Döner Kebab", [("1 Döner", 400)], aka: ["Döner"]),
        e("X654042", "Pommes frites", [("1 kleine Portion", 100), ("1 mittlere Portion", 150)], aka: ["Pommes"]),
        e("Y911060", "Burger", [("1 Burger", 220)], aka: ["Hamburger"]),
        e("X740433", "Spaghetti Bolognese", [("1 Teller", 400)], aka: ["Bolognese"]),
        e("Y943062", "Currywurst mit Brötchen", [("1 Portion", 300)], aka: ["Currywurst"]),
        e("Y627112", "Sushi mit Lachs", [("1 Stück", 25), ("8 Stück", 200)], aka: ["Sushi"]),
        // Getränke
        e("N110000", "Wasser", [("1 Glas", 250), ("1 Flasche", 500)], aka: ["Mineralwasser"]),
        e("N410100", "Kaffee schwarz", [("1 Tasse", 150), ("1 Becher", 250)], aka: ["Kaffee"]),
        e("N411100", "Espresso", [("1 Shot", 30)]),
        e("N414000", "Cappuccino", [("1 Tasse", 180)]),
        e("N418000", "Latte Macchiato", [("1 Glas", 300)], aka: ["Milchkaffee"]),
        e("F603600", "Orangensaft", [("1 Glas", 200)], aka: ["O-Saft"], unit: "ml"),
        e("N256000", "Apfelschorle", [("1 Glas", 300), ("1 Flasche", 500)], aka: ["Schorle"]),
        e("N330000", "Cola", [("1 Dose", 330), ("1 Glas", 250), ("1 Flasche", 500)]),
        e("P163000", "Bier (Pils)", [("1 Flasche", 500), ("1 kleines", 330), ("1 Maß", 1000)], aka: ["Bier", "Pils"]),
        e("P2A3000", "Rotwein", [("1 Glas", 200), ("1 kleines Glas", 125)], aka: ["Wein"]),
        e("P210000", "Weißwein", [("1 Glas", 200), ("1 kleines Glas", 125)], aka: ["Wein"]),
    ]

    static let byCode: [String: Entry] = Dictionary(all.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
}
