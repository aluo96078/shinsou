import Foundation

// MARK: - Language Manager

/// Manages the current app language and provides localized bundle lookup.
/// Supports runtime language switching without app restart.
public final class LanguageManager: @unchecked Sendable {
    public static let shared = LanguageManager()

    /// Posted when the language changes so SwiftUI views can refresh.
    public static let languageDidChangeNotification = Notification.Name("ShinsouLanguageDidChange")

    /// The language code currently in effect ("en", "ja", "zh-Hant", etc.).
    /// Set to "system" or nil to follow the device locale.
    public var currentLanguage: String? {
        didSet {
            _bundle = nil // invalidate cache
            NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
        }
    }

    /// Resolved bundle for the current language.
    public var bundle: Bundle {
        if let cached = _bundle { return cached }
        let resolved = resolveBundle()
        _bundle = resolved
        return resolved
    }

    private var _bundle: Bundle?
    private let moduleBundle: Bundle = .module

    private init() {}

    private func resolveBundle() -> Bundle {
        guard let lang = currentLanguage, lang != "system" else {
            return moduleBundle // follow system locale
        }

        // Try exact match first (e.g. "zh-Hant"), then base language (e.g. "zh")
        let candidates = [lang, String(lang.prefix(2))]
        for candidate in candidates {
            if let path = moduleBundle.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return moduleBundle
    }
}

// MARK: - Localized string helper

private func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: LanguageManager.shared.bundle, comment: "")
}

// MARK: - MR (Shinsou Resources)

public enum MR {
    public enum strings {
        // MARK: - Tabs
        public static var tabLibrary: String { L("tab_library") }
        public static var tabUpdates: String { L("tab_updates") }
        public static var tabHistory: String { L("tab_history") }
        public static var tabBrowse: String { L("tab_browse") }
        public static var tabMore: String { L("tab_more") }

        // MARK: - Common Actions
        public static var actionOk: String { L("action_ok") }
        public static var actionCancel: String { L("action_cancel") }
        public static var actionDelete: String { L("action_delete") }
        public static var actionEdit: String { L("action_edit") }
        public static var actionSearch: String { L("action_search") }
        public static var actionFilter: String { L("action_filter") }
        public static var actionSort: String { L("action_sort") }
        public static var actionDownload: String { L("action_download") }
        public static var actionShare: String { L("action_share") }

        // MARK: - Library
        public static var libraryEmpty: String { L("library_empty") }

        // MARK: - Reader
        public static var readerModePagerLtr: String { L("reader_mode_pager_ltr") }
        public static var readerModePagerRtl: String { L("reader_mode_pager_rtl") }
        public static var readerModePagerVertical: String { L("reader_mode_pager_vertical") }
        public static var readerModeWebtoon: String { L("reader_mode_webtoon") }
        public static var readerModeContinuousVertical: String { L("reader_mode_continuous_vertical") }

        // MARK: - Settings
        public static var settingsGeneral: String { L("settings_general") }
        public static var settingsAppearance: String { L("settings_appearance") }
        public static var settingsLibrary: String { L("settings_library") }
        public static var settingsReader: String { L("settings_reader") }
        public static var settingsDownloads: String { L("settings_downloads") }
        public static var settingsBrowse: String { L("settings_browse") }
        public static var settingsTracking: String { L("settings_tracking") }
        public static var settingsSecurity: String { L("settings_security") }
        public static var settingsData: String { L("settings_data") }
        public static var settingsAdvanced: String { L("settings_advanced") }
        public static var settingsAbout: String { L("settings_about") }
        public static var settingsBackup: String { L("settings_backup") }
        public static var settingsSync: String { L("settings_sync") }
        public static var settingsTitle: String { L("settings_title") }

        // MARK: - More Screen
        public static var moreTitle: String { L("more_title") }
        public static var moreIncognitoMode: String { L("more_incognito_mode") }
        public static var moreIncognitoDesc: String { L("more_incognito_desc") }
        public static var moreIncognitoActive: String { L("more_incognito_active") }
        public static var moreDownloadOnly: String { L("more_download_only") }
        public static var moreDownloadOnlyDesc: String { L("more_download_only_desc") }
        public static var moreDownloadOnlyActive: String { L("more_download_only_active") }
        public static var moreDownloadQueue: String { L("more_download_queue") }
        public static var moreStatistics: String { L("more_statistics") }
        public static var moreSectionContent: String { L("more_section_content") }
        public static var moreSectionApp: String { L("more_section_app") }

