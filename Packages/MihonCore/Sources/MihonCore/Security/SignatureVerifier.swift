import Foundation
import CryptoKit

public enum SignatureVerifier {
    public static func sha256(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    public static func verify(data: Data, expectedHash: String) -> Bool {
        sha256(of: data).lowercased() == expectedHash.lowercased()
    }
}
