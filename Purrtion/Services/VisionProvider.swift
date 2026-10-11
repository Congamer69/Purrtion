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