        // MARK: - General Settings
        public static var generalLanguage: String { L("general_language") }
        public static var generalDisplay: String { L("general_display") }
        public static var generalDateFormat: String { L("general_date_format") }
        public static var generalNavigation: String { L("general_navigation") }
        public static var generalDefaultScreen: String { L("general_default_screen") }
        public static var generalBehaviour: String { L("general_behaviour") }
        public static var generalConfirmClose: String { L("general_confirm_close") }
        public static var generalConfirmCloseDesc: String { L("general_confirm_close_desc") }

        // MARK: - Library
        public static var librarySettings: String { L("library_settings") }
        public static var libraryFilter: String { L("library_filter") }
        public static var librarySort: String { L("library_sort") }
        public static var libraryDisplay: String { L("library_display") }
        public static var libraryDownloaded: String { L("library_downloaded") }
        public static var libraryUnread: String { L("library_unread") }
        public static var libraryStarted: String { L("library_started") }
        public static var libraryBookmarked: String { L("library_bookmarked") }
        public static var libraryCompleted: String { L("library_completed") }
        public static var libraryTracking: String { L("library_tracking") }
        public static var libraryReshuffle: String { L("library_reshuffle") }
        public static var libraryDisplayMode: String { L("library_display_mode") }
        public static var libraryCompactGrid: String { L("library_compact_grid") }
        public static var libraryComfortableGrid: String { L("library_comfortable_grid") }
        public static var libraryCoverOnlyGrid: String { L("library_cover_only_grid") }
        public static var libraryList: String { L("library_list") }
        public static var libraryBadges: String { L("library_badges") }
        public static var libraryUnreadCount: String { L("library_unread_count") }
        public static var libraryDownloadCount: String { L("library_download_count") }
        public static var libraryLocalSource: String { L("library_local_source") }
        public static var libraryCategoryTabs: String { L("library_category_tabs") }
        public static var libraryShowCategoryTabs: String { L("library_show_category_tabs") }
        public static var libraryShowMangaCount: String { L("library_show_manga_count") }
        public static var libraryManageCategories: String { L("library_manage_categories") }
        public static var libraryCategoryName: String { L("library_category_name") }
        public static var libraryNewCategory: String { L("library_new_category") }
        public static var libraryEnterCategoryName: String { L("library_enter_category_name") }
        public static var libraryRenameCategory: String { L("library_rename_category") }
        public static var libraryNewName: String { L("library_new_name") }
        public static var libraryNoCategories: String { L("library_no_categories") }
        public static var libraryNoCategoriesDesc: String { L("library_no_categories_desc") }
        public static var libraryResumeReading: String { L("library_resume_reading") }
        public static var libraryReadFromStart: String { L("library_read_from_start") }
        public static var libraryMoveToCategory: String { L("library_move_to_category") }
        public static var libraryRemoveFromLibrary: String { L("library_remove_from_library") }
        public static var libraryMarkAllRead: String { L("library_mark_all_read") }
        public static var libraryMarkAllUnread: String { L("library_mark_all_unread") }

        // MARK: - History
        public static var historyTitle: String { L("history_title") }
        public static var historyNoHistory: String { L("history_no_history") }
        public static var historySearch: String { L("history_search") }
        public static var historyClearAll: String { L("history_clear_all") }
        public static var historyRemove: String { L("history_remove") }

        // MARK: - Browse
        public static var browseSources: String { L("browse_sources") }
        public static var browseExtensions: String { L("browse_extensions") }
        public static var browseMigration: String { L("browse_migration") }
        public static var browseGlobalSearch: String { L("browse_global_search") }
        public static var browsePopular: String { L("browse_popular") }
        public static var browseLatest: String { L("browse_latest") }
        public static var browseNoResults: String { L("browse_no_results") }
        public static var browseSearchAll: String { L("browse_search_all") }
        public static var browseSearchAcross: String { L("browse_search_across") }
        public static var browsePreferences: String { L("browse_preferences") }
        public static var browseEnableAll: String { L("browse_enable_all") }
        public static var browseShowAllReset: String { L("browse_show_all_reset") }
        public static var browseFilterLanguages: String { L("browse_filter_languages") }
        public static var browseLanguages: String { L("browse_languages") }
        public static var browseInstalled: String { L("browse_installed") }
        public static var browseAvailable: String { L("browse_available") }
        public static var browseNoExtensions: String { L("browse_no_extensions") }
        public static var browseRepositories: String { L("browse_repositories") }
        public static var browseAddRepository: String { L("browse_add_repository") }
        public static var browseRepositoryUrl: String { L("browse_repository_url") }
        public static var browseUninstall: String { L("browse_uninstall") }
        public static var browseClearCookies: String { L("browse_clear_cookies") }
        public static var browseClear: String { L("browse_clear") }
        public static var browseUninstallConfirm: String { L("browse_uninstall_confirm") }
        public static var browseCookiesConfirm: String { L("browse_cookies_confirm") }
        public static var browseUninstallFailed: String { L("browse_uninstall_failed") }
        public static var browseUnknownError: String { L("browse_unknown_error") }
        public static var browseCheckUpdates: String { L("browse_check_updates") }
        public static var browseCheckUpdatesDesc: String { L("browse_check_updates_desc") }
        public static var browseShowNsfw: String { L("browse_show_nsfw") }
        public static var browseShowNsfwDesc: String { L("browse_show_nsfw_desc") }
        public static var browseNsfwWarning: String { L("browse_nsfw_warning") }
        public static var browseNoCustomRepos: String { L("browse_no_custom_repos") }
        public static var browseRepoFooter: String { L("browse_repo_footer") }
        public static var browseInvalidUrl: String { L("browse_invalid_url") }
        public static var browseRepoExists: String { L("browse_repo_exists") }
        public static var browseHasUpdate: String { L("browse_has_update") }
        public static var browseInstallAction: String { L("browse_install_action") }
        public static var browseUpdateAction: String { L("browse_update_action") }
        public static var browseUpdateAll: String { L("browse_update_all") }

