import Foundation

/// Manifest for a JavaScript-based source plugin.
public struct PluginManifest: Codable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let versionCode: Int?
    public let lang: String
    public let nsfw: Bool
    public let script: String
    public let signature: String
    public let minRuntimeVersion: String?
    public let sources: [SourceIndexEntry]?

    public init(
        id: String,
        name: String,
        version: String,
        versionCode: Int? = nil,
        lang: String,
        nsfw: Bool = false,
        script: String,
        signature: String,
        minRuntimeVersion: String? = nil,
        sources: [SourceIndexEntry]? = nil
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.versionCode = versionCode
        self.lang = lang
        self.nsfw = nsfw
        self.script = script
        self.signature = signature
        self.minRuntimeVersion = minRuntimeVersion
        self.sources = sources
    }
}

/// Extension index entry from a repository's index.min.json (legacy Android format)
public struct ExtensionIndexEntry: Codable, Sendable {
    public let name: String
    public let pkg: String
    public let apk: String
    public let lang: String
    public let code: Int
    public let version: String
    public let nsfw: Int
    public let sources: [SourceIndexEntry]?
}

/// Plugin index entry from a community repo's index.json.
/// Each entry points to a downloadable JS crawler script.
public struct PluginIndexEntry: Codable, Sendable {
    public let id: String           // e.g. "en.mangadex"
    public let name: String
    public let version: String
    public let versionCode: Int
    public let lang: String
    public let nsfw: Int            // 0 or 1
    public let scriptUrl: String    // relative path to .js file, e.g. "plugins/en.mangadex.js"
    public let iconUrl: String?     // relative path to icon
    public let description: String? // plugin description
    public let sources: [SourceIndexEntry]?
}

public struct SourceIndexEntry: Codable, Sendable, Equatable {
    public let name: String
    public let lang: String
    public let id: Int64
    public let baseUrl: String?

    // Keiyoushi index.min.json encodes `id` as a JSON string, not a number.
    // Custom decoder handles both cases.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        lang = try container.decode(String.self, forKey: .lang)
        baseUrl = try container.decodeIfPresent(String.self, forKey: .baseUrl)
        if let intId = try? container.decode(Int64.self, forKey: .id) {
            id = intId
        } else {
            let strId = try container.decode(String.self, forKey: .id)
            guard let parsed = Int64(strId) else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Cannot parse id '\(strId)' as Int64")
            }
            id = parsed
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, lang, id, baseUrl
    }

    public init(name: String, lang: String, id: Int64, baseUrl: String?) {
        self.name = name
        self.lang = lang
        self.id = id
        self.baseUrl = baseUrl
    }
}
