import Foundation

/// Tiny Firebase client over REST (no SDK): anonymous Auth + the few Firestore calls the friends page needs.
/// Configuration comes from `Firebase.plist` (not in git) – without it the friends page stays hidden.
/// Server of the friends page and the server backup: the Firebase.plist built into the app. Server codes pasted by older
/// versions are still read, so a build without a plist keeps working for them.
enum FirebaseConfig {
    static let storageKey = "friends.server"
    private static let prefix = "purrtion-server:"
    /// Stored after "Freunde-Server trennen", so a built-in config does not reconnect by itself.
    private static let off = "off"

    struct Server: Codable, Equatable {
        var k: String
        var p: String
        var i: String = ""
        var isValid: Bool { k.count > 20 && !k.hasPrefix("<") && !p.isEmpty }
    }

    private static let bundled: Server? = {
        guard let url = Bundle.main.url(forResource: "Firebase", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let d = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return nil }
        let s = Server(k: d["APIKey"] as? String ?? "", p: d["ProjectID"] as? String ?? "", i: d["InviteURL"] as? String ?? "")
        return s.isValid ? s : nil
    }()

    private static var raw: String? { UserDefaults.standard.string(forKey: storageKey) }
    private static var stored: Server? { raw.flatMap(decode) }

    /// The built-in server (the public builds carry it); a server stored by an older version is only used without one.
    static var server: Server? { bundled ?? (raw == off ? nil : stored) }
    static var apiKey: String? { server?.k }
    static var projectID: String? { server?.p }
    static var inviteURL: String { server?.i ?? "" }
    static var isAvailable: Bool { server?.isValid == true }
    /// Same, for views that observe the stored value (`@AppStorage(storageKey)`) so they re-render when it changes.
    static func isAvailable(_ observed: String) -> Bool { isAvailable }
    static func encode(_ s: Server) -> String {
        let data = (try? JSONEncoder().encode(s)) ?? Data()
        return prefix + data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Reads a pasted code; whitespace, line breaks and quotes from chats are ignored.
    static func decode(_ raw: String) -> Server? {
        let t = raw.filter { !$0.isWhitespace }.trimmingCharacters(in: CharacterSet(charactersIn: "\"'„“”"))
        guard t.hasPrefix(prefix) else { return nil }
        var b = String(t.dropFirst(prefix.count)).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b.count % 4 != 0 { b += "=" }
        guard let data = Data(base64Encoded: b), let s = try? JSONDecoder().decode(Server.self, from: data), s.isValid else { return nil }
        return s
    }
}

enum FirebaseError: LocalizedError {
    case notConfigured, offline, notFound, conflict, denied, server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Die Freunde-Funktion ist in diesem Build nicht eingerichtet."
        case .offline: "Keine Verbindung. Versuch es gleich nochmal."
        case .notFound: "Nicht gefunden."
        case .conflict: "Existiert schon."
        case .denied: "Keine Berechtigung."
        case .server(let m): "Serverfehler: \(m)"
        }
    }
}

/// Anonymous account: the refresh token lives in the keychain (survives reinstalls), the ID token in memory.
@MainActor
final class FirebaseAuth {
    static let shared = FirebaseAuth()
    private var idToken: String?
    private var expires = Date.distantPast

    var uid: String? { Keychain.get("fb.uid") }
    var hasAccount: Bool { uid != nil && Keychain.get("fb.refresh") != nil }

