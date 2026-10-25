import Foundation
import SwiftData

/// Backup on the server (Firestore), tied to the Google login. The JSON of `Backup` is compressed (raw deflate, same on
/// Android) and cut into parts of 700 KB (up to 10 MB in all). Two slots alternate, so a failed upload never damages the last backup:
/// the parts of the new slot are written first, then `backups/{uid}` points to them.
enum ServerBackup {
    static let partSize = 700_000
    static let maxParts = 15

    struct Meta: Equatable {
        var updated: Date
        var parts: Int
        var entries: Int
        var slot: String
        var device: String
    }

    struct Shrinks: Error { let local: Int; let remote: Int }

    enum BackupError: LocalizedError {
        case tooBig, incomplete, noAccount
        var errorDescription: String? {
            switch self {
            case .tooBig: "Das Backup ist größer als 10 MB und passt nicht auf den Server."
            case .incomplete: "Das Backup auf dem Server ist unvollständig."
            case .noAccount: "Melde dich zuerst mit Google an."
            }
        }
    }

    @MainActor private static var uid: String? { FirebaseAuth.shared.uid }

    @MainActor
    static func meta() async throws -> Meta? {
        guard let uid else { throw BackupError.noAccount }
        do {
            let d = try await FirebaseREST.get("backups/\(uid)")
            guard let parts = d["parts"] as? Double else { return nil }
            return Meta(updated: d["updated"] as? Date ?? .distantPast, parts: Int(parts), entries: Int(d["entries"] as? Double ?? 0),
                        slot: d["slot"] as? String ?? "a", device: d["device"] as? String ?? "")
        } catch FirebaseError.notFound {
            return nil
        }
    }

    @MainActor
    static func upload(_ ctx: ModelContext, force: Bool) async throws -> Meta {
        guard let uid else { throw BackupError.noAccount }
        let payload = try Backup.makePayload(ctx)
        let old = try await meta()
        // A fresh install must not replace a good backup with its almost empty data.
        if !force, let old, old.entries > 0, payload.entries.count < old.entries / 2 {
            throw Shrinks(local: payload.entries.count, remote: old.entries)
        }
        let packed = try (Backup.encode(payload) as NSData).compressed(using: .zlib) as Data
        let chunks = stride(from: 0, to: packed.count, by: partSize).map { packed.subdata(in: $0..<min($0 + partSize, packed.count)) }
        guard chunks.count <= maxParts else { throw BackupError.tooBig }
        let slot = old?.slot == "a" ? "b" : "a"
        for (i, chunk) in chunks.enumerated() {
            try await FirebaseREST.set("backups/\(uid)/parts/\(slot)\(i)", ["d": chunk])
        }
        let meta = Meta(updated: .now, parts: chunks.count, entries: payload.entries.count, slot: slot, device: "iOS")
        try await FirebaseREST.set("backups/\(uid)", [
            "updated": meta.updated, "parts": chunks.count, "entries": meta.entries, "size": packed.count,
            "slot": slot, "device": meta.device, "v": 1,
        ])
        if let old { for i in 0..<old.parts { try? await FirebaseREST.delete("backups/\(uid)/parts/\(old.slot)\(i)") } }
        return meta
    }

    @MainActor
    static func download() async throws -> Data {
        guard let uid else { throw BackupError.noAccount }
        guard let meta = try await meta() else { throw FirebaseError.notFound }
        var packed = Data()
        for i in 0..<meta.parts {
            guard let part = try await FirebaseREST.get("backups/\(uid)/parts/\(meta.slot)\(i)")["d"] as? Data else { throw BackupError.incomplete }
            packed.append(part)
        }
        return try (packed as NSData).decompressed(using: .zlib) as Data
    }

    @MainActor
    static func delete() async throws {
        guard let uid else { throw BackupError.noAccount }
        if let meta = try await meta() {
            for slot in ["a", "b"] { for i in 0..<max(meta.parts, maxParts) { try? await FirebaseREST.delete("backups/\(uid)/parts/\(slot)\(i)") } }
        }
        try await FirebaseREST.delete("backups/\(uid)")
    }
}
