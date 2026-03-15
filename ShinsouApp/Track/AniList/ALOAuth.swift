import Foundation

struct ALOAuth: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int64
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType   = "token_type"
        case expiresIn   = "expires_in"
        case createdAt   = "created_at"
    }

    /// Returns true when the token's lifetime has elapsed.
    var isExpired: Bool {
        let expiresAt = createdAt + expiresIn
        return Int64(Date().timeIntervalSince1970) >= expiresAt
    }
}
