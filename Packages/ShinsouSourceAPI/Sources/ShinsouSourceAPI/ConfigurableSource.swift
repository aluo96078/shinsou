import Foundation

/// A source that provides configurable preferences.
public protocol ConfigurableSource: Source {
    /// Unique key for storing this source's preferences, typically the source ID.
    var preferenceKey: String { get }

    /// Returns the list of preference definitions for this source.
    func getPreferenceDefinitions() -> [SourcePreference]
}

public enum SourcePreference: Sendable {
    case textField(key: String, title: String, summary: String, defaultValue: String)
    case toggle(key: String, title: String, summary: String, defaultValue: Bool)
    case select(key: String, title: String, entries: [String], entryValues: [String], defaultValue: String)
    case multiSelect(key: String, title: String, entries: [String], entryValues: [String], defaultValues: Set<String>)
}
