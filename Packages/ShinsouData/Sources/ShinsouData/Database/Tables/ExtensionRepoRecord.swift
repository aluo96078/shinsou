import Foundation
import GRDB
import ShinsouDomain

public struct ExtensionRepoRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "extension_repo"

    public var baseUrl: String  // Primary Key
    public var name: String
    public var shortName: String?
    public var website: String
    public var signingKeyFingerprint: String

    enum CodingKeys: String, CodingKey {
        case baseUrl = "base_url"
        case name
        case shortName = "short_name"
        case website
        case signingKeyFingerprint = "signing_key_fingerprint"
    }

    public func toDomain() -> ExtensionRepo {
        ExtensionRepo(
            baseUrl: baseUrl,
            name: name,
            shortName: shortName,
            website: website,
            signingKeyFingerprint: signingKeyFingerprint
        )
    }

    public static func from(domain: ExtensionRepo) -> ExtensionRepoRecord {
        ExtensionRepoRecord(
            baseUrl: domain.baseUrl,
            name: domain.name,
            shortName: domain.shortName,
            website: domain.website,
            signingKeyFingerprint: domain.signingKeyFingerprint
        )
    }
}
