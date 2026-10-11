import Foundation

/// Which engine analyses meal photos. Apple is free and on-device; the others use your own API key.
enum VisionProvider: String, CaseIterable, Identifiable {
    case apple, gemini, claude, openai

    static let storageKey = "vision.provider"
    static var current: VisionProvider {
        VisionProvider(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .apple
    }

    var id: String { rawValue }

    var name: String {
        switch self {
        case .apple: "Apple Intelligence"
        case .gemini: "Google Gemini"
        case .claude: "Claude (Anthropic)"
        case .openai: "OpenAI"
        }
    }

    var icon: String {
        switch self {
        case .apple: "apple.intelligence"
        case .gemini: "sparkles"
        case .claude: "asterisk"
        case .openai: "circle.hexagongrid"
        }
    }

    var costNote: String {
        switch self {
        case .apple: "Kostenlos · auf dem iPhone · kein Schlüssel nötig"
        case .gemini: "Kostenloses Kontingent mit eigenem Schlüssel · Daten können im Gratis-Tarif zum Training genutzt werden"
        case .claude: "Sehr genau · kostet pro Foto ein paar Cent"
        case .openai: "Kostet pro Foto ca. 1 Cent oder weniger"
        }
    }

    var needsKey: Bool { self != .apple }
    var keychainKey: String { "apiKey.\(rawValue)" }
    var modelStorageKey: String { "vision.model.\(rawValue)" }

    var defaultModel: String {
        switch self {
        case .apple: ""
        case .gemini: "gemini-3.8-flash"
        case .claude: "claude-opus-5-5"
        case .openai: "gpt-5.4-mini"
        }
    }

    var model: String {
        let m = UserDefaults.standard.string(forKey: modelStorageKey)?.trimmingCharacters(in: .whitespaces) ?? ""
        return m.isEmpty ? defaultModel : m
    }

    /// Pasted keys often carry a stray space or line break – trim them.
    var apiKey: String { (Keychain.get(keychainKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    var keyURL: URL? {
        switch self {
        case .apple: nil
        case .gemini: URL(string: "https://aistudio.google.com/apikey")
        case .claude: URL(string: "https://console.anthropic.com/settings/keys")
        case .openai: URL(string: "https://platform.openai.com/api-keys")
        }
    }
}

/// What the AI is used for – each task can use its own provider and model.
enum AITask: String, CaseIterable, Identifiable {
    case photo, day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: "Foto-Erkennung"
        case .day: "Tagesanalyse"
        }
    }

    /// Photo keeps the original keys so existing settings stay valid.
    var providerKey: String { self == .photo ? VisionProvider.storageKey : "vision.day.provider" }
    func modelKey(_ p: VisionProvider) -> String { self == .photo ? p.modelStorageKey : "vision.day.model.\(p.rawValue)" }

    /// The day analysis follows the photo provider until one is chosen explicitly.
    var provider: VisionProvider {
        let raw = UserDefaults.standard.string(forKey: providerKey) ?? ""
        if let p = VisionProvider(rawValue: raw) { return p }
        return self == .day ? AITask.photo.provider : .apple
    }

    var followsPhoto: Bool { self == .day && VisionProvider(rawValue: UserDefaults.standard.string(forKey: providerKey) ?? "") == nil }

    /// Own model for this task → otherwise the photo model of that provider → default.
    func model(for p: VisionProvider) -> String {
        let own = UserDefaults.standard.string(forKey: modelKey(p))?.trimmingCharacters(in: .whitespaces) ?? ""
        if !own.isEmpty { return own }
        return self == .day ? AITask.photo.model(for: p) : p.defaultModel
    }

    var model: String { model(for: provider) }
}

extension VisionProvider {
    var shortName: String {
        switch self {
        case .apple: "Apple"
        case .gemini: "Gemini"
        case .claude: "Claude"
        case .openai: "OpenAI"
        }
    }

    /// Common choices offered in the model menu (any other model id can be typed).
    var suggestedModels: [String] {
        switch self {
        case .apple: []
        case .claude: ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
        case .gemini: ["gemini-3.8-flash"]
        case .openai: ["gpt-5.4-mini"]
        }
    }
}
