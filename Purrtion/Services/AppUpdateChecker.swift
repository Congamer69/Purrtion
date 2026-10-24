import SwiftUI

/// Tells you when a newer Purrtion is published. iOS does not let an app replace itself, so this only notifies and
/// hands over to SideStore (`sidestore://install?url=…`, see docs.sidestore.io → URL Schema), which installs the new IPA
/// as an update. The version comes from the same source file SideStore reads, so both always agree.
@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    static let sourceURL = URL(string: "https://raw.githubusercontent.com/Congamer69/Purrtion/main/distribution/sidestore-source.json")!
    static let releasePage = URL(string: "https://github.com/Congamer69/Purrtion/releases/latest")!
    private static let bundleID = "com.const.purrtion"

    /// The automatic check asks the network at most this often, otherwise the saved answer is used.
    private static let interval: TimeInterval = 6 * 3600
    /// "Später" silences the prompt for this build for this long. The settings row still shows the update.
    private static let snooze: TimeInterval = 3 * 86400

    struct Release: Codable, Equatable {
        let version: String
        let build: Int
        let notes: String
        let downloadURL: URL
    }

    @Published private(set) var available: Release?
    @Published private(set) var isChecking = false
    /// Result of a manual check ("Du bist auf dem neuesten Stand", an error …).
    @Published private(set) var message: String?
    @Published var showSheet = false
    /// SideStore could not be opened, so the sheet shows the steps to do by hand.
    @Published private(set) var needsManualSteps = false

    @AppStorage("update.lastCheck") private var lastCheck = 0.0
    @AppStorage("update.cache") private var cache = Data()
    @AppStorage("update.snoozedBuild") private var snoozedBuild = 0
    @AppStorage("update.snoozedUntil") private var snoozedUntil = 0.0

    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
    var currentBuild: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0 }

    private init() { available = newer(than: decode(cache)) }

    // MARK: Checking

    /// On launch: uses the saved answer while it is fresh, asks the network otherwise. Never blocks and never complains.
    func checkOnLaunch() async {
        if Date().timeIntervalSince1970 - lastCheck >= Self.interval { _ = await fetch() }
        if let release = available, !isSnoozed(release) { showSheet = true }
    }

    /// "Nach Updates suchen": always asks the network (not more often than every 20 seconds) and says what happened.
    func checkManually() async {
        message = nil
        if Date().timeIntervalSince1970 - lastCheck >= 20 {
            guard await fetch() else { message = "Keine Verbindung. Versuche es später noch einmal."; return }
        }
        if available != nil { showSheet = true } else { message = "Du hast die neueste Version (\(currentVersion))." }
    }

    private func fetch() async -> Bool {
        guard !isChecking else { return false }
        isChecking = true
        defer { isChecking = false }
        var request = URLRequest(url: Self.sourceURL, timeoutInterval: 15)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let latest = Self.latest(in: data) else { return false }
        lastCheck = Date().timeIntervalSince1970
        cache = (try? JSONEncoder().encode(latest)) ?? Data()
        available = newer(than: latest)
        return true
    }

    private func decode(_ data: Data) -> Release? { try? JSONDecoder().decode(Release.self, from: data) }
    private func newer(than release: Release?) -> Release? {
        guard let release, release.build > currentBuild else { return nil }
        return release
    }
    private func isSnoozed(_ release: Release) -> Bool {
        snoozedBuild == release.build && Date().timeIntervalSince1970 < snoozedUntil
    }

    /// The version with the highest build number for this app in a SideStore source file.
    nonisolated static func latest(in data: Data) -> Release? {
        struct Source: Decodable {
            struct App: Decodable {
                struct Version: Decodable { let version: String; let buildVersion: String?; let localizedDescription: String?; let downloadURL: URL }
                let bundleIdentifier: String
                let versions: [Version]
            }
            let apps: [App]
        }
        guard let source = try? JSONDecoder().decode(Source.self, from: data),
              let app = source.apps.first(where: { $0.bundleIdentifier == bundleID }) else { return nil }
        return app.versions
            .compactMap { v in Int(v.buildVersion ?? "").map { Release(version: v.version, build: $0, notes: v.localizedDescription ?? "", downloadURL: v.downloadURL) } }
            .max { $0.build < $1.build }
    }

    // MARK: Actions

    func later() {
        if let release = available { snoozedBuild = release.build; snoozedUntil = Date().timeIntervalSince1970 + Self.snooze }
        showSheet = false
        needsManualSteps = false
    }

    /// Hands the new IPA to SideStore, which installs it over this app (same bundle identifier, so the data stays).
    func update() {
        guard let release = available else { return }
        var components = URLComponents()
        components.scheme = "sidestore"
        components.host = "install"
        components.queryItems = [URLQueryItem(name: "url", value: release.downloadURL.absoluteString)]
        guard let url = components.url else { needsManualSteps = true; return }
        UIApplication.shared.open(url) { [weak self] opened in
            Task { @MainActor in
                if opened { self?.showSheet = false } else { self?.needsManualSteps = true }
            }
        }
    }
}

// MARK: - Sheet

/// The update prompt: versions, notes, and "Später" / "Aktualisieren". Never blocks the app.
struct AppUpdateSheet: View {
    @ObservedObject var checker: AppUpdateChecker
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let release = checker.available {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.accentText)
                        .frame(width: 52, height: 52).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Update verfügbar").font(Theme.font(22, .bold))
                        Text("Version \(checker.currentVersion) → \(release.version)").font(Theme.font(14)).foregroundStyle(Theme.textSecondary)
                    }
                }
                ScrollView {
                    Text(release.notes.isEmpty ? "Keine Hinweise zu dieser Version." : release.notes)
                        .font(Theme.font(14)).foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

                if checker.needsManualSteps {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SideStore ließ sich nicht öffnen.").font(Theme.font(14, .semibold))
                        Text("Öffne SideStore, wechsle zu „Meine Apps“ und tippe bei Purrtion auf „Aktualisieren“. Erscheint dort nichts, ziehe die Liste nach unten.")
                            .font(Theme.font(13)).foregroundStyle(Theme.textSecondary)
                        Button("Release-Seite öffnen") { openURL(AppUpdateChecker.releasePage) }.font(Theme.font(14, .bold))
                    }
                }

                HStack(spacing: 12) {
                    Button { checker.later() } label: {
                        Text("Später").font(Theme.font(16, .semibold)).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.accentSoft, in: Capsule())
                    }
                    Button { Haptics.tap(); checker.update() } label: {
                        Text("Aktualisieren").font(Theme.font(16, .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .presentationDetents([.medium, .large])
            .onDisappear { checker.later() }
        }
    }
}

/// Settings row: current version, "Update verfügbar" and a manual check.
struct AppUpdateRow: View {
    @ObservedObject private var checker = AppUpdateChecker.shared

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.circle").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.accentText)
                .frame(width: 32, height: 32).background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text("App-Update").font(Theme.font(15, .semibold))
                Text(checker.available.map { "Version \($0.version) verfügbar" } ?? "Version \(checker.currentVersion) (\(checker.currentBuild))")
                    .font(Theme.font(12)).foregroundStyle(Theme.textSecondary)
                if let message = checker.message {
                    Text(message).font(Theme.font(12, .semibold)).foregroundStyle(Theme.accentText)
                }
            }
            Spacer(minLength: 0)
            if checker.isChecking {
                ProgressView()
            } else {
                Button(checker.available == nil ? "Prüfen" : "Ansehen") { Task { await checker.checkManually() } }
                    .font(Theme.font(14, .bold)).buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }
}