        // MARK: - Manga
        public static var mangaInLibrary: String { L("manga_in_library") }
        public static var mangaAddToLibrary: String { L("manga_add_to_library") }
        public static var mangaTracking: String { L("manga_tracking") }
        public static var mangaWebview: String { L("manga_webview") }
        public static var mangaNotes: String { L("manga_notes") }
        public static var mangaEditNotes: String { L("manga_edit_notes") }
        public static var mangaMarkDuplicatesRead: String { L("manga_mark_duplicates_read") }
        public static var mangaRead: String { L("manga_read") }
        public static var mangaUnread: String { L("manga_unread") }
        public static var mangaBookmark: String { L("manga_bookmark") }
        public static var mangaSaveToPhotos: String { L("manga_save_to_photos") }
        public static var mangaSetCustomCover: String { L("manga_set_custom_cover") }
        public static var mangaCoverImage: String { L("manga_cover_image") }
        public static var mangaCoverNotLoaded: String { L("manga_cover_not_loaded") }
        public static var mangaCoverSaved: String { L("manga_cover_saved") }
        public static var mangaPhotosDenied: String { L("manga_photos_denied") }
        public static var mangaCustomCoverSaved: String { L("manga_custom_cover_saved") }
        public static var mangaEncodeFailed: String { L("manga_encode_failed") }
        public static var mangaStatusOngoing: String { L("manga_status_ongoing") }
        public static var mangaStatusCompleted: String { L("manga_status_completed") }
        public static var mangaStatusLicensed: String { L("manga_status_licensed") }
        public static var mangaStatusPublishingFinished: String { L("manga_status_publishing_finished") }
        public static var mangaStatusCancelled: String { L("manga_status_cancelled") }
        public static var mangaStatusOnHiatus: String { L("manga_status_on_hiatus") }
        public static var mangaStatusUnknown: String { L("manga_status_unknown") }
        public static var mangaFilterScanlator: String { L("manga_filter_scanlator") }
        public static var mangaShowAllScanlators: String { L("manga_show_all_scanlators") }
        public static var mangaSkipRead: String { L("manga_skip_read") }
        public static var mangaSkipFiltered: String { L("manga_skip_filtered") }
        public static var mangaSkipDuplicate: String { L("manga_skip_duplicate") }
        public static var mangaSortDescending: String { L("manga_sort_descending") }
        public static var mangaSortAscending: String { L("manga_sort_ascending") }
        public static var mangaReaderSkip: String { L("manga_reader_skip") }
        public static var mangaReaderSkipFooter: String { L("manga_reader_skip_footer") }
        public static var mangaDuplicateHint: String { L("manga_duplicate_hint") }

        // MARK: - Migration
        public static var migrationSearching: String { L("migration_searching") }
        public static var migrationNoResults: String { L("migration_no_results") }
        public static var migrationComplete: String { L("migration_complete") }
        public static var migrationCompleteMsg: String { L("migration_complete_msg") }
        public static var migrationFailed: String { L("migration_failed") }
        public static var migrationConfirm: String { L("migration_confirm") }
        public static var migrationMigrate: String { L("migration_migrate") }

