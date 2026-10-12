import Foundation

/// Keeps the offline food databases up to date: a small manifest in the project's GitHub repository
/// says which version of each database file is current; newer files are downloaded once, checked and
/// then used instead of the copy bundled with the app. Open Food Facts is always live anyway.
@MainActor
final class DatabaseUpdater: ObservableObject {
    static let shared = DatabaseUpdater()

    enum Database: String, CaseIterable, Identifiable {
        case bls, swiss
        var id: String { rawValue }
        var title: String { self == .bls ? "Bundeslebensmittelschlüssel" : "Schweizer Nährwertdatenbank" }
        /// Version and revision of the file shipped inside the app.
        var bundledVersion: String { self == .bls ? "4.0" : "7.1" }
        var bundledRevision: Int { 1 }
    }

    struct Manifest: Decodable {
        struct Entry: Decodable {
            let version: String
            let revision: Int
            let url: URL
            let foods: Int
        }
        let databases: [String: Entry]
    }

    static let manifestURL = URL(string: "https://raw.githubusercontent.com/Congamer69/Purrtion/main/data/manifest.json")!
    static let autoKey = "source.autoUpdate"
    private static let lastCheckKey = "source.lastUpdateCheck"

    @Published private(set) var isChecking = false
    @Published private(set) var status: String?

    var lastCheck: Date? { UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date }

    // MARK: Files

    nonisolated private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Databases", isDirectory: true)
    }

    nonisolated private static func downloadedURL(_ db: Database) -> URL {
        folder.appendingPathComponent("\(db.rawValue).json")
    }

    /// Downloaded file if present, otherwise the bundled one.
    nonisolated static func fileURL(_ db: Database) -> URL? {
        let local = downloadedURL(db)
        if FileManager.default.fileExists(atPath: local.path) { return local }
        return Bundle.main.url(forResource: db.rawValue, withExtension: "json")
    }

    func version(_ db: Database) -> String {
        UserDefaults.standard.string(forKey: "source.version.\(db.rawValue)") ?? db.bundledVersion
    }

    private func revision(_ db: Database) -> Int {
        let r = UserDefaults.standard.integer(forKey: "source.revision.\(db.rawValue)")
        return r == 0 ? db.bundledRevision : r
    }

    // MARK: Updating

    /// Automatic check, at most once a week.
    func autoUpdateIfNeeded() {
        let auto = UserDefaults.standard.object(forKey: Self.autoKey) as? Bool ?? true
        guard auto, !isChecking else { return }
        if let last = lastCheck, Date().timeIntervalSince(last) < 7 * 24 * 3600 { return }
        Task { await update(silent: true) }
    }

    func update(silent: Bool = false) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        if !silent { status = "Suche nach Updates …" }
        do {
            var request = URLRequest(url: Self.manifestURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("Purrtion", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            var updated: [String] = []
            for db in Database.allCases {
                guard let entry = manifest.databases[db.rawValue], entry.revision > revision(db) else { continue }
                if !silent { status = "Lade \(db.title) …" }
                try await install(db, from: entry)
                updated.append("\(db.title) \(entry.version)")
            }
            UserDefaults.standard.set(Date(), forKey: Self.lastCheckKey)
            status = updated.isEmpty ? (silent ? nil : "Alles aktuell") : "Aktualisiert: " + updated.joined(separator: ", ")
        } catch {
            if !silent { status = "Aktualisierung fehlgeschlagen – bitte später erneut versuchen." }
        }
    }

    private func install(_ db: Database, from entry: Manifest.Entry) async throws {
        let (data, response) = try await URLSession.shared.data(from: entry.url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        // Only accept a plausible, complete database file.
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["keys"] is [String], let foods = json["foods"] as? [[Any]],
              foods.count >= max(500, entry.foods * 9 / 10) else { throw URLError(.cannotDecodeContentData) }
        try FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        try data.write(to: Self.downloadedURL(db), options: .atomic)
        UserDefaults.standard.set(entry.version, forKey: "source.version.\(db.rawValue)")
        UserDefaults.standard.set(entry.revision, forKey: "source.revision.\(db.rawValue)")
        switch db {
        case .bls: BLSDatabase.shared.reload()
        case .swiss: SwissDatabase.shared.reload()
        }
    }
}
