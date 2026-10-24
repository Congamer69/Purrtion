import Foundation
import CryptoKit
import CommonCrypto

/// Keeps the friends login (uid + refresh token) in a backup, encrypted with a password only you know.
///
/// The token gives access to your friends profile, so it is never written in plain text:
/// - key: PBKDF2-HMAC-SHA256 (210 000 rounds, random 16 byte salt) from the password (Unicode NFC)
/// - cipher: AES-256-GCM with a random 12 byte nonce, the label below as authenticated data
/// - stored as `p1:` + base64(salt ‖ nonce ‖ ciphertext ‖ tag), the same on iPhone and Android
/// The password is kept in the keychain on this device only, so daily backups can encrypt without asking. It is never part of a backup.
enum BackupVault {
    static let passwordKey = "backup.password"
    static let minimumLength = 8
    private static let prefix = "p1:"
    private static let rounds: UInt32 = 210_000
    private static let label = Data("purrtion-friends-v1".utf8)

    struct Account: Codable, Equatable {
        var uid: String
        var refresh: String
    }

    enum VaultError: LocalizedError {
        case wrongPassword
        var errorDescription: String? { "Das Passwort stimmt nicht." }
    }

    /// The password set on this device (nil = the friends login is not backed up).
    static var password: String? { Keychain.get(passwordKey).flatMap { $0.isEmpty ? nil : $0 } }

    static func setPassword(_ value: String?) { Keychain.set(passwordKey, value ?? "") }

    static func seal(_ account: Account, password: String) throws -> String {
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        guard status == errSecSuccess else { throw CocoaError(.coderInvalidValue) }
        let box = try AES.GCM.seal(try JSONEncoder().encode(account), using: key(password, salt: salt), authenticating: label)
        return prefix + (salt + box.combined!).base64EncodedString()
    }

    /// Throws `wrongPassword` for a wrong password or a changed file.
    static func open(_ text: String, password: String) throws -> Account {
        guard text.hasPrefix(prefix), let blob = Data(base64Encoded: String(text.dropFirst(prefix.count))), blob.count > 16 + 28 else {
            throw VaultError.wrongPassword
        }
        let salt = blob.prefix(16)
        do {
            let box = try AES.GCM.SealedBox(combined: blob.dropFirst(16))
            let plain = try AES.GCM.open(box, using: key(password, salt: Data(salt)), authenticating: label)
            return try JSONDecoder().decode(Account.self, from: plain)
        } catch { throw VaultError.wrongPassword }
    }

    private static func key(_ password: String, salt: Data) -> SymmetricKey {
        let pw = Array(password.precomposedStringWithCanonicalMapping.utf8)
        var out = [UInt8](repeating: 0, count: 32)
        pw.withUnsafeBufferPointer { p in
            salt.withUnsafeBytes { s in
                _ = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), UnsafeRawPointer(p.baseAddress!).assumingMemoryBound(to: Int8.self), pw.count,
                                         s.bindMemory(to: UInt8.self).baseAddress!, salt.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), rounds, &out, 32)
            }
        }
        return SymmetricKey(data: out)
    }
}
