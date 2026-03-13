import Foundation

@propertyWrapper
public struct Preference<Value> {
    private let key: String
    private let defaultValue: Value
    private let store: UserDefaults

    public init(key: String, defaultValue: Value, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.store = store
    }

    public var wrappedValue: Value {
        get { store.object(forKey: key) as? Value ?? defaultValue }
        set { store.set(newValue, forKey: key) }
    }
}

public final class AppPreferences: @unchecked Sendable {
    private let store: UserDefaults

    public init(store: UserDefaults = .standard) {
        self.store = store
    }

    // MARK: - General
    public var isIncognitoMode: Bool {
        get { store.bool(forKey: "incognito_mode") }
        set { store.set(newValue, forKey: "incognito_mode") }
    }

    public var isDownloadOnly: Bool {
        get { store.bool(forKey: "download_only") }
        set { store.set(newValue, forKey: "download_only") }
    }

    // MARK: - Library
    public var libraryDisplayMode: Int {
        get { store.integer(forKey: "library_display_mode") }
        set { store.set(newValue, forKey: "library_display_mode") }
    }

    public var libraryColumnsPortrait: Int {
        get { max(store.integer(forKey: "library_columns_portrait"), 0) }
        set { store.set(newValue, forKey: "library_columns_portrait") }
    }

    public var libraryColumnsLandscape: Int {
        get { max(store.integer(forKey: "library_columns_landscape"), 0) }
        set { store.set(newValue, forKey: "library_columns_landscape") }
    }

    // MARK: - Reader
    public var defaultReadingMode: Int {
        get { store.integer(forKey: "reader_default_mode") }
        set { store.set(newValue, forKey: "reader_default_mode") }
    }

    public var showPageNumber: Bool {
        get { store.object(forKey: "reader_show_page_number") as? Bool ?? true }
        set { store.set(newValue, forKey: "reader_show_page_number") }
    }

    public var keepScreenOn: Bool {
        get { store.object(forKey: "reader_keep_screen_on") as? Bool ?? true }
        set { store.set(newValue, forKey: "reader_keep_screen_on") }
    }

    public var fullscreen: Bool {
        get { store.object(forKey: "reader_fullscreen") as? Bool ?? true }
        set { store.set(newValue, forKey: "reader_fullscreen") }
    }

    // MARK: - Security
    public var useBiometricLock: Bool {
        get { store.bool(forKey: "security_biometric") }
        set { store.set(newValue, forKey: "security_biometric") }
    }

    // MARK: - Download
    public var downloadOnlyOnWifi: Bool {
        get { store.object(forKey: "download_wifi_only") as? Bool ?? true }
        set { store.set(newValue, forKey: "download_wifi_only") }
    }

    public var saveChaptersAsCBZ: Bool {
        get { store.bool(forKey: "download_save_cbz") }
        set { store.set(newValue, forKey: "download_save_cbz") }
    }

    // MARK: - Source
    public var showNsfwSource: Bool {
        get { store.bool(forKey: "source_show_nsfw") }
        set { store.set(newValue, forKey: "source_show_nsfw") }
    }

    public var enabledLanguages: Set<String> {
        get { Set(store.stringArray(forKey: "source_languages") ?? ["en"]) }
        set { store.set(Array(newValue), forKey: "source_languages") }
    }
}
