import Foundation
import SwiftData
import AuthenticationServices
import UIKit

/// The server account: a Google login linked to the anonymous Firebase account, so friends and the server backup
/// follow the person to a new device. Without a login nothing changes: the local backup keeps working on its own.
@MainActor
final class ServerAccount: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ServerAccount()
    static let emailKey = "account.email"
    static let autoKey = "account.autoBackup"
    private static let lastKey = "account.lastBackup"

    private let defaults = UserDefaults.standard
    @Published private(set) var email: String?
    @Published private(set) var busy = false
    @Published var status: String?
    /// Server backup as last seen.
    @Published private(set) var remote: ServerBackup.Meta?
    /// The Google account already belongs to another uid (often a new device): ask before taking it over.
    @Published var conflict: Conflict?
    /// Backing up would replace a much bigger server backup: ask first.
    @Published var shrinkWarning: ServerBackup.Shrinks?
    private var session: ASWebAuthenticationSession?

    struct Conflict: Identifiable {
        let id = UUID()
        let backup: ServerBackup.Meta?
        let previous: (uid: String, refresh: String)?
        let hadFriends: Bool
    }

    override init() {
        email = UserDefaults.standard.string(forKey: Self.emailKey)
        super.init()
    }

    var isLinked: Bool { email != nil && FirebaseAuth.shared.hasAccount }
    var autoEnabled: Bool { get { defaults.object(forKey: Self.autoKey) as? Bool ?? true } set { defaults.set(newValue, forKey: Self.autoKey); objectWillChange.send() } }
    var lastBackup: Date? { defaults.object(forKey: Self.lastKey) as? Date }

    /// Where the login page lives: the hosting site of the server, taken from the invite link.
    private var origin: String? {
        if let u = URL(string: FirebaseConfig.inviteURL), let scheme = u.scheme, let host = u.host { return "\(scheme)://\(host)" }
        return FirebaseConfig.projectID.map { "https://\($0).web.app" }
    }

    // MARK: Login

    func signIn() async {
        guard let origin, let key = FirebaseConfig.apiKey, let project = FirebaseConfig.projectID else {
            status = "Verbinde zuerst den Server."
            return
        }
        busy = true
        defer { busy = false }
        status = nil
        do {
            let state = UUID().uuidString
            var c = URLComponents(string: origin + "/auth/")!
            c.queryItems = [.init(name: "k", value: key), .init(name: "p", value: project), .init(name: "s", value: state)]
            let items = URLComponents(url: try await open(c.url!), resolvingAgainstBaseURL: false)?.queryItems ?? []
            func value(_ n: String) -> String? { items.first { $0.name == n }?.value }
            guard value("s") == state else { throw FirebaseError.server("Die Antwort gehört nicht zu dieser Anmeldung.") }
            guard let token = value("id") else { throw FirebaseError.server("Google hat die Anmeldung nicht bestätigt.") }
            try await finish(googleToken: token)
        } catch let e as ASWebAuthenticationSessionError where e.code == .canceledLogin {
            // closed by the person
        } catch {
            status = "Anmeldung fehlgeschlagen. \(error.localizedDescription)"
        }
    }

    private func open(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            let s = ASWebAuthenticationSession(url: url, callbackURLScheme: "purrtion") { callback, error in
                if let callback { cont.resume(returning: callback) } else { cont.resume(throwing: error ?? FirebaseError.offline) }
            }
            s.presentationContextProvider = self
            session = s
            if !s.start() { cont.resume(throwing: FirebaseError.server("Das Anmeldefenster ließ sich nicht öffnen.")) }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            return scene?.keyWindow ?? scene?.windows.first ?? ASPresentationAnchor()
        }
    }

    private func finish(googleToken: String) async throws {
        let auth = FirebaseAuth.shared
        let previous: (uid: String, refresh: String)? = auth.hasAccount ? (auth.uid ?? "", Keychain.get("fb.refresh") ?? "") : nil
        let hadFriends = FriendsStore.shared.me != nil
        let result: FirebaseAuth.GoogleResult
        do {
            result = try await auth.googleSignIn(googleIDToken: googleToken, link: previous != nil)
        } catch FirebaseError.server(let message) where message.contains("ALREADY_LINKED") {
            result = try await auth.googleSignIn(googleIDToken: googleToken, link: false)
        }
        auth.use(result)
        setEmail(result.email.isEmpty ? "Google" : result.email)
        if previous?.uid == result.uid {
            // Linked: same account, friends and code stay.
            autoEnabled = true
            status = "Angemeldet. Dein Konto ist mit Google verknüpft."
            remote = try? await ServerBackup.meta()
            return
        }
        let backup = try? await ServerBackup.meta()
        remote = backup
        if backup != nil || (previous != nil && hadFriends) {
            conflict = Conflict(backup: backup, previous: previous, hadFriends: previous != nil && hadFriends)
        } else {
            takeOver()
        }
    }

    /// The Google account's data replaces what the old account had on this device (friends are read from the server).
    private func takeOver() {
        FriendsStore.shared.reloadAfterAccountChange()
        autoEnabled = true
        status = "Angemeldet."
    }

    /// Answer to the conflict dialog.
    func resolve(_ c: Conflict, load: Bool, ctx: ModelContext) async {
        conflict = nil
        guard load else {
            // Back to the account this device had.
            if let p = c.previous { FirebaseAuth.shared.adopt(uid: p.uid, refresh: p.refresh) } else { FirebaseAuth.shared.signOut() }
            setEmail(nil)
            remote = nil
            status = "Abgebrochen. Es wurde nichts verändert."
            return
        }
        takeOver()
        if c.backup != nil { await restore(ctx) } else { await backupNow(ctx, force: true) }
    }

    func signOutLocal() {
        FirebaseAuth.shared.signOut()
        setEmail(nil)
        remote = nil
    }

    func signOut() {
        signOutLocal()
        FriendsStore.shared.reloadAfterAccountChange()
        status = "Abgemeldet. Deine Daten auf diesem iPhone bleiben."
    }

    private func setEmail(_ value: String?) {
        email = value
        if let value { defaults.set(value, forKey: Self.emailKey) } else { defaults.removeObject(forKey: Self.emailKey) }
    }

    // MARK: Backup

    func refreshRemote() async {
        guard isLinked else { return }
        remote = try? await ServerBackup.meta()
    }

    func backupNow(_ ctx: ModelContext, force: Bool = false, automatic: Bool = false) async {
        guard isLinked, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let meta = try await ServerBackup.upload(ctx, force: force)
            remote = meta
            defaults.set(Date(), forKey: Self.lastKey)
            status = automatic ? nil : "Gesichert ✓"
            if !automatic { Haptics.success() }
        } catch let s as ServerBackup.Shrinks {
            if automatic { status = "Automatisch sichern pausiert: Das Server-Backup hat deutlich mehr Einträge (\(s.remote)) als dieses iPhone (\(s.local))." }
            else { shrinkWarning = s }
        } catch {
            if !automatic { status = "Sicherung fehlgeschlagen. \(error.localizedDescription)" }
        }
    }

    /// Replaces the data on this device with the server backup.
    func restore(_ ctx: ModelContext) async {
        guard isLinked else { return }
        busy = true
        defer { busy = false }
        do {
            let data = try await ServerBackup.download()
            let p = try Backup.restore(from: data, into: ctx)
            defaults.set(Date(), forKey: Self.lastKey)
            remote = try? await ServerBackup.meta()
            status = "Wiederhergestellt: \(p.entries.count) Einträge, \(p.custom.count) eigene Lebensmittel und Rezepte."
            Haptics.success()
        } catch {
            status = "Wiederherstellung fehlgeschlagen. \(error.localizedDescription)"
        }
    }

    func deleteRemote() async {
        busy = true
        defer { busy = false }
        do {
            try await ServerBackup.delete()
            remote = nil
            status = "Das Server-Backup ist gelöscht."
        } catch { status = "Löschen fehlgeschlagen. \(error.localizedDescription)" }
    }

    /// Called when the app becomes active: about once a day.
    func autoBackupIfNeeded(_ ctx: ModelContext) {
        guard isLinked, autoEnabled, !busy else { return }
        if let last = lastBackup, Date().timeIntervalSince(last) < 20 * 3600 { return }
        Task { await backupNow(ctx, automatic: true) }
    }
}
