import Foundation
import SwiftData

/// Streak shop: points earned by logging buy fur colours, hats, glasses, scarves and an extra freeze.
/// The points are computed from the history (so a restored backup brings them back); only what was bought is stored.
struct ShopItem: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Identifiable {
        case fur, hat, glasses, scarf, extra
        var id: String { rawValue }
        var title: String { switch self { case .fur: "Fell"; case .hat: "Hüte"; case .glasses: "Brillen"; case .scarf: "Schals"; case .extra: "Extras" } }
    }
    let id: String
    let name: String
    let kind: Kind
    let price: Int
}

enum Shop {
    static var enabled: Bool { Extras.bool(Extras.shopKey, default: true) }

    static let items: [ShopItem] = [
        .init(id: "moon", name: "Mondschein", kind: .fur, price: 150), .init(id: "cinnamon", name: "Zimt", kind: .fur, price: 150),
        .init(id: "mint", name: "Minze", kind: .fur, price: 200), .init(id: "sakura", name: "Sakura", kind: .fur, price: 250),
        .init(id: "galaxy", name: "Galaxie", kind: .fur, price: 400),
        .init(id: "hat.party", name: "Partyhut", kind: .hat, price: 60), .init(id: "hat.beanie", name: "Mütze", kind: .hat, price: 80),
        .init(id: "hat.top", name: "Zylinder", kind: .hat, price: 120), .init(id: "hat.wizard", name: "Zauberhut", kind: .hat, price: 200),
        .init(id: "hat.crown", name: "Krone", kind: .hat, price: 300),
        .init(id: "glasses.round", name: "Brille", kind: .glasses, price: 90), .init(id: "glasses.sun", name: "Sonnenbrille", kind: .glasses, price: 130),
        .init(id: "scarf.red", name: "Roter Schal", kind: .scarf, price: 70), .init(id: "scarf.blue", name: "Blauer Schal", kind: .scarf, price: 70),
        .init(id: "scarf.green", name: "Grüner Schal", kind: .scarf, price: 70), .init(id: "scarf.violet", name: "Violetter Schal", kind: .scarf, price: 100),
        .init(id: "scarf.gold", name: "Goldschal", kind: .scarf, price: 180),
        .init(id: "extra.freeze", name: "Extra-Freeze", kind: .extra, price: 120),
    ]

    // MARK: Points

    private static let milestoneBonus: [(days: Int, points: Int)] = [(3, 20), (7, 50), (14, 100), (30, 200), (60, 400), (100, 800), (200, 1500), (365, 3000)]

    /// 5 points for every logged day, 10 more when the day ended close to the goal, and a bonus for each streak milestone reached.
    @MainActor
    static func earned(ctx: ModelContext, goals: Goals, bestStreak: Int) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let from = cal.date(byAdding: .day, value: -800, to: today)!
        let entries = (try? ctx.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.day >= from }))) ?? []
        var kcalByDay: [Date: Double] = [:]
        for e in entries { kcalByDay[e.day, default: 0] += e.kcal }
        var points = 0
        for (day, kcal) in kcalByDay where day < today {          // today counts once it is over
            points += 5
            let goal = goals.target(for: day).kcal
            if kcal >= goal * 0.7 && kcal <= goal * 1.05 { points += 10 }
        }
        points += milestoneBonus.filter { bestStreak >= $0.days }.reduce(0) { $0 + $1.points }
        return points
    }

    // MARK: Ownership

    private static let ownedKey = "shop.owned"
    private static let extrasSpentKey = "shop.extrasSpent"

    static var owned: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: ownedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: ownedKey) }
    }

    static var spent: Int {
        owned.compactMap { id in items.first { $0.id == id }?.price }.reduce(0, +) + UserDefaults.standard.integer(forKey: extrasSpentKey)
    }

    static func balance(earned: Int) -> Int { max(0, earned - spent) }

    /// Buys an item; true when it worked. Fur, hats, glasses and scarves are put on right away.
    @discardableResult
    static func buy(_ item: ShopItem, balance: Int) -> Bool {
        guard balance >= item.price else { return false }
        if item.kind == .extra {
            let defaults = UserDefaults.standard
            let freezes = defaults.object(forKey: "streak.freezes") as? Int ?? 1
            guard freezes < Streak.maxFreezes else { return false }
            defaults.set(freezes + 1, forKey: "streak.freezes")
            defaults.set(defaults.integer(forKey: extrasSpentKey) + item.price, forKey: extrasSpentKey)
            return true
        }
        guard !owned.contains(item.id) else { return false }
        owned.insert(item.id)
        equip(item)
        return true
    }

    // MARK: Wearing

    static func key(for kind: ShopItem.Kind) -> String? {
        switch kind { case .fur: "catPalette"; case .hat: "shop.hat"; case .glasses: "shop.glasses"; case .scarf: "shop.scarf"; case .extra: nil }
    }

    static func isWorn(_ item: ShopItem) -> Bool {
        guard let key = key(for: item.kind) else { return false }
        return UserDefaults.standard.string(forKey: key) == item.id
    }

    /// Puts it on, or takes it off when it is worn already (fur goes back to the first cat).
    static func equip(_ item: ShopItem) {
        guard let key = key(for: item.kind), owned.contains(item.id) else { return }
        let defaults = UserDefaults.standard
        if isWorn(item) { defaults.set(item.kind == .fur ? CatPalette.ginger.id : "", forKey: key) } else { defaults.set(item.id, forKey: key) }
    }

    /// What the cat wears now. Friends always see it, whatever the shop switch says.
    static var currentOutfit: Outfit {
        let d = UserDefaults.standard
        return Outfit(hat: d.string(forKey: "shop.hat") ?? "", glasses: d.string(forKey: "shop.glasses") ?? "", scarf: d.string(forKey: "shop.scarf") ?? "")
    }

    static func takeOffAll() {
        for k in ["shop.hat", "shop.glasses", "shop.scarf"] { UserDefaults.standard.set("", forKey: k) }
    }

    /// Palettes the user may pick in the settings: the four cats plus bought fur colours.
    static var palettes: [CatPalette] { CatPalette.all + CatPalette.shop.filter { owned.contains($0.id) } }
}
