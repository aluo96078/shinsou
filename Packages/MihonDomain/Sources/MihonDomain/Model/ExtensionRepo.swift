import Foundation

public struct ExtensionRepo: Sendable, Equatable, Identifiable {
    public var id: String { baseUrl }

    public let baseUrl: String
    public let name: String
    public let shortName: String?
    public let website: String
    public let signingKeyFingerprint: String

    public init(
        baseUrl: String, name: String, shortName: String? = nil,
        website: String = "", signingKeyFingerprint: String = ""
    ) {
        self.baseUrl = baseUrl
        self.name = name
        self.shortName = shortName
        self.website = website
        self.signingKeyFingerprint = signingKeyFingerprint
    }
}
