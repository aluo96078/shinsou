import Foundation
import CryptoKit

// MARK: - OAuth Token Model

struct MALOAuth: Codable, Sendable {
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case tokenType    = "token_type"
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn    = "expires_in"
        case createdAt    = "created_at"
    }

    /// Returns true when the access token has expired (with a 60-second buffer).
    var isExpired: Bool {
        let expiryTime = createdAt + Int64(expiresIn) - 60
        return Int64(Date().timeIntervalSince1970) >= expiryTime
    }
}

// MARK: - PKCE Helper

enum PKCEHelper {
    /// Generates a cryptographically random code verifier (43–128 chars, URL-safe Base64).
    static func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Derives the code challenge from a code verifier using S256 (SHA-256).
    static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = SHA256.hash(data: data)
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