        // MARK: - Tracking
        public static var trackTitle: String { L("track_title") }
        public static var trackAdd: String { L("track_add") }
        public static var trackStatus: String { L("track_status") }
        public static var trackScore: String { L("track_score") }
        public static var trackChapter: String { L("track_chapter") }
        public static var trackStarted: String { L("track_started") }
        public static var trackFinished: String { L("track_finished") }
        public static var trackSearching: String { L("track_searching") }
        public static var trackNoResults: String { L("track_no_results") }
        public static var trackTryDifferent: String { L("track_try_different") }
        public static var trackLogin: String { L("track_login") }
        public static var trackLoginButton: String { L("track_login_button") }
        public static var trackLogoutButton: String { L("track_logout_button") }
        public static var trackAuthenticating: String { L("track_authenticating") }
        public static var trackServices: String { L("track_services") }
        public static var trackServicesFooter: String { L("track_services_footer") }
        public static var trackConnected: String { L("track_connected") }
        public static var trackNotConnected: String { L("track_not_connected") }
        public static var trackSyncBehaviour: String { L("track_sync_behaviour") }
        public static var trackAutoSync: String { L("track_auto_sync") }
        public static var trackAutoSyncDesc: String { L("track_auto_sync_desc") }
        public static var trackUpdateProgress: String { L("track_update_progress") }
        public static var trackUpdateProgressDesc: String { L("track_update_progress_desc") }

        // MARK: - Reader
        public static var readerTitle: String { L("reader_title") }
        public static var readerReadingMode: String { L("reader_reading_mode") }
        public static var readerMode: String { L("reader_mode") }
        public static var readerDisplay: String { L("reader_display") }
        public static var readerShowPageNumber: String { L("reader_show_page_number") }
        public static var readerKeepScreenOn: String { L("reader_keep_screen_on") }
        public static var readerFullscreen: String { L("reader_fullscreen") }
        public static var readerControls: String { L("reader_controls") }
        public static var readerVolumeKeys: String { L("reader_volume_keys") }
        public static var readerVolumeKeysDesc: String { L("reader_volume_keys_desc") }
        public static var readerColorFilter: String { L("reader_color_filter") }
        public static var readerBrightness: String { L("reader_brightness") }
        public static var readerSplitTall: String { L("reader_split_tall") }
        public static var readerSplitTallDesc: String { L("reader_split_tall_desc") }
        public static var readerImageProcessing: String { L("reader_image_processing") }
        public static var readerSidePadding: String { L("reader_side_padding") }
        public static var readerWebtoon: String { L("reader_webtoon") }
        public static var readerWebtoonFooter: String { L("reader_webtoon_footer") }
        public static var readerRetry: String { L("reader_retry") }

        // MARK: - Downloads
        public static var downloadsTitle: String { L("downloads_title") }
        public static var downloadsNoDownloads: String { L("downloads_no_downloads") }
        public static var downloadsPauseAll: String { L("downloads_pause_all") }
        public static var downloadsResumeAll: String { L("downloads_resume_all") }
        public static var downloadsClearCompleted: String { L("downloads_clear_completed") }
        public static var downloadsCancelAll: String { L("downloads_cancel_all") }
        public static var downloadsQueued: String { L("downloads_queued") }
        public static var downloadsDownloaded: String { L("downloads_downloaded") }
        public static var downloadsLocation: String { L("downloads_location") }
        public static var downloadsLocationFooter: String { L("downloads_location_footer") }
        public static var downloadsStorage: String { L("downloads_storage") }
        public static var downloadsAutoDownload: String { L("downloads_auto_download") }
        public static var downloadsAutoDownloadDesc: String { L("downloads_auto_download_desc") }
        public static var downloadsDeleteAfterRead: String { L("downloads_delete_after_read") }
        public static var downloadsDeleteAfterReadDesc: String { L("downloads_delete_after_read_desc") }
        public static var downloadsRemoveAfterMarked: String { L("downloads_remove_after_marked") }
        public static var downloadsRemoveAfterMarkedDesc: String { L("downloads_remove_after_marked_desc") }
        public static var downloadsAutomation: String { L("downloads_automation") }
        public static var downloadsWifiOnly: String { L("downloads_wifi_only") }
        public static var downloadsWifiOnlyDesc: String { L("downloads_wifi_only_desc") }
        public static var downloadsNetwork: String { L("downloads_network") }
        public static var downloadsParallel: String { L("downloads_parallel") }
        public static var downloadsPerformance: String { L("downloads_performance") }
        public static var downloadsPerformanceFooter: String { L("downloads_performance_footer") }

