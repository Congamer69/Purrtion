import Foundation
import SwiftData
import CryptoKit

/// Friends page state and sync.
///
/// Firestore usage is kept tiny:
/// - own data: one document `users/{uid}`, written only when something changed – stats at most every 15 minutes,
///   name / friend changes right away,
/// - friends: one query "friends array-contains me" returns everyone who added me (friends + requests) in a single
///   request, at most every 3 minutes (pull to refresh forces it),
/// - invite codes: one read per code lookup.
/// The last result is cached, so the page opens instantly and works offline.
@MainActor
final class FriendsStore: ObservableObject {
    static let shared = FriendsStore()

    static let enabledKey = "friends.enabled"
    static let nameKey = "friends.name"
    static let shareWeightKey = "friends.shareWeight"

    struct Person: Identifiable, Codable, Equatable {
        let id: String
        var name: String
        var palette: String
        var stats: FriendStats
        var updated: Date?
    }

    /// My own document as last written.
    struct Me: Codable, Equatable {
        var code: String
        var friends: [String] = []
        var hidden: [String] = []
        /// Sent requests: uid → label (name from the link or the code).
        var pendingLabels: [String: String] = [:]
    }

    @Published private(set) var me: Me?
    @Published private(set) var people: [Person] = []          // everyone who added me
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var busy = false
    @Published var error: String?
    /// Invite code from a link, waiting for confirmation.
    @Published var incomingCode: IncomingCode?

    struct IncomingCode: Identifiable, Equatable { let code: String; let name: String?; var id: String { code } }

    private let defaults = UserDefaults.standard
    private var lastUpload: Date? { get { defaults.object(forKey: "friends.lastUpload") as? Date } set { defaults.set(newValue, forKey: "friends.lastUpload") } }
    /// Stable across launches (Swift's Hasher is not), so an unchanged day never causes a write.
    private var lastUploadHash: String { get { defaults.string(forKey: "friends.lastHash") ?? "" } set { defaults.set(newValue, forKey: "friends.lastHash") } }

    init() {
        if let data = defaults.data(forKey: "friends.me") { me = try? JSONDecoder().decode(Me.self, from: data) }
        if let data = defaults.data(forKey: "friends.cache") { people = (try? JSONDecoder().decode([Person].self, from: data)) ?? [] }
        lastRefresh = defaults.object(forKey: "friends.lastRefresh") as? Date
    }

    var isAvailable: Bool { FirebaseConfig.isAvailable }
    var isSetUp: Bool { me != nil && FirebaseAuth.shared.hasAccount }
    var uid: String? { FirebaseAuth.shared.uid }
    var name: String { defaults.string(forKey: Self.nameKey) ?? "" }

    var friends: [Person] { people.filter { me?.friends.contains($0.id) == true } }
    var incoming: [Person] { people.filter { me?.friends.contains($0.id) != true && me?.hidden.contains($0.id) != true } }
    /// Requests I sent that were not answered yet.
    var outgoing: [(id: String, label: String)] {
        guard let me else { return [] }
        let answered = Set(people.map(\.id))
        // Only requests I sent myself – a friend who deleted their data simply disappears.
        return me.friends.filter { !answered.contains($0) && me.pendingLabels[$0] != nil }.map { ($0, me.pendingLabels[$0] ?? "") }
    }

