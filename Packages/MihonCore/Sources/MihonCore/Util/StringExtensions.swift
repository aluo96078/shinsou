import Foundation
import CryptoKit

public extension String {
    var md5Hash: String {
        let data = Data(self.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    var sha256Hash: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func chapterNumber() -> Double {
        let pattern = #"([0-9]+)(\.[0-9]+)?"#
        guard let range = self.range(of: pattern, options: .regularExpression) else {
            return -1
        }
        return Double(self[range]) ?? -1
    }
}