        // MARK: - Security
        public static var securityTitle: String { L("security_title") }
        public static var securityRequireAuth: String { L("security_require_auth") }
        public static var securityAppLock: String { L("security_app_lock") }
        public static var securityAppLockFooter: String { L("security_app_lock_footer") }
        public static var securitySecureScreen: String { L("security_secure_screen") }
        public static var securitySecureScreenDesc: String { L("security_secure_screen_desc") }
        public static var securityIncognito: String { L("security_incognito") }
        public static var securityIncognitoDesc: String { L("security_incognito_desc") }
        public static var securityPrivacy: String { L("security_privacy") }
        public static var securityAuthUnavailable: String { L("security_auth_unavailable") }
        public static var securityAuthUnavailableMsg: String { L("security_auth_unavailable_msg") }
        public static var securityLockImmediately: String { L("security_lock_immediately") }
        public static var securityLock10s: String { L("security_lock_10s") }
        public static var securityLock30s: String { L("security_lock_30s") }
        public static var securityLock1m: String { L("security_lock_1m") }
        public static var securityLock5m: String { L("security_lock_5m") }
        public static var securityLock10m: String { L("security_lock_10m") }

        // MARK: - Advanced
        public static var advancedTitle: String { L("advanced_title") }
        public static var advancedStorage: String { L("advanced_storage") }
        public static var advancedClearImageCache: String { L("advanced_clear_image_cache") }
        public static var advancedClearImageCacheFooter: String { L("advanced_clear_image_cache_footer") }
        public static var advancedClearDatabase: String { L("advanced_clear_database") }
        public static var advancedClearDatabaseFooter: String { L("advanced_clear_database_footer") }
        public static var advancedResetSettings: String { L("advanced_reset_settings") }
        public static var advancedResetSettingsFooter: String { L("advanced_reset_settings_footer") }
        public static var advancedNetwork: String { L("advanced_network") }
        public static var advancedDoh: String { L("advanced_doh") }
        public static var advancedDohDesc: String { L("advanced_doh_desc") }
        public static var advancedDohFooter: String { L("advanced_doh_footer") }
        public static var advancedDiagnostics: String { L("advanced_diagnostics") }
        public static var advancedCrashLogs: String { L("advanced_crash_logs") }
        public static var advancedCrashLogsFooter: String { L("advanced_crash_logs_footer") }
        public static var advancedAbout: String { L("advanced_about") }
        public static var advancedAppVersion: String { L("advanced_app_version") }
        public static var advancedCopyVersion: String { L("advanced_copy_version") }
        public static var advancedClearCacheConfirm: String { L("advanced_clear_cache_confirm") }
        public static var advancedClearCacheMsg: String { L("advanced_clear_cache_msg") }
        public static var advancedClearCacheButton: String { L("advanced_clear_cache_button") }
        public static var advancedClearDbConfirm: String { L("advanced_clear_db_confirm") }
        public static var advancedClearDbMsg: String { L("advanced_clear_db_msg") }

        // MARK: - About
        public static var aboutTitle: String { L("about_title") }
        public static var aboutConnect: String { L("about_connect") }
        public static var aboutWebsite: String { L("about_website") }
        public static var aboutGitHubSubtitle: String { L("about_github_subtitle") }
        public static var aboutContactDev: String { L("about_contact_dev") }
        public static var aboutLegal: String { L("about_legal") }
        public static var aboutLicenses: String { L("about_licenses") }
        public static var aboutOpenSourceLicense: String { L("about_open_source_license") }
        public static var aboutPrivacyPolicy: String { L("about_privacy_policy") }
        public static var privacyTitle: String { L("privacy_title") }
        public static var privacyLastUpdated: String { L("privacy_last_updated") }
        public static var privacyIntro: String { L("privacy_intro") }
        public static var privacySection1Title: String { L("privacy_section1_title") }
        public static var privacySection1Body: String { L("privacy_section1_body") }
        public static var privacySection2Title: String { L("privacy_section2_title") }
        public static var privacySection2Body: String { L("privacy_section2_body") }
        public static var privacySection3Title: String { L("privacy_section3_title") }
        public static var privacySection3Body: String { L("privacy_section3_body") }
        public static var privacySection4Title: String { L("privacy_section4_title") }
        public static var privacySection4Body: String { L("privacy_section4_body") }
        public static var privacySection5Title: String { L("privacy_section5_title") }
        public static var privacySection5Body: String { L("privacy_section5_body") }
        public static var aboutFooter: String { L("about_footer") }

        // MARK: - Backup
        public static var backupTitle: String { L("backup_title") }
        public static var backupCreate: String { L("backup_create") }
        public static var backupRestore: String { L("backup_restore") }
        public static var backupNoBackups: String { L("backup_no_backups") }
        public static var backupNoBackupsDesc: String { L("backup_no_backups_desc") }

