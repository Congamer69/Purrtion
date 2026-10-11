import Foundation
import SwiftData
import SwiftUI

/// Result of "Tag abschließen": the AI's short verdict on one day.
@Model
final class DayReview {
    var day: Date = Date()
    var createdAt: Date = Date()
    /// One or two words, e.g. "Ausgewogen".
    var rating: String = ""
    /// "positiv", "neutral" or "kritisch".
    var tone: String = "neutral"
    var pointsData: Data?
    /// Fingerprint of the day's entries when the review was made – used to detect later changes.
    var signature: String = ""
    var enrichedCount: Int = 0
    var providerName: String = ""
    var score: Int?
    /// Health score without the AI-added micronutrients.
    var scoreBefore: Int?
    /// Created automatically by the nightly analysis.
    var automatic: Bool = false

    init(day: Date) {
        self.day = Calendar.current.startOfDay(for: day)
    }

    var points: [String] {
        get { pointsData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
        set { pointsData = try? JSONEncoder().encode(newValue) }
    }

    var color: Color {
        switch tone {
        case "positiv": Theme.fiber
        case "kritisch": Theme.accent
        default: Theme.carbs
        }
    }

    var mood: CatMood {
        switch tone {
        case "positiv": .happy
        case "kritisch": .full
        default: .idle
        }
    }

    static func signature(for entries: [FoodEntry]) -> String {
        entries.map { "\($0.id.uuidString):\(Int($0.kcal.rounded()))" }.sorted().joined(separator: "|")
    }
}