    var inviteLink: URL? {
        guard let code = me?.code, !FirebaseConfig.inviteURL.isEmpty else { return nil }
        let n = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: FirebaseConfig.inviteURL + code + (n.isEmpty ? "" : "?n=\(n)"))
    }

    private func saveLocal() {
        defaults.set(try? JSONEncoder().encode(me), forKey: "friends.me")
        defaults.set(try? JSONEncoder().encode(people), forKey: "friends.cache")
        defaults.set(lastRefresh, forKey: "friends.lastRefresh")
    }

    private func run(_ work: () async throws -> Void) async {
        busy = true
        defer { busy = false }
        do { try await work(); error = nil } catch is CancellationError {
            // view went away / gesture ended – not an error
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Setup

    /// Signs in anonymously, restores an existing profile or creates one with a fresh invite code.
    func setUp(ctx: ModelContext, goals: Goals) async {
        await run {
            _ = try await FirebaseAuth.shared.token()
            guard let uid else { throw FirebaseError.denied }
            if me == nil {
                if let doc = try? await FirebaseREST.get("users/\(uid)"), let code = doc["code"] as? String {
                    me = Me(code: code, friends: doc["friends"] as? [String] ?? [], hidden: doc["hidden"] as? [String] ?? [])
                    if name.isEmpty, let n = doc["name"] as? String { defaults.set(n, forKey: Self.nameKey) }
                } else {
                    me = Me(code: try await createCode(uid: uid))
                }
                saveLocal()
            }
            try await upload(ctx: ctx, goals: goals, force: true)
            try await fetch()
        }
    }

    private func createCode(uid: String) async throws -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<5 {
            let code = String((0..<8).map { _ in alphabet.randomElement()! })
            do {
                try await FirebaseREST.create(collection: "codes", id: code, ["uid": uid])
                return code
            } catch FirebaseError.conflict { continue }
        }
        throw FirebaseError.server("Kein freier Code gefunden")
    }

    // MARK: Sync

    /// Writes my document if something changed (stats at most every 15 minutes unless forced).
    func upload(ctx: ModelContext, goals: Goals, force: Bool = false) async throws {
        guard isAvailable, let me, let uid, !name.isEmpty else { return }
        let stats = FriendStats.compute(ctx: ctx, goals: goals, shareWeight: defaults.bool(forKey: Self.shareWeightKey))
        let palette = defaults.string(forKey: "catPalette") ?? "ginger"
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        let payload = [name, palette, me.code, me.friends.joined(separator: ","), me.hidden.joined(separator: ","),
                       String(data: (try? enc.encode(stats)) ?? Data(), encoding: .utf8) ?? ""].joined(separator: "|")
        let hash = SHA256.hash(data: Data(payload.utf8)).map { String(format: "%02x", $0) }.joined()
        guard hash != lastUploadHash else { return }
        if !force, let last = lastUpload, Date.now.timeIntervalSince(last) < 15 * 60 { return }
        try await FirebaseREST.set("users/\(uid)", [
            "name": name, "palette": palette, "code": me.code, "friends": me.friends, "hidden": me.hidden,
            "stats": stats.dictionary, "updated": Date.now, "v": 1,
        ])
        lastUpload = .now
        lastUploadHash = hash
    }

    /// Background-friendly: upload changed stats, ignoring errors.
    func uploadIfNeeded(ctx: ModelContext, goals: Goals) {
        guard isSetUp else { return }
        Task { try? await upload(ctx: ctx, goals: goals) }
    }

    /// Everyone who added me – friends and open requests – in one query.
    private func fetch() async throws {
        guard let uid else { return }
        let docs = try await FirebaseREST.query(collection: "users", arrayField: "friends", contains: uid)
        people = docs.map { id, f in
            Person(id: id, name: f["name"] as? String ?? "?", palette: f["palette"] as? String ?? "ginger",
                   stats: FriendStats(f["stats"] as? [String: Any] ?? [:]), updated: f["updated"] as? Date)
        }
        lastRefresh = .now
        // Answered requests no longer need their label.
        if var m = me {
            let answered = Set(people.map(\.id))
            m.pendingLabels = m.pendingLabels.filter { !answered.contains($0.key) }
            me = m
        }
        saveLocal()
    }

    func refresh(ctx: ModelContext, goals: Goals, force: Bool = false) async {
        guard isSetUp else { return }
        if !force, let last = lastRefresh, Date.now.timeIntervalSince(last) < 3 * 60 {
            try? await upload(ctx: ctx, goals: goals)
            return
        }
        await run {
            try await upload(ctx: ctx, goals: goals)
            try await fetch()
        }
    }

    // MARK: Friend actions

    private func changeMe(ctx: ModelContext, goals: Goals, _ change: (inout Me) -> Void) async {
        guard var m = me else { return }
        change(&m)
        me = m
        saveLocal()
        await run { try await upload(ctx: ctx, goals: goals, force: true) }
    }

    /// Sends a request to the owner of an invite code.
    func addFriend(code raw: String, label: String? = nil, ctx: ModelContext, goals: Goals) async -> Bool {
        let code = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count == 8 else { error = "Ein Code hat 8 Zeichen."; return false }
        guard code != me?.code else { error = "Das ist dein eigener Code. 😺"; return false }
        var ok = false
        await run {
            let doc: [String: Any]
            do { doc = try await FirebaseREST.get("codes/\(code)") } catch FirebaseError.notFound {
                throw FirebaseError.server("Diesen Code gibt es nicht.")
            }
            guard let other = doc["uid"] as? String else { throw FirebaseError.notFound }
            guard var m = me, !m.friends.contains(other) else { ok = true; return }
            m.friends.append(other)
            m.hidden.removeAll { $0 == other }
            m.pendingLabels[other] = label ?? "Code \(code)"
            me = m
            saveLocal()
            try await upload(ctx: ctx, goals: goals, force: true)
            try await fetch()
            ok = true
        }
        return ok
    }

    func accept(_ id: String, ctx: ModelContext, goals: Goals) async {
        await changeMe(ctx: ctx, goals: goals) { m in
            if !m.friends.contains(id) { m.friends.append(id) }
            m.hidden.removeAll { $0 == id }
        }
    }

    func decline(_ id: String, ctx: ModelContext, goals: Goals) async {
        await changeMe(ctx: ctx, goals: goals) { m in
            m.friends.removeAll { $0 == id }
            if !m.hidden.contains(id) { m.hidden.append(id) }
            m.pendingLabels[id] = nil
        }
    }

    /// Removes a friend (or withdraws a request). They can no longer see my data.
    func remove(_ id: String, ctx: ModelContext, goals: Goals) async {
        await decline(id, ctx: ctx, goals: goals)
    }

    /// Deletes my document, my code and the anonymous account from this device.
    func deleteAll() async {
        await run {
            if let uid {
                try? await FirebaseREST.delete("users/\(uid)")
                if let code = me?.code { try? await FirebaseREST.delete("codes/\(code)") }
            }
            await FirebaseAuth.shared.deleteAccount()
        }
        FirebaseAuth.shared.signOut()
        me = nil
        people = []
        lastRefresh = nil
        lastUploadHash = ""
        lastUpload = nil
        for k in ["friends.me", "friends.cache", "friends.lastRefresh"] { defaults.removeObject(forKey: k) }
    }

    // MARK: Links

    /// purrtion://friend/ABCDEFGH?n=Name
    func handle(url: URL) -> Bool {
        guard url.scheme == "purrtion", url.host == "friend" else { return false }
        let code = url.lastPathComponent.uppercased().filter { $0.isLetter || $0.isNumber }
        guard code.count == 8 else { return false }
        let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "n" }?.value
        incomingCode = IncomingCode(code: code, name: name)
        return true
    }
}