        // MARK: - Common
        public static var commonDone: String { L("common_done") }
        public static var commonCancel: String { L("common_cancel") }
        public static var commonSave: String { L("common_save") }
        public static var commonAdd: String { L("common_add") }
        public static var commonRemove: String { L("common_remove") }
        public static var commonError: String { L("common_error") }
        public static var commonOk: String { L("common_ok") }
        public static var commonSelectAll: String { L("common_select_all") }
        public static var commonDeselectAll: String { L("common_deselect_all") }
        public static var commonChange: String { L("common_change") }
        public static var commonRetry: String { L("common_retry") }

        // MARK: - Onboarding
        public static var onboardingWelcome: String { L("onboarding_welcome") }
        public static var onboardingWelcomeDesc: String { L("onboarding_welcome_desc") }
        public static var onboardingSourcesTitle: String { L("onboarding_sources_title") }
        public static var onboardingSourcesDesc: String { L("onboarding_sources_desc") }
        public static var onboardingSources1: String { L("onboarding_sources_1") }
        public static var onboardingSources2: String { L("onboarding_sources_2") }
        public static var onboardingSources3: String { L("onboarding_sources_3") }
        public static var onboardingLibraryTitle: String { L("onboarding_library_title") }
        public static var onboardingLibraryDesc: String { L("onboarding_library_desc") }
        public static var onboardingLibrary1: String { L("onboarding_library_1") }
        public static var onboardingLibrary2: String { L("onboarding_library_2") }
        public static var onboardingLibrary3: String { L("onboarding_library_3") }
        public static var onboardingReady: String { L("onboarding_ready") }
        public static var onboardingReadyDesc: String { L("onboarding_ready_desc") }
        public static var onboardingNotifications: String { L("onboarding_notifications") }
        public static var onboardingAllow: String { L("onboarding_allow") }
        public static var onboardingSkip: String { L("onboarding_skip") }
        public static var onboardingStart: String { L("onboarding_start") }
        public static var onboardingNotifEnabled: String { L("onboarding_notif_enabled") }
        public static var onboardingNotifDenied: String { L("onboarding_notif_denied") }
        public static var onboardingNotifDesc: String { L("onboarding_notif_desc") }

        // MARK: - Backup (Extended)
        public static var backupActions: String { L("backup_actions") }
        public static var backupActionsDesc: String { L("backup_actions_desc") }
        public static var backupLocal: String { L("backup_local") }
        public static var backupLocalFooter: String { L("backup_local_footer") }
        public static var backupContents: String { L("backup_contents") }
        public static var backupLoading: String { L("backup_loading") }
        public static var backupSelectItems: String { L("backup_select_items") }
        public static var backupSelectItemsDesc: String { L("backup_select_items_desc") }
        public static var backupRestoreComplete: String { L("backup_restore_complete") }
        public static var backupErrorOccurred: String { L("backup_error_occurred") }
        public static var backupRestoreOptions: String { L("backup_restore_options") }
        public static var backupMangaData: String { L("backup_manga_data") }
        public static var backupCategories: String { L("backup_categories") }
        public static var backupChapterProgress: String { L("backup_chapter_progress") }
        public static var backupTrackingRecords: String { L("backup_tracking_records") }
        public static var backupReadingHistory: String { L("backup_reading_history") }
        public static var backupRestoreFrom: String { L("backup_restore_from") }
        public static var backupShareExport: String { L("backup_share_export") }
        public static var backupStartRestore: String { L("backup_start_restore") }
        public static func backupCreatedAt(_ date: String, _ version: String) -> String { String(format: L("backup_created_at"), date, version) }

        // MARK: - Library (Extended)
        public static var libraryContinueReading: String { L("library_continue_reading") }
        public static var librarySearchPrompt: String { L("library_search_prompt") }
        public static var librarySelect: String { L("library_select") }
        public static var libraryDefault: String { L("library_default") }
        public static var libraryAlwaysAsk: String { L("library_always_ask") }
        public static var libraryCategoriesSection: String { L("library_categories_section") }
        public static var libraryDefaultCategoryDesc: String { L("library_default_category_desc") }
        public static var libraryWifiOnly: String { L("library_wifi_only") }
        public static var libraryWifiOnlyDesc: String { L("library_wifi_only_desc") }
        public static var libraryChargingOnly: String { L("library_charging_only") }
        public static var libraryChargingOnlyDesc: String { L("library_charging_only_desc") }
        public static var libraryUpdateRestrictions: String { L("library_update_restrictions") }
        public static var libraryRestrictionsDesc: String { L("library_restrictions_desc") }
        public static var libraryAutoRefresh: String { L("library_auto_refresh") }
        public static var libraryAutoRefreshDesc: String { L("library_auto_refresh_desc") }
        public static var libraryMetadata: String { L("library_metadata") }
        public static func librarySelectedCount(_ count: Int) -> String { String(format: L("library_selected_count"), count) }