    func token() async throws -> String {
        if let idToken, expires > .now.addingTimeInterval(60) { return idToken }
        guard let key = FirebaseConfig.apiKey else { throw FirebaseError.notConfigured }
        if let refresh = Keychain.get("fb.refresh") {
            var req = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(key)")!)
            req.httpMethod = "POST"
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.httpBody = "grant_type=refresh_token&refresh_token=\(refresh)".data(using: .utf8)
            let json = try await FirebaseREST.send(req)
            if let t = json["id_token"] as? String {
                store(token: t, refresh: json["refresh_token"] as? String, uid: json["user_id"] as? String,
                      expiresIn: json["expires_in"] as? String)
                return t
            }
        }
        // New anonymous account.
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(key)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["returnSecureToken": true])
        let json = try await FirebaseREST.send(req)
        guard let t = json["idToken"] as? String else { throw FirebaseError.server("Anmeldung fehlgeschlagen") }
        store(token: t, refresh: json["refreshToken"] as? String, uid: json["localId"] as? String,
              expiresIn: json["expiresIn"] as? String)
        return t
    }

    private func store(token: String, refresh: String?, uid: String?, expiresIn: String?) {
        idToken = token
        expires = .now.addingTimeInterval(Double(expiresIn ?? "3600") ?? 3600)
        if let refresh { Keychain.set("fb.refresh", refresh) }
        if let uid { Keychain.set("fb.uid", uid) }
    }

    /// Deletes the anonymous account itself (before signing out).
    func deleteAccount() async {
        guard let key = FirebaseConfig.apiKey, let token = try? await token() else { return }
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=\(key)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["idToken": token])
        _ = try? await FirebaseREST.send(req)
    }

    /// Signs in with a Google ID token. With `link`, the current (anonymous) account gets the Google login and keeps
    /// its uid. Throws `.server("FEDERATED_USER_ID_ALREADY_LINKED")` when that Google account belongs to another uid.
    func googleSignIn(googleIDToken: String, link: Bool) async throws -> GoogleResult {
        guard let key = FirebaseConfig.apiKey else { throw FirebaseError.notConfigured }
        var body: [String: Any] = ["requestUri": "http://localhost", "postBody": "id_token=\(googleIDToken)&providerId=google.com",
                                   "returnSecureToken": true, "returnIdpCredential": true]
        if link, let current = try? await token() { body["idToken"] = current }
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(key)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let json = try await FirebaseREST.send(req)
        // Linking keeps the refresh token valid, so a reply without a new one is fine in that case.
        guard let t = json["idToken"] as? String, let uid = json["localId"] as? String,
              let refresh = (json["refreshToken"] as? String) ?? (link ? Keychain.get("fb.refresh") : nil) else {
            let detail = (json["errorMessage"] as? String) ?? (json["needConfirmation"] as? Bool == true ? "needConfirmation" : json.keys.sorted().joined(separator: ","))
            throw FirebaseError.server("Anmeldung fehlgeschlagen (\(detail))")
        }
        return GoogleResult(idToken: t, refresh: refresh, uid: uid, email: json["email"] as? String ?? "", expiresIn: json["expiresIn"] as? String)
    }

    struct GoogleResult { let idToken: String; let refresh: String; let uid: String; let email: String; let expiresIn: String? }

    /// Makes a signed-in result the current account.
    func use(_ r: GoogleResult) {
        store(token: r.idToken, refresh: r.refresh, uid: r.uid, expiresIn: r.expiresIn)
    }

    /// Takes over an account from a backup: the next request refreshes its token.
    func adopt(uid: String, refresh: String) {
        idToken = nil
        expires = .distantPast
        Keychain.set("fb.uid", uid)
        Keychain.set("fb.refresh", refresh)
    }

    func signOut() {
        idToken = nil
        expires = .distantPast
        Keychain.set("fb.refresh", "")
        Keychain.set("fb.uid", "")
    }
}

