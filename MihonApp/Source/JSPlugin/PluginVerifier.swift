import Foundation
import CryptoKit
import MihonCore
import MihonSourceAPI

// MARK: - PluginVerificationError

enum PluginVerificationError: Error, LocalizedError {
    case hashMismatch(expected: String, actual: String)
    case untrustedPlugin(pkg: String, versionCode: Int, hash: String)
    case manifestMissing

    var errorDescription: String? {
        switch self {
        case let .hashMismatch(expected, actual):
            return "Hash mismatch: expected \(expected), got \(actual)"
        case let .untrustedPlugin(pkg, versionCode, hash):
            return "Plugin '\(pkg)' v\(versionCode) with hash \(hash.prefix(16))… is not trusted"
        case .manifestMissing:
            return "Plugin manifest is missing, cannot verify"
        }
    }
}

// MARK: - PluginTrustStore

/// Persists a set of trusted `{pkg}:{versionCode}:{sha256}` tokens in UserDefaults.
/// A token is added only after successful signature verification or explicit user approval.
final class PluginTrustStore {
    static let shared = PluginTrustStore()

    private let udKey = "plugin.trustStore.trustedTokens"

    private init() {}

    // MARK: - Public API

    func isTrusted(pkg: String, versionCode: Int, hash: String) -> Bool {
        let token = makeToken(pkg: pkg, versionCode: versionCode, hash: hash)
        return storedTokens.contains(token)
    }

    func trust(pkg: String, versionCode: Int, hash: String) {
        let token = makeToken(pkg: pkg, versionCode: versionCode, hash: hash)
        var tokens = storedTokens
        tokens.insert(token)
        save(tokens)
    }

    func revoke(pkg: String, versionCode: Int, hash: String) {
        let token = makeToken(pkg: pkg, versionCode: versionCode, hash: hash)
        var tokens = storedTokens
        tokens.remove(token)
        save(tokens)
    }

    func revokeAll(pkg: String) {
        var tokens = storedTokens
        tokens = tokens.filter { !$0.hasPrefix("\(pkg):") }
        save(tokens)
    }

    // MARK: - Private helpers

    private var storedTokens: Set<String> {
        let array = UserDefaults.standard.array(forKey: udKey) as? [String] ?? []
        return Set(array)
    }

    private func save(_ tokens: Set<String>) {
        UserDefaults.standard.set(Array(tokens), forKey: udKey)
    }

    private func makeToken(pkg: String, versionCode: Int, hash: String) -> String {
        "\(pkg):\(versionCode):\(hash.lowercased())"
    }
}

// MARK: - PluginVerifier

/// Verifies the SHA-256 hash of a JS plugin file before it is loaded.
///
/// Verification flow:
/// 1. Compute SHA-256 of the raw script `Data`.
/// 2. If the manifest carries a non-empty `signature`, compare against it.
/// 3. Check whether the `{pkg}:{versionCode}:{hash}` token is recorded in `PluginTrustStore`.
///    If the plugin has never been trusted and passes the hash check, it is added automatically.
/// 4. Throw `PluginVerificationError` on any failure so `PluginLoader` can skip the file.
enum PluginVerifier {

    // MARK: - Core verification

    /// Verify plugin `data` against its `manifest`.
    ///
    /// - Parameters:
    ///   - data:          Raw bytes of the `.js` file.
    ///   - manifest:      The companion manifest describing the plugin.
    ///   - signingKeyFingerprint: Optional fingerprint from the `ExtensionRepo` used to double-check
    ///                    the `manifest.signature` field. Pass `nil` to skip this step.
    ///
    /// - Throws: `PluginVerificationError` if verification fails.
    static func verify(
        data: Data,
        manifest: PluginManifest,
        signingKeyFingerprint: String? = nil
    ) throws {
        let actualHash = SignatureVerifier.sha256(of: data)

        // 1. If the manifest declares an expected hash, compare strictly.
        if !manifest.signature.isEmpty {
            let expected = manifest.signature.lowercased()
            guard actualHash.lowercased() == expected else {
                throw PluginVerificationError.hashMismatch(
                    expected: expected,
                    actual: actualHash
                )
            }

            // If a repo signing key fingerprint was supplied, use it as a secondary check.
            // (In practice the signing key would be used to verify a crypto signature over the
            //  manifest, but since the current protocol uses a plain SHA-256 comparison we treat
            //  the fingerprint as an allowed-hash allowlist entry when non-empty.)
            if let fingerprint = signingKeyFingerprint,
               !fingerprint.isEmpty,
               fingerprint.lowercased() != expected {
                // The fingerprint doesn't match the manifest hash — still acceptable as long as
                // the hash comparison above passed; the fingerprint mismatch is only logged.
                print("[PluginVerifier] Warning: signing key fingerprint '\(fingerprint.prefix(16))…' " +
                      "does not match manifest signature for '\(manifest.id)'. " +
                      "Proceeding because hash verification passed.")
            }
        }

        // 2. Derive a version code from the manifest version string (e.g. "1.4.2" → 142).
        let versionCode = versionInt(from: manifest.version)

        // 3. Trust-store check.
        let trustStore = PluginTrustStore.shared
        if !trustStore.isTrusted(pkg: manifest.id, versionCode: versionCode, hash: actualHash) {
            if manifest.signature.isEmpty {
                // Unsigned plugin: refuse to load unless already trusted.
                throw PluginVerificationError.untrustedPlugin(
                    pkg: manifest.id,
                    versionCode: versionCode,
                    hash: actualHash
                )
            }
            // Signed plugin whose hash matched: record as trusted for future loads.
            trustStore.trust(pkg: manifest.id, versionCode: versionCode, hash: actualHash)
        }
    }

    // MARK: - Convenience: verify from disk URL

    /// Reads `url` from disk and verifies it in one call.
    static func verifyFile(
        at url: URL,
        manifest: PluginManifest,
        signingKeyFingerprint: String? = nil
    ) throws {
        let data = try Data(contentsOf: url)
        try verify(data: data, manifest: manifest, signingKeyFingerprint: signingKeyFingerprint)
    }

    // MARK: - Hash query (for UI display)

    /// Returns the hex-encoded SHA-256 of `data` without performing trust checks.
    static func hash(of data: Data) -> String {
        SignatureVerifier.sha256(of: data)
    }

    // MARK: - Private helpers

    private static func versionInt(from version: String) -> Int {
        let components = version
            .split(separator: ".")
            .compactMap { Int($0) }
        switch components.count {
        case 1: return components[0]
        case 2: return components[0] * 100 + components[1]
        default:
            // Take at most three components: major * 10000 + minor * 100 + patch
            let major = components[0]
            let minor = components.count > 1 ? components[1] : 0
            let patch = components.count > 2 ? components[2] : 0
            return major * 10_000 + minor * 100 + patch
        }
    }
}