        // MARK: - Manga (Extended)
        public static var mangaGenres: String { L("manga_genres") }
        public static var mangaNoChapters: String { L("manga_no_chapters") }
        public static func mangaSourceId(_ id: Int64) -> String { String(format: L("manga_source_id"), id) }
        public static func mangaChaptersCount(_ count: Int) -> String { String(format: L("manga_chapters_count"), count) }
        public static func mangaDuplicatesCount(_ count: Int) -> String { String(format: L("manga_duplicates_count"), count) }

        // MARK: - Chapter
        public static func chapterPage(_ page: Int) -> String { String(format: L("chapter_page"), page) }
        public static var chapterScanlators: String { L("chapter_scanlators") }
        public static func chapterHiddenCount(_ count: Int) -> String { String(format: L("chapter_hidden_count"), count) }

        // MARK: - About (Extended)
        public static func aboutVersion(_ version: String, _ build: String) -> String { String(format: L("about_version"), version, build) }
        public static func aboutVersionBuild(_ version: String, _ build: String) -> String { String(format: L("about_version_build"), version, build) }

        // MARK: - Upcoming
        public static var upcomingNoUpdates: String { L("upcoming_no_updates") }
        public static func upcomingEveryDays(_ days: Int) -> String { String(format: L("upcoming_every_days"), days) }

        // MARK: - Cloudflare WebView
        public static var cloudflareVerification: String { L("cloudflare_verification") }
        public static func cloudflareInvalidUrl(_ url: String) -> String { String(format: L("cloudflare_invalid_url"), url) }

        // MARK: - Category Picker
        public static var categoryCreateHint: String { L("category_create_hint") }
        public static var categorySet: String { L("category_set") }

        // MARK: - Track (Extended)
        public static func trackLoginDesc(_ name: String) -> String { String(format: L("track_login_desc"), name) }
        public static func trackLogoutDesc(_ name: String) -> String { String(format: L("track_logout_desc"), name) }
        public static func trackChaptersShort(_ count: Int) -> String { String(format: L("track_chapters_short"), count) }

        // MARK: - Browse (Extended)
        public static var browseOpenWebview: String { L("browse_open_webview") }

        // MARK: - Extension
        public static var extensionForceRefresh: String { L("extension_force_refresh") }
        public static var extensionActions: String { L("extension_actions") }
        public static var extensionForceRefreshDesc: String { L("extension_force_refresh_desc") }
        public static var extensionDangerZone: String { L("extension_danger_zone") }
        public static var extensionRefreshFailed: String { L("extension_refresh_failed") }
        public static var extensionNoSources: String { L("extension_no_sources") }
        public static var extensionSourcesFooter: String { L("extension_sources_footer") }

        // MARK: - Sources
        public static var sourcesPinned: String { L("sources_pinned") }
        public static var sourcesNotFound: String { L("sources_not_found") }

        // MARK: - Migration (Extended)
        public static var migrationNoSources: String { L("migration_no_sources") }
        public static var migrationSelectSource: String { L("migration_select_source") }
        public static var migrationNoManga: String { L("migration_no_manga") }
        public static var migrationMigrating: String { L("migration_migrating") }
        public static func migrationMigrateTitle(_ title: String) -> String { String(format: L("migration_migrate_title"), title) }
        public static func migrationResultsCount(_ count: Int) -> String { String(format: L("migration_results_count"), count) }

        // MARK: - Global Search
        public static func globalSearchResults(_ count: Int) -> String { String(format: L("global_search_results"), count) }

        // MARK: - Downloads (Extended)
        public static var downloadsCustomFolderNote: String { L("downloads_custom_folder_note") }
        public static var downloadsDefaultLocation: String { L("downloads_default_location") }

        // MARK: - Reader (Extended)
        public static var readerDefaultMode: String { L("reader_default_mode") }
        public static var readerDoubleTapZoom: String { L("reader_double_tap_zoom") }
        public static var readerDoubleTapZoomDesc: String { L("reader_double_tap_zoom_desc") }
        public static var readerShowPageDesc: String { L("reader_show_page_desc") }
        public static var readerKeepScreenDesc: String { L("reader_keep_screen_desc") }
        public static var readerSkipFiltered: String { L("reader_skip_filtered") }
        public static var readerSkipFilteredDesc: String { L("reader_skip_filtered_desc") }
        public static var readerChaptersSection: String { L("reader_chapters_section") }
        public static var readerBrightnessOffset: String { L("reader_brightness_offset") }
        public static var readerColorFilterDefaults: String { L("reader_color_filter_defaults") }
        public static var readerColorFilterDefaultsDesc: String { L("reader_color_filter_defaults_desc") }
        public static var readerFinished: String { L("reader_finished") }
        public static var readerNextChapter: String { L("reader_next_chapter") }
        public static var readerNoNextChapter: String { L("reader_no_next_chapter") }
        public static var readerPreviousChapter: String { L("reader_previous_chapter") }
        public static var readerNoPreviousChapter: String { L("reader_no_previous_chapter") }
        public static var readerChapterList: String { L("reader_chapter_list") }
        public static var readerLoadFailed: String { L("reader_load_failed") }