/// Firestore REST calls with plain Swift values (String, Double, Int, Bool, Date, arrays, dictionaries).
@MainActor
enum FirebaseREST {
    private static var base: String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID ?? "")/databases/(default)/documents"
    }

    static func send(_ req: URLRequest) async throws -> [String: Any] {
        let any = try await sendAny(req)
        return any as? [String: Any] ?? [:]
    }

    static func sendAny(_ req: URLRequest) async throws -> Any {
        var req = req
        req.timeoutInterval = 20
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: req) } catch {
            if (error as? URLError)?.code == .cancelled || error is CancellationError { throw CancellationError() }
            throw FirebaseError.offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) ?? [:]
        switch status {
        case 200..<300: return json
        case 404: throw FirebaseError.notFound
        case 409: throw FirebaseError.conflict
        case 401, 403: throw FirebaseError.denied
        default:
            let msg = ((json as? [String: Any])?["error"] as? [String: Any])?["message"] as? String ?? "HTTP \(status)"
            throw FirebaseError.server(msg)
        }
    }

    private static func request(_ path: String, method: String, body: Any? = nil) async throws -> Any {
        let token = try await FirebaseAuth.shared.token()
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await sendAny(req)
    }

    // MARK: Documents

    static func get(_ path: String) async throws -> [String: Any] {
        let doc = try await request("/" + path, method: "GET") as? [String: Any] ?? [:]
        return decodeFields(doc["fields"] as? [String: Any] ?? [:])
    }

    /// Replaces the whole document (creates it if missing).
    static func set(_ path: String, _ fields: [String: Any]) async throws {
        _ = try await request("/" + path, method: "PATCH", body: ["fields": encodeFields(fields)])
    }

    /// Creates a document with a fixed id; throws `.conflict` when it exists.
    static func create(collection: String, id: String, _ fields: [String: Any]) async throws {
        _ = try await request("/\(collection)?documentId=\(id)", method: "POST", body: ["fields": encodeFields(fields)])
    }

    static func delete(_ path: String) async throws {
        _ = try await request("/" + path, method: "DELETE")
    }

    /// All documents of `collection` whose array `field` contains `value` – one request for any number of documents.
    static func query(collection: String, arrayField field: String, contains value: String, limit: Int = 100) async throws -> [(id: String, fields: [String: Any])] {
        let body: [String: Any] = ["structuredQuery": [
            "from": [["collectionId": collection]],
            "where": ["fieldFilter": ["field": ["fieldPath": field], "op": "ARRAY_CONTAINS", "value": ["stringValue": value]]],
            "limit": limit,
        ]]
        let rows = try await request(":runQuery", method: "POST", body: body) as? [[String: Any]] ?? []
        return rows.compactMap { row in
            guard let doc = row["document"] as? [String: Any], let name = doc["name"] as? String else { return nil }
            return (String(name.split(separator: "/").last ?? ""), decodeFields(doc["fields"] as? [String: Any] ?? [:]))
        }
    }

    // MARK: Value conversion

    static func encodeFields(_ dict: [String: Any]) -> [String: Any] { dict.mapValues(encode) }

    static func encode(_ v: Any) -> [String: Any] {
        switch v {
        case let s as String: return ["stringValue": s]
        case let d as Data: return ["bytesValue": d.base64EncodedString()]
        case let b as Bool: return ["booleanValue": b]
        case let i as Int: return ["integerValue": String(i)]
        case let d as Double: return d.isFinite ? ["doubleValue": d] : ["nullValue": NSNull()]
        case let n as NSNumber: return ["doubleValue": n.doubleValue]
        case let date as Date: return ["timestampValue": ISO8601DateFormatter().string(from: date)]
        case let a as [Any]: return ["arrayValue": ["values": a.map(encode)]]
        case let m as [String: Any]: return ["mapValue": ["fields": m.mapValues(encode)]]
        default: return ["nullValue": NSNull()]
        }
    }

    static func decodeFields(_ fields: [String: Any]) -> [String: Any] {
        fields.compactMapValues { decode($0 as? [String: Any] ?? [:]) }
    }

    static func decode(_ v: [String: Any]) -> Any? {
        if let s = v["stringValue"] as? String { return s }
        if let b64 = v["bytesValue"] as? String { return Data(base64Encoded: b64) }
        if let b = v["booleanValue"] as? Bool { return b }
        if let i = v["integerValue"] as? String { return Double(i) }
        if let d = v["doubleValue"] as? Double { return d }
        if let d = v["doubleValue"] as? NSNumber { return d.doubleValue }
        if let t = v["timestampValue"] as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: t) ?? ISO8601DateFormatter().date(from: t)
        }
        if let a = v["arrayValue"] as? [String: Any] {
            return (a["values"] as? [[String: Any]] ?? []).compactMap(decode)
        }
        if let m = v["mapValue"] as? [String: Any] { return decodeFields(m["fields"] as? [String: Any] ?? [:]) }
        return nil
    }
}