        // MARK: - Appearance
        public static var appearanceOledDesc: String { L("appearance_oled_desc") }
        public static var appearanceTheme: String { L("appearance_theme") }
        public static var appearanceTintColor: String { L("appearance_tint_color") }
        public static var appearanceTintDesc: String { L("appearance_tint_desc") }
        public static var appearanceRelativeTimestamps: String { L("appearance_relative_timestamps") }
        public static var appearanceTimestamps: String { L("appearance_timestamps") }

        // MARK: - Statistics
        public static var statsMangaByStatus: String { L("stats_manga_by_status") }
        public static var statsNoManga: String { L("stats_no_manga") }
        public static var statsReadingActivity: String { L("stats_reading_activity") }

        // MARK: - Advanced (Extended - Proxy)
        public static var advancedProxyTitle: String { L("advanced_proxy_title") }
        public static var advancedProxyDesc: String { L("advanced_proxy_desc") }
        public static var advancedProxyWorkerUrl: String { L("advanced_proxy_worker_url") }
        public static var advancedProxyUrlPlaceholder: String { L("advanced_proxy_url_placeholder") }
        public static var advancedProxyApiKey: String { L("advanced_proxy_api_key") }
        public static var advancedProxyKeyPlaceholder: String { L("advanced_proxy_key_placeholder") }
        public static var advancedProxyTest: String { L("advanced_proxy_test") }
        public static var advancedProxySection: String { L("advanced_proxy_section") }
        public static var advancedProxyFooter: String { L("advanced_proxy_footer") }

        // MARK: - Main iPad
        public static var mainSelectTab: String { L("main_select_tab") }

        // MARK: - iCloud Sync
        public static var syncTitle: String { L("sync_title") }
        public static var syncICloudStatus: String { L("sync_icloud_status") }
        public static var syncAccountAvailable: String { L("sync_account_available") }
        public static var syncAccountNoAccount: String { L("sync_account_no_account") }
        public static var syncAccountRestricted: String { L("sync_account_restricted") }
        public static var syncAccountUnknown: String { L("sync_account_unknown") }
        public static var syncLastSync: String { L("sync_last_sync") }
        public static var syncNever: String { L("sync_never") }

        public static var syncICloudDriveSection: String { L("sync_icloud_drive_section") }
        public static var syncAutoBackup: String { L("sync_auto_backup") }
        public static var syncAutoBackupDesc: String { L("sync_auto_backup_desc") }
        public static var syncBackupNow: String { L("sync_backup_now") }
        public static var syncCloudBackups: String { L("sync_cloud_backups") }
        public static var syncNoCloudBackups: String { L("sync_no_cloud_backups") }
        public static var syncRestoreFrom: String { L("sync_restore_from") }
        public static var syncRestoreConfirm: String { L("sync_restore_confirm") }
        public static var syncRestoreConfirmMsg: String { L("sync_restore_confirm_msg") }

        public static var syncCloudKitSection: String { L("sync_cloudkit_section") }
        public static var syncCloudKitEnabled: String { L("sync_cloudkit_enabled") }
        public static var syncCloudKitEnabledDesc: String { L("sync_cloudkit_enabled_desc") }
        public static var syncSyncNow: String { L("sync_sync_now") }
        public static var syncResetCloud: String { L("sync_reset_cloud") }
        public static var syncResetCloudConfirm: String { L("sync_reset_cloud_confirm") }
        public static var syncResetCloudConfirmMsg: String { L("sync_reset_cloud_confirm_msg") }
        public static var syncStatusIdle: String { L("sync_status_idle") }
        public static var syncStatusSyncing: String { L("sync_status_syncing") }
        public static var syncStatusSuccess: String { L("sync_status_success") }
        public static var syncStatusError: String { L("sync_status_error") }

        public static var syncCloudKitUnavailableTitle: String { L("sync_cloudkit_unavailable_title") }
        public static var syncCloudKitUnavailableMsg: String { L("sync_cloudkit_unavailable_msg") }

        public static var syncNewDeviceTitle: String { L("sync_new_device_title") }
        public static var syncNewDeviceMsg: String { L("sync_new_device_msg") }
        public static var syncRestore: String { L("sync_restore") }
    }
}
