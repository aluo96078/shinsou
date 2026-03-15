import Foundation
import SwiftSoup
import ShinsouSourceAPI

// MARK: - Theme Definition

/// Defines CSS selectors and URL patterns for a manga site theme.
struct ThemeDefinition {
    let name: String

    // URL patterns — `{page}` is replaced with the page number, `{query}` with URL-encoded search text
    let popularUrlPattern: String
    let latestUrlPattern: String
    let searchUrlPattern: String

    // CSS selectors for manga list pages
    let mangaListSelector: String
    let mangaTitleSelector: String
    let mangaUrlSelector: String
    let mangaThumbnailSelector: String
    let nextPageSelector: String

    // CSS selectors for manga detail page
    let detailTitleSelector: String
    let detailAuthorSelector: String
    let detailDescriptionSelector: String
    let detailGenreSelector: String
    let detailStatusSelector: String
    let detailThumbnailSelector: String

    // CSS selectors for chapter list (on detail page)
    let chapterListSelector: String
    let chapterTitleSelector: String
    let chapterUrlSelector: String
    let chapterDateSelector: String

    // CSS selectors for page list (reader page)
    let pageImageSelector: String

    // Optional: attribute names
    let thumbnailAttribute: String
    let urlAttribute: String

    // Filter support — URL pattern with `{sort}`, `{status}`, `{genre}` placeholders
    let filterUrlPattern: String?
    let sortOptions: [(name: String, value: String)]
    let statusOptions: [(name: String, value: String)]
    let genreUrlPattern: String?  // URL pattern for genre browsing with `{genre}` placeholder

    init(name: String,
         popularUrlPattern: String, latestUrlPattern: String, searchUrlPattern: String,
         mangaListSelector: String, mangaTitleSelector: String, mangaUrlSelector: String,
         mangaThumbnailSelector: String, nextPageSelector: String,
         detailTitleSelector: String, detailAuthorSelector: String,
         detailDescriptionSelector: String, detailGenreSelector: String,
         detailStatusSelector: String, detailThumbnailSelector: String,
         chapterListSelector: String, chapterTitleSelector: String,
         chapterUrlSelector: String, chapterDateSelector: String,
         pageImageSelector: String, thumbnailAttribute: String, urlAttribute: String,
         filterUrlPattern: String? = nil,
         sortOptions: [(name: String, value: String)] = [],
         statusOptions: [(name: String, value: String)] = [],
         genreUrlPattern: String? = nil) {
        self.name = name
        self.popularUrlPattern = popularUrlPattern
        self.latestUrlPattern = latestUrlPattern
        self.searchUrlPattern = searchUrlPattern
        self.mangaListSelector = mangaListSelector
        self.mangaTitleSelector = mangaTitleSelector
        self.mangaUrlSelector = mangaUrlSelector
        self.mangaThumbnailSelector = mangaThumbnailSelector
        self.nextPageSelector = nextPageSelector
        self.detailTitleSelector = detailTitleSelector
        self.detailAuthorSelector = detailAuthorSelector
        self.detailDescriptionSelector = detailDescriptionSelector
        self.detailGenreSelector = detailGenreSelector
        self.detailStatusSelector = detailStatusSelector
        self.detailThumbnailSelector = detailThumbnailSelector
        self.chapterListSelector = chapterListSelector
        self.chapterTitleSelector = chapterTitleSelector
        self.chapterUrlSelector = chapterUrlSelector
        self.chapterDateSelector = chapterDateSelector
        self.pageImageSelector = pageImageSelector
        self.thumbnailAttribute = thumbnailAttribute
        self.urlAttribute = urlAttribute
        self.filterUrlPattern = filterUrlPattern
        self.sortOptions = sortOptions
        self.statusOptions = statusOptions
        self.genreUrlPattern = genreUrlPattern
    }
}

// MARK: - Built-in Themes

extension ThemeDefinition {

    /// Madara WordPress manga theme
    static let madara = ThemeDefinition(
        name: "Madara",
        popularUrlPattern: "/manga/?m_orderby=views&page={page}",
        latestUrlPattern: "/manga/?m_orderby=latest&page={page}",
        searchUrlPattern: "/?s={query}&post_type=wp-manga&paged={page}",
        mangaListSelector: "div.page-item-detail, div.c-tabs-item__content",
        mangaTitleSelector: "div.post-title h3 a, div.post-title h5 a, div.post-title a",
        mangaUrlSelector: "div.post-title h3 a, div.post-title h5 a, div.post-title a",
        mangaThumbnailSelector: "img",
        nextPageSelector: "div.nav-previous a, a.nextpostslink, a.last",
        detailTitleSelector: "div.post-title h1, div.post-title h3",
        detailAuthorSelector: "div.author-content a, span.author-content a",
        detailDescriptionSelector: "div.description-summary div.summary__content p, div.summary__content",
        detailGenreSelector: "div.genres-content a",
        detailStatusSelector: "div.post-content_item:contains(Status) div.summary-content, div.post-status div.summary-content",
        detailThumbnailSelector: "div.summary_image img",
        chapterListSelector: "li.wp-manga-chapter, ul.version-chap li",
        chapterTitleSelector: "a",
        chapterUrlSelector: "a",
        chapterDateSelector: "span.chapter-release-date, span.chapter-release-date i",
        pageImageSelector: "div.page-break img, div.reading-content img",
        thumbnailAttribute: "src",
        urlAttribute: "href",
        filterUrlPattern: "/manga/?m_orderby={sort}&status[]={status}&page={page}",
        sortOptions: [("Views", "views"), ("Rating", "rating"), ("Latest", "latest"), ("A-Z", "alphabet"), ("Trending", "trending"), ("New", "new-manga")],
        statusOptions: [("All", ""), ("Ongoing", "on-going"), ("Completed", "end"), ("On Hold", "on-hold"), ("Cancelled", "canceled")]
    )

    /// MangaThemesia
    static let mangaThemesia = ThemeDefinition(
        name: "MangaThemesia",
        popularUrlPattern: "/manga/?order=popular&page={page}",
        latestUrlPattern: "/manga/?order=update&page={page}",
        searchUrlPattern: "/?s={query}&page={page}",
        mangaListSelector: "div.bs div.bsx, div.listupd div.bs div.bsx, div.listupd div.utao",
        mangaTitleSelector: "a[title], div.tt, a .ntitle",
        mangaUrlSelector: "a",
        mangaThumbnailSelector: "img.ts-post-image, img.wp-post-image, img",
        nextPageSelector: "a.next.page-numbers, div.hpage a.r",
        detailTitleSelector: "h1.entry-title",
        detailAuthorSelector: "span:contains(Author) i, div.tsinfo div:contains(Author) i",
        detailDescriptionSelector: "div.entry-content[itemprop=description] p, div.entry-content p",
        detailGenreSelector: "span.mgen a, div.wd-full span.mgen a",
        detailStatusSelector: "span:contains(Status) i, div.tsinfo div:contains(Status) i",
        detailThumbnailSelector: "div.thumb img, img.attachment-",
        chapterListSelector: "div#chapterlist ul li, ul.clstyle li",
        chapterTitleSelector: "span.chapternum, a span.chapternum",
        chapterUrlSelector: "a",
        chapterDateSelector: "span.chapterdate",
        pageImageSelector: "div#readerarea img, img.ts-main-image",
        thumbnailAttribute: "src",
        urlAttribute: "href",
        filterUrlPattern: "/manga/?order={sort}&status={status}&page={page}",
        sortOptions: [("Popular", "popular"), ("Latest", "update"), ("A-Z", "title"), ("Rating", "rating")],
        statusOptions: [("All", ""), ("Ongoing", "ongoing"), ("Completed", "completed"), ("Hiatus", "hiatus")]
    )

    /// Mangabox — Mangakakalot / Manganato / Chapmanganato style
    static let mangabox = ThemeDefinition(
        name: "Mangabox",
        popularUrlPattern: "/manga_list?type=topview&category=all&state=all&page={page}",
        latestUrlPattern: "/manga_list?type=latest&category=all&state=all&page={page}",
        searchUrlPattern: "/search/story/{query}?page={page}",
        mangaListSelector: "div.content-genres-item, div.list-truyen-item-wrap, div.search-story-item",
        mangaTitleSelector: "h3 a, a.genres-item-name",
        mangaUrlSelector: "h3 a, a.genres-item-name",
        mangaThumbnailSelector: "img",
        nextPageSelector: "a.page-next, a.page-blue.page-last",
        detailTitleSelector: "h1, h2, ul.manga-info-text li h1",
        detailAuthorSelector: "li:contains(Author) a, td:contains(Author) + td a",
        detailDescriptionSelector: "div#noidungm, div.panel-story-info-description, div#panel-story-info-description",
        detailGenreSelector: "li:contains(Genre) a, td:contains(Genres) + td a",
        detailStatusSelector: "li:contains(Status), td:contains(Status) + td",
        detailThumbnailSelector: "div.manga-info-pic img, span.info-image img",
        chapterListSelector: "div.chapter-list div.row, ul.row-content-chapter li",
        chapterTitleSelector: "a",
        chapterUrlSelector: "a",
        chapterDateSelector: "span:last-child",
        pageImageSelector: "div.container-chapter-reader img, div#vungdoc img",
        thumbnailAttribute: "src",
        urlAttribute: "href",
        filterUrlPattern: "/manga_list?type={sort}&category=all&state={status}&page={page}",
        sortOptions: [("Top View", "topview"), ("Newest", "newest"), ("Latest Update", "latest")],
        statusOptions: [("All", "all"), ("Ongoing", "ongoing"), ("Completed", "completed")]
    )

    /// FMReader
    static let fmreader = ThemeDefinition(
        name: "FMReader",
        popularUrlPattern: "/manga-list.html?listType=pagination&page={page}&sort=views&sort_type=DESC",
        latestUrlPattern: "/manga-list.html?listType=pagination&page={page}&sort=last_update&sort_type=DESC",
        searchUrlPattern: "/manga-list.html?listType=pagination&page={page}&name={query}",
        mangaListSelector: "div.thumb-item-flow div.thumb_attr, div.list-truyen-item-wrap",
        mangaTitleSelector: "div.series-title a, h3 a",
        mangaUrlSelector: "div.series-title a, h3 a",
        mangaThumbnailSelector: "div.content img, img",
        nextPageSelector: "a.next, a[rel=next]",
        detailTitleSelector: "h1.series-name, h1.title-manga",
        detailAuthorSelector: "li.author p.col-xs-8 a",
        detailDescriptionSelector: "div.summary-content p, div.series-summary",
        detailGenreSelector: "li.kind p.col-xs-8 a",
        detailStatusSelector: "li.status p.col-xs-8",
        detailThumbnailSelector: "div.col-image img",
        chapterListSelector: "ul.list-chapters li, div.list-chapters li",
        chapterTitleSelector: "a",
        chapterUrlSelector: "a",
        chapterDateSelector: "div.col-xs-4, span.date-updated",
        pageImageSelector: "div.chapter-content img, img#chapter-img",
        thumbnailAttribute: "src",
        urlAttribute: "href",
        filterUrlPattern: "/manga-list.html?listType=pagination&page={page}&sort={sort}&sort_type=DESC",
        sortOptions: [("Views", "views"), ("Latest Update", "last_update"), ("Name", "name")],
        statusOptions: [("All", ""), ("Ongoing", "ongoing"), ("Completed", "completed")]
    )

    /// GroupLe / Grouple — used by ReadManga, MintManga (Russian sites)
    static let grouple = ThemeDefinition(
        name: "Grouple",
        popularUrlPattern: "/list?sortType=rate&page={page}",
        latestUrlPattern: "/list?sortType=updated&page={page}",
        searchUrlPattern: "/search?q={query}&page={page}",
        mangaListSelector: "div.tile, div.desc",
        mangaTitleSelector: "h3 a, a.manga-tooltip",
        mangaUrlSelector: "h3 a, a.manga-tooltip",
        mangaThumbnailSelector: "img.lazy, img",
        nextPageSelector: "a.next",
        detailTitleSelector: "h1.names .name, h1",
        detailAuthorSelector: "span.elem_author a, p.author a",
        detailDescriptionSelector: "div.manga-description",
        detailGenreSelector: "span.elem_genre a, span.genre a",
        detailStatusSelector: "p.status, span.elem_status",
        detailThumbnailSelector: "div.subject-cover img, img.cover",
        chapterListSelector: "div.chapters-link tbody tr, div.chapters-link a",
        chapterTitleSelector: "a, td a",
        chapterUrlSelector: "a, td a",
        chapterDateSelector: "td.date, span.date",
        pageImageSelector: "div#fotocontext img, img.manga-img",
        thumbnailAttribute: "src",
        urlAttribute: "href",
        filterUrlPattern: "/list?sortType={sort}&page={page}",
        sortOptions: [("Rating", "rate"), ("Popularity", "votes"), ("Latest Update", "updated"), ("Name", "name"), ("New", "created")],
        statusOptions: [("All", ""), ("Ongoing", "ongoing"), ("Completed", "completed")]
    )

    /// Generic fallback — broad selectors that work on many sites
    static let generic = ThemeDefinition(
        name: "Generic",
        popularUrlPattern: "/?page={page}",
        latestUrlPattern: "/manga/?page={page}",
        searchUrlPattern: "/search?q={query}&page={page}",
        mangaListSelector: "[class*=manga] a[href], [class*=item] a[href], [class*=comic] a[href], div.gallery a[href]",
        mangaTitleSelector: "h3, h4, [class*=title], [class*=name], span",
        mangaUrlSelector: "a",
        mangaThumbnailSelector: "img",
        nextPageSelector: "a.next, a[rel=next], a:contains(Next), li.next a",
        detailTitleSelector: "h1, h2",
        detailAuthorSelector: "[class*=author] a, a[href*=author]",
        detailDescriptionSelector: "[class*=desc], [class*=summary], [class*=synopsis]",
        detailGenreSelector: "[class*=genre] a, [class*=tag] a",
        detailStatusSelector: "[class*=status]",
        detailThumbnailSelector: "[class*=cover] img, [class*=thumb] img",
        chapterListSelector: "[class*=chapter] a, li a[href*=chapter]",
        chapterTitleSelector: "a",
        chapterUrlSelector: "a",
        chapterDateSelector: "span, time",
        pageImageSelector: "[class*=reader] img, [class*=content] img[src*=manga], [class*=content] img[src*=chapter]",
        thumbnailAttribute: "src",
        urlAttribute: "href"
    )

    /// ManhuaGui (漫畫柜) — Chinese manga aggregator
    static let manhuagui = ThemeDefinition(
        name: "ManhuaGui",
        popularUrlPattern: "/rank/",
        latestUrlPattern: "/update/",
        searchUrlPattern: "/s/{query}.html",
        mangaListSelector: "div.main-list ul li a, div.cont-list ul li a",
        mangaTitleSelector: "h3",
        mangaUrlSelector: "a[href*=comic]",
        mangaThumbnailSelector: "img",
        nextPageSelector: "a.next, #more",
        detailTitleSelector: "h1, div.book-title h1",
        detailAuthorSelector: "dd a[href*=author], dl:contains(作者) dd a, dt:contains(作) + dd a",
        detailDescriptionSelector: "div#intro-all, div#intro-cut",
        detailGenreSelector: "dl:contains(类别) dd a, dt:contains(类) + dd a, span.tag a",
        detailStatusSelector: "dl:contains(状态) dd, dt:contains(状态) + dd",
        detailThumbnailSelector: "div.thumb img, div.book-cover img, p.hcover img",
        chapterListSelector: "div.chapter-list ul li a, ul.chapter-page li a",
        chapterTitleSelector: "a",
        chapterUrlSelector: "a",
        chapterDateSelector: "span.date",
        pageImageSelector: "div#mangaBox img, img#mangaFile",
        thumbnailAttribute: "src",
        urlAttribute: "href",
        filterUrlPattern: "/list/{genre}_{status}_{sort}/",
        sortOptions: [("Popular", "view"), ("Latest Update", "update"), ("Rating", "rate"), ("Newest", "index")],
        statusOptions: [("All", ""), ("Ongoing", "lianzai"), ("Completed", "wanjie")],
        genreUrlPattern: "/list/{genre}/"
    )

    /// ManhuaGui built-in genres (from homepage nav)
    static let manhuaguiGenres: [(name: String, value: String)] = [
        ("全部", ""), ("日本", "japan"), ("港台", "hongkong"), ("欧美", "europe"),
        ("内地", "china"), ("韩国", "korea"), ("热血", "rexue"), ("冒险", "maoxian"),
        ("魔幻", "mohuan"), ("神鬼", "shengui"), ("搞笑", "gaoxiao"), ("萌系", "mengxi"),
        ("爱情", "aiqing"), ("科幻", "kehuan"), ("魔法", "mofa"), ("格斗", "gedou"),
        ("武侠", "wuxia"), ("机战", "jizhan"), ("战争", "zhanzheng"), ("竞技", "jingji"),
        ("体育", "tiyu"), ("校园", "xiaoyuan"), ("生活", "shenghuo"), ("励志", "lizhi"),
        ("历史", "lishi"), ("伪娘", "weiniang"), ("宅男", "zhainan"), ("腐女", "funv"),
        ("耽美", "danmei"), ("百合", "baihe"), ("后宫", "hougong"), ("治愈", "zhiyu"),
        ("美食", "meishi"), ("推理", "tuili"), ("悬疑", "xuanyi"), ("恐怖", "kongbu"),
        ("四格", "sige"), ("职场", "zhichang"), ("侦探", "zhentan"), ("社会", "shehui"),
        ("音乐", "yinyue"), ("舞蹈", "wudao"), ("杂志", "zazhi"), ("黑道", "heidao"),
        ("少女", "shaonv"), ("少年", "shaonian"), ("青年", "qingnian"), ("儿童", "ertong"),
    ]

    /// E-Hentai gallery site
    static let ehentai = ThemeDefinition(
        name: "EHentai",
        popularUrlPattern: "/popular?page={page}",
        latestUrlPattern: "/?page={page}",
        searchUrlPattern: "/?f_search={query}&page={page}&f_apply=Apply+Filter",
        mangaListSelector: "table.itg tr:has(td.gl3c)",
        mangaTitleSelector: "div.glink",
        mangaUrlSelector: "td.gl3c a, td.gl2c a",
        mangaThumbnailSelector: "td.gl2c div.glthumb img, td.gl2c img, img",
        nextPageSelector: "table.ptt td:last-child a, a#dnext",
        detailTitleSelector: "h1#gn, h1#gj",
        detailAuthorSelector: "div#taglist tr:contains(artist) td a, div#taglist tr:contains(group) td a",
        detailDescriptionSelector: "div#gd2 div#gdn, div.gm div#gd2",
        detailGenreSelector: "div#taglist tr td a",
        detailStatusSelector: "div#gdd tr:contains(Length) td.gdt2",
        detailThumbnailSelector: "div#gd1 img, div#gleft img",
        chapterListSelector: "___none___",
        chapterTitleSelector: "a",
        chapterUrlSelector: "a",
        chapterDateSelector: "span",
        pageImageSelector: "div#i3 img#img, img#img",
        thumbnailAttribute: "src",
        urlAttribute: "href",
        filterUrlPattern: "/?f_cats={cats}&f_search={query}&page={page}&f_apply=Apply+Filter",
        sortOptions: [],
        statusOptions: []
    )

    /// E-Hentai categories (bitmask: f_cats = sum of EXCLUDED category values)
    static let ehentaiCategories: [(name: String, value: Int)] = [
        ("Doujinshi", 2), ("Manga", 4), ("Artist CG", 8), ("Game CG", 16),
        ("Western", 512), ("Non-H", 256), ("Image Set", 32), ("Cosplay", 64),
        ("Asian Porn", 128), ("Misc", 1),
    ]

    /// All built-in themes for auto-detection (generic last as fallback)
    static let allThemes: [ThemeDefinition] = [madara, mangaThemesia, mangabox, fmreader, grouple, manhuagui, ehentai]
}

// MARK: - Scraping Errors

enum ScrapingError: Error, LocalizedError {
    case cloudflareBlocked(String)
    case httpError(Int, String)
    case noResults(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .cloudflareBlocked(let site):
            return "'\(site)' 受 Cloudflare 保護，需要開啟網頁完成驗證。"
        case .httpError(let code, let site):
            return "HTTP \(code) error when accessing '\(site)'."
        case .noResults(let site):
            return "No manga found on '\(site)'. The site structure may not be supported."
        case .invalidResponse(let site):
            return "Invalid response from '\(site)'."
        }
    }

    var isCloudflare: Bool {
        if case .cloudflareBlocked = self { return true }
        return false
    }
}

// MARK: - ParsedHttpSource

/// Base scraping source that fetches HTML pages and parses manga listings using CSS selectors.
/// Supports multi-theme fallback: if the detected theme returns 0 results, tries all other themes.
final class ParsedHttpSource {
    let baseUrl: String
    private let session: URLSession
    private var theme: ThemeDefinition?
    private var cachedHomepageHtml: String?

    /// Auto-detected filter options from the site
    struct FilterOption {
        let name: String
        let value: String
    }
    private(set) var detectedGenres: [FilterOption] = []
    private(set) var detectedSortOptions: [FilterOption] = []
    private(set) var detectedStatusOptions: [FilterOption] = []

    init(baseUrl: String, theme: ThemeDefinition? = nil) {
        self.baseUrl = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        self.theme = theme

        // Use NetworkHelper's cacheless session (anti-scraping features applied at request level)
        self.session = NetworkHelper.shared.cachelessSession
    }

    // MARK: - Public API

    func getPopularManga(page: Int) async throws -> MangasPage {
        let theme = try await resolveTheme()

        // Try theme-specific URL first (use try? to not abort on 404)
        let urlStr = baseUrl + theme.popularUrlPattern
            .replacingOccurrences(of: "{page}", with: "\(page)")
        if let result = try? await fetchMangaList(urlStr: urlStr, theme: theme),
           !result.mangas.isEmpty {
            return result
        }

        // On page 1: try smart extraction from cached homepage, then full fallback
        if page == 1 {
            if let cachedHtml = cachedHomepageHtml,
               let smartResult = try? extractMangaFromGenericHtml(cachedHtml),
               !smartResult.mangas.isEmpty {
                print("[ParsedHttpSource] Smart extraction found \(smartResult.mangas.count) entries for \(baseUrl)")
                return smartResult
            }
            return try await fallbackAllThemes(page: page, mode: .popular)
        }

        return MangasPage(mangas: [], hasNextPage: false)
    }

    func getLatestUpdates(page: Int) async throws -> MangasPage {
        let theme = try await resolveTheme()
        let urlStr = baseUrl + theme.latestUrlPattern
            .replacingOccurrences(of: "{page}", with: "\(page)")

        if let result = try? await fetchMangaList(urlStr: urlStr, theme: theme),
           !result.mangas.isEmpty {
            return result
        }

        if page == 1 {
            if let cachedHtml = cachedHomepageHtml,
               let smartResult = try? extractMangaFromGenericHtml(cachedHtml),
               !smartResult.mangas.isEmpty {
                return smartResult
            }
            return try await fallbackAllThemes(page: page, mode: .latest)
        }

        return MangasPage(mangas: [], hasNextPage: false)
    }

    func getSearchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage {
        let theme = try await resolveTheme()

        // E-Hentai: always use custom URL builder (combines query + filters)
        if theme.name == "EHentai" {
            let urlStr = buildEHentaiUrl(page: page, query: query, filters: filters)
            return try await fetchMangaList(urlStr: urlStr, theme: theme)
        }

        // If there's a text query, use search URL
        if !query.isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let urlStr = baseUrl + theme.searchUrlPattern
                .replacingOccurrences(of: "{query}", with: encoded)
                .replacingOccurrences(of: "{page}", with: "\(page)")
            return try await fetchMangaList(urlStr: urlStr, theme: theme)
        }

        // Only use filter URL if the theme supports it
        if theme.filterUrlPattern != nil, !filters.isEmpty {
            let urlStr = buildFilteredUrl(page: page, filters: filters, theme: theme)
            if let result = try? await fetchMangaList(urlStr: urlStr, theme: theme),
               !result.mangas.isEmpty {
                return result
            }
            // Filter URL failed — fall through to popular
        }

        // Fallback: just use the popular listing
        return try await getPopularManga(page: page)
    }

    // MARK: - Filter Support

    func getFilterList() -> FilterList {
        // Try to use resolved theme; if not yet resolved, return empty (will be populated later)
        guard let theme = theme else { return [] }
        return buildFilterList(for: theme)
    }

    /// Build filters after theme is resolved (called by StubCatalogueSource after first browse).
    func getFilterListAsync() async -> FilterList {
        guard let theme = try? await resolveTheme() else { return [] }
        return buildFilterList(for: theme)
    }

    private func buildFilterList(for theme: ThemeDefinition) -> FilterList {
        // E-Hentai: special filter structure with category checkboxes and tag search
        if theme.name == "EHentai" {
            return buildEHentaiFilterList()
        }

        var filters: FilterList = []

        // Sort: prefer theme-defined, fallback to auto-detected
        let sortOpts = !theme.sortOptions.isEmpty ? theme.sortOptions.map { FilterOption(name: $0.name, value: $0.value) } : detectedSortOptions
        if !sortOpts.isEmpty {
            filters.append(.sort(
                name: "Sort by",
                values: sortOpts.map(\.name),
                selection: Filter.SortSelection(index: 0, ascending: false)
            ))
        }

        // Status: prefer theme-defined, fallback to auto-detected
        let statusOpts = !theme.statusOptions.isEmpty ? theme.statusOptions.map { FilterOption(name: $0.name, value: $0.value) } : detectedStatusOptions
        if !statusOpts.isEmpty {
            filters.append(.select(
                name: "Status",
                values: statusOpts.map(\.name),
                state: 0
            ))
        }

        // Genre: prefer hardcoded for ManhuaGui, then auto-detected
        let genres: [FilterOption]
        if theme.name == "ManhuaGui" {
            genres = ThemeDefinition.manhuaguiGenres.map { FilterOption(name: $0.name, value: $0.value) }
        } else {
            genres = detectedGenres
        }

        if !genres.isEmpty {
            // Use Select dropdown (easier for many options)
            let genreNames = ["All"] + genres.map(\.name)
            filters.append(.select(
                name: "Genre",
                values: genreNames,
                state: 0
            ))
        }

        return filters
    }

    // MARK: - E-Hentai specific filters

    private func buildEHentaiFilterList() -> FilterList {
        // Categories as checkboxes (enabled by default — unchecking = excluding)
        let categoryFilters: [Filter] = ThemeDefinition.ehentaiCategories.map { cat in
            .checkBox(name: cat.name, state: true)
        }

        return [
            .header(name: "Categories"),
            .group(name: "Categories", filters: categoryFilters),
            .header(name: "Search"),
            .text(name: "Tags", state: ""),
            .select(name: "Minimum Rating", values: ["Any", "2+", "3+", "4+", "5"], state: 0),
            .select(name: "Pages", values: ["Any", "10+", "25+", "50+", "100+", "250+", "500+"], state: 0),
        ]
    }

    private func buildEHentaiUrl(page: Int, query: String, filters: FilterList) -> String {
        // Calculate f_cats bitmask: sum of EXCLUDED categories
        var excludedCats = 0
        var tagSearch = ""
        var minRating = 0
        var minPages = 0

        for filter in filters {
            switch filter {
            case .group(let name, let children) where name == "Categories":
                for child in children {
                    if case .checkBox(let catName, let isEnabled) = child, !isEnabled {
                        if let cat = ThemeDefinition.ehentaiCategories.first(where: { $0.name == catName }) {
                            excludedCats += cat.value
                        }
                    }
                }
            case .text(let name, let state) where name == "Tags":
                tagSearch = state
            case .select(let name, _, let state) where name == "Minimum Rating":
                let ratings = [0, 2, 3, 4, 5]
                if state < ratings.count { minRating = ratings[state] }
            case .select(let name, _, let state) where name == "Pages":
                let pages = [0, 10, 25, 50, 100, 250, 500]
                if state < pages.count { minPages = pages[state] }
            default:
                break
            }
        }

        // Build search query: combine text query with tag search
        var searchParts: [String] = []
        if !query.isEmpty { searchParts.append(query) }
        if !tagSearch.isEmpty { searchParts.append(tagSearch) }
        let combinedSearch = searchParts.joined(separator: " ").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        var urlStr = baseUrl + "/?page=\(page - 1)&f_cats=\(excludedCats)&f_apply=Apply+Filter"
        if !combinedSearch.isEmpty { urlStr += "&f_search=\(combinedSearch)" }
        if minRating > 0 { urlStr += "&f_sr=on&f_srdd=\(minRating)" }
        if minPages > 0 { urlStr += "&f_sp=on&f_spf=\(minPages)&f_spt=" }

        return urlStr
    }

    private func buildFilteredUrl(page: Int, filters: FilterList, theme: ThemeDefinition) -> String {
        // Resolve available options (theme-defined > auto-detected)
        let sortOpts = !theme.sortOptions.isEmpty ? theme.sortOptions.map { FilterOption(name: $0.name, value: $0.value) } : detectedSortOptions
        let statusOpts = !theme.statusOptions.isEmpty ? theme.statusOptions.map { FilterOption(name: $0.name, value: $0.value) } : detectedStatusOptions
        let genreOpts: [FilterOption]
        if theme.name == "ManhuaGui" {
            genreOpts = ThemeDefinition.manhuaguiGenres.map { FilterOption(name: $0.name, value: $0.value) }
        } else {
            genreOpts = detectedGenres
        }

        var sortValue = sortOpts.first?.value ?? ""
        var statusValue = statusOpts.first?.value ?? ""
        var genreValue = ""

        for filter in filters {
            switch filter {
            case .sort(_, _, let selection):
                if let sel = selection, sel.index < sortOpts.count {
                    sortValue = sortOpts[sel.index].value
                }
            case .select(let name, _, let state):
                if name == "Status", state < statusOpts.count {
                    statusValue = statusOpts[state].value
                } else if name == "Genre" {
                    // state 0 = "All" (no filter), state 1+ maps to genreOpts[state-1]
                    let genreIdx = state - 1
                    if genreIdx >= 0, genreIdx < genreOpts.count {
                        genreValue = genreOpts[genreIdx].value
                    }
                }
            default:
                break
            }
        }

        // Use filter URL pattern if available
        if let pattern = theme.filterUrlPattern {
            var urlStr = baseUrl + pattern
                .replacingOccurrences(of: "{page}", with: "\(page)")
                .replacingOccurrences(of: "{sort}", with: sortValue)
                .replacingOccurrences(of: "{status}", with: statusValue)
                .replacingOccurrences(of: "{genre}", with: genreValue)

            // Clean up empty segments: /list/__/ → /list/, trailing underscores
            while urlStr.contains("__") { urlStr = urlStr.replacingOccurrences(of: "__", with: "_") }
            urlStr = urlStr.replacingOccurrences(of: "/_/", with: "/")
            if urlStr.hasSuffix("_/") { urlStr = String(urlStr.dropLast(2)) + "/" }
            if urlStr.hasSuffix("_") { urlStr = String(urlStr.dropLast()) + "/" }
            return urlStr
        }

        // No filter URL pattern — build URL from auto-detected values using query params
        var urlStr = baseUrl + theme.popularUrlPattern
            .replacingOccurrences(of: "{page}", with: "\(page)")

        var params: [String] = []
        if !sortValue.isEmpty { params.append("order=\(sortValue)") }
        if !statusValue.isEmpty { params.append("status=\(statusValue)") }
        if !genreValue.isEmpty { params.append("genre=\(genreValue)") }

        if !params.isEmpty {
            let separator = urlStr.contains("?") ? "&" : "?"
            urlStr += separator + params.joined(separator: "&")
        }

        return urlStr
    }

    func getMangaDetails(manga: SManga) async throws -> SManga {
        let theme = try await resolveTheme()
        let urlStr = manga.url.hasPrefix("http") ? manga.url : baseUrl + manga.url
        guard let url = URL(string: urlStr) else { return manga }

        let (data, response) = try await fetchWithHeaders(url: url)
        try checkHttpResponse(response)
        guard let html = decodeHtml(data) else { return manga }

        let doc = try SwiftSoup.parse(html)
        var result = manga

        // Try theme-specific selectors first
        if let title = try? doc.select(theme.detailTitleSelector).first()?.text(), !title.isEmpty {
            // Only update title if it looks reasonable (shorter or similar to existing)
            // This avoids overwriting a clean browse title with page noise
            if result.title.isEmpty || title.count <= result.title.count + 10 {
                result.title = title
            }
        }
        if let author = try? doc.select(theme.detailAuthorSelector).first()?.text(),
           !author.isEmpty, author.count < 100 {
            result.author = author
        }
        if let desc = try? doc.select(theme.detailDescriptionSelector).text(), !desc.isEmpty {
            result.description = desc
        }
        if let genres = try? doc.select(theme.detailGenreSelector).array().map({ try $0.text() }),
           !genres.isEmpty {
            result.genre = genres.filter { !$0.isEmpty }
        }
        if let thumbEl = try? doc.select(theme.detailThumbnailSelector).first() {
            result.thumbnailUrl = try extractImageUrl(from: thumbEl)
        }
        if let statusText = try? doc.select(theme.detailStatusSelector).first()?.text() {
            result.status = parseStatus(statusText)
        }

        // If theme selectors found nothing useful, try generic fallback
        let hasDescription = result.description != nil && !(result.description?.isEmpty ?? true)
        let hasGenre = result.genre != nil && !(result.genre?.isEmpty ?? true)
        if !hasDescription && !hasGenre {
            print("[ParsedHttpSource] Theme selectors found no details, trying generic extraction for \(urlStr)")
            extractGenericDetails(doc: doc, result: &result)
        }

        result.initialized = true
        return result
    }

    func getChapterList(manga: SManga) async throws -> [SChapter] {
        let theme = try await resolveTheme()
        let urlStr = manga.url.hasPrefix("http") ? manga.url : baseUrl + manga.url
        guard let url = URL(string: urlStr) else { return [] }

        let (data, response) = try await fetchWithHeaders(url: url)
        try checkHttpResponse(response)
        guard let html = decodeHtml(data) else { return [] }

        let doc = try SwiftSoup.parse(html)

        // Try theme-specific selectors
        let elements = try doc.select(theme.chapterListSelector)
        var chapters = elements.array().compactMap { element -> SChapter? in
            guard let linkEl = try? element.select(theme.chapterUrlSelector).first(),
                  let href = try? linkEl.attr(theme.urlAttribute),
                  !href.isEmpty else { return nil }

            let name = (try? element.select(theme.chapterTitleSelector).first()?.text()) ?? "Chapter"
            let chapterUrl = href.hasPrefix("http") ? href : baseUrl + href

            return SChapter(
                url: chapterUrl,
                name: name,
                dateUpload: 0,
                chapterNumber: extractChapterNumber(from: name)
            )
        }

        // If theme selectors found no chapters, try generic fallback
        if chapters.isEmpty {
            print("[ParsedHttpSource] Theme selectors found no chapters, trying generic extraction for \(urlStr)")
            chapters = extractGenericChapters(doc: doc, mangaUrl: urlStr)
        }

        return chapters
    }

    func getPageList(chapter: SChapter) async throws -> [Page] {
        let theme = try await resolveTheme()
        let urlStr = chapter.url.hasPrefix("http") ? chapter.url : baseUrl + chapter.url
        guard let url = URL(string: urlStr) else {
            debugLog("[PageList] Invalid URL: \(urlStr)")
            return []
        }

        debugLog("[PageList] Loading from: \(urlStr)")
        let (data, response) = try await fetchWithHeaders(url: url)
        try checkHttpResponse(response)

        // Log HTTP status
        if let http = response as? HTTPURLResponse {
            debugLog("[PageList] HTTP \(http.statusCode), \(data.count) bytes")
        }

        guard let html = decodeHtml(data) else {
            debugLog("[PageList] Failed to decode HTML (\(data.count) bytes)")
            return []
        }

        debugLog("[PageList] HTML: \(html.count) chars, theme: \(theme.name)")

        let doc = try SwiftSoup.parse(html)

        // Strategy 1: Try theme-specific selectors
        let images = try doc.select(theme.pageImageSelector)
        var pages = images.array().enumerated().compactMap { index, element -> Page? in
            guard let imgUrl = try? extractImageUrl(from: element),
                  !imgUrl.isEmpty else { return nil }
            return Page(index: index, url: "", imageUrl: imgUrl)
        }
        if !pages.isEmpty {
            debugLog("[PageList] ✅ S1 theme '\(theme.name)': \(pages.count) pages")
            return pages
        }
        debugLog("[PageList] S1 theme selector: 0 pages")

        // Strategy 2: Try ALL theme selectors, not just the detected one
        for altTheme in ThemeDefinition.allThemes where altTheme.name != theme.name {
            if let imgs = try? doc.select(altTheme.pageImageSelector).array(), !imgs.isEmpty {
                let altPages = imgs.enumerated().compactMap { index, element -> Page? in
                    guard let imgUrl = try? extractImageUrl(from: element),
                          !imgUrl.isEmpty else { return nil }
                    return Page(index: index, url: "", imageUrl: imgUrl)
                }
                if !altPages.isEmpty {
                    debugLog("[PageList] ✅ S2 alt theme '\(altTheme.name)': \(altPages.count) pages")
                    return altPages
                }
            }
        }
        debugLog("[PageList] S2 all themes: 0 pages")

        // Strategy 3: Generic HTML image extraction
        pages = extractGenericPages(doc: doc)
        if !pages.isEmpty {
            debugLog("[PageList] ✅ S3 generic HTML: \(pages.count) pages")
            return pages
        }
        debugLog("[PageList] S3 generic HTML: 0 pages")

        // Strategy 4: Extract from JavaScript (many sites embed image URLs in scripts)
        pages = extractPagesFromJavaScript(html: html)
        if !pages.isEmpty {
            debugLog("[PageList] ✅ S4 JavaScript: \(pages.count) pages")
            return pages
        }
        debugLog("[PageList] S4 JavaScript: 0 pages")

        // Strategy 5: Look for encoded/obfuscated data in script tags
        pages = extractPagesFromEncodedScripts(html: html)
        if !pages.isEmpty {
            debugLog("[PageList] ✅ S5 encoded: \(pages.count) pages")
            return pages
        }
        debugLog("[PageList] S5 encoded: 0 pages")

        // Debug: dump what we found in the HTML to help diagnose
        logDebugInfo(doc: doc, html: html)

        debugLog("[PageList] ❌ All strategies failed")
        return pages
    }

    /// Extract image URLs from JavaScript embedded in the page HTML.
    /// Many manga sites (especially Chinese ones) load images dynamically via JS.
    private func extractPagesFromJavaScript(html: String) -> [Page] {
        var pages: [Page] = []
        var seen = Set<String>()

        // ---- Pattern 1: JSON array of image URLs ----
        // Find any JSON array containing image-like URLs:
        //   ["https://cdn.example.com/01.jpg", "https://cdn.example.com/02.jpg"]
        //   or: var images = ["//cdn.example.com/01.jpg", ...]
        let arrayPattern = #"\[\s*["']([^"']*(?:jpg|jpeg|png|gif|webp|bmp|avif)[^"']*)["'](?:\s*,\s*["'][^"']*["'])*\s*\]"#
        if let regex = try? NSRegularExpression(pattern: arrayPattern, options: []) {
            let range = NSRange(html.startIndex..., in: html)
            let matches = regex.matches(in: html, range: range)
            for match in matches {
                let matchStr = String(html[Range(match.range, in: html)!])
                // Extract all quoted strings from this array
                let urlPattern = #"["']([^"']+)["']"#
                if let urlRegex = try? NSRegularExpression(pattern: urlPattern) {
                    let urlRange = NSRange(matchStr.startIndex..., in: matchStr)
                    let urlMatches = urlRegex.matches(in: matchStr, range: urlRange)
                    for urlMatch in urlMatches {
                        if urlMatch.numberOfRanges >= 2, let r = Range(urlMatch.range(at: 1), in: matchStr) {
                            let rawUrl = String(matchStr[r])
                            let resolved = resolveUrl(rawUrl)
                            if !seen.contains(resolved) && looksLikeImageUrl(resolved) {
                                seen.insert(resolved)
                                pages.append(Page(index: pages.count, url: "", imageUrl: resolved))
                            }
                        }
                    }
                }
                if pages.count >= 2 {
                    print("[JS] Pattern 1 matched array with \(pages.count) URLs")
                    break
                }
            }
        }

        // ---- Pattern 2: Image URLs assigned in JS variables or arrays ----
        // e.g.: pic_url = "https://..."; or imageList.push("https://...")
        if pages.isEmpty {
            let imgUrlPattern = #"["']((?:https?:)?//[^"']+?\.(?:jpg|jpeg|png|gif|webp|bmp|avif)(?:\?[^"']*)?)["']"#
            if let regex = try? NSRegularExpression(pattern: imgUrlPattern) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, range: range)
                var candidates: [String] = []
                for match in matches {
                    if match.numberOfRanges >= 2, let urlRange = Range(match.range(at: 1), in: html) {
                        let rawUrl = String(html[urlRange])
                        let resolved = resolveUrl(rawUrl)
                        if looksLikeImageUrl(resolved) {
                            candidates.append(resolved)
                        }
                    }
                }
                // Only use if we found multiple (likely a page list, not just a thumbnail)
                if candidates.count >= 2 {
                    // De-duplicate while preserving order
                    for url in candidates where !seen.contains(url) {
                        seen.insert(url)
                        pages.append(Page(index: pages.count, url: "", imageUrl: url))
                    }
                    print("[JS] Pattern 2 found \(pages.count) image URLs")
                }
            }
        }

        // ---- Pattern 3: path + files combination ----
        // e.g.: "path":"/manga/chapter1/", "files":["001.jpg","002.jpg"]
        // or: SMH.imgData(...).preInit() patterns from ManhuaGui
        if pages.isEmpty {
            var basePath: String?
            // Try multiple key names for the path
            let pathKeys = ["path", "img_prefix", "imgpath", "comic_url", "chapter_url", "base", "host"]
            for key in pathKeys {
                let pattern = "[\"\\']\(key)[\"\\']\\s*[:=]\\s*[\"\\']([^\"\\']*)[\"\\']]"
                if let match = html.range(of: pattern, options: .regularExpression) {
                    let str = String(html[match])
                    let valuePattern = #"[=:]\s*["']([^"']+)["']"#
                    if let valMatch = str.range(of: valuePattern, options: .regularExpression) {
                        let valStr = String(str[valMatch])
                        basePath = valStr.replacingOccurrences(of: #"^[=:]\s*["']"#, with: "", options: .regularExpression)
                            .replacingOccurrences(of: #"["']$"#, with: "", options: .regularExpression)
                        if basePath != nil { break }
                    }
                }
            }

            // Find files array with multiple possible key names
            let fileKeys = ["files", "images", "img_list", "chapterImages", "chapterimage", "pageArray", "fs"]
            for key in fileKeys {
                let pattern = "[\"\\']\(key)[\"\\']\\s*[:=]\\s*\\[([^\\]]*)\\]"
                if let match = html.range(of: pattern, options: .regularExpression) {
                    let filesStr = String(html[match])
                    let filePattern = #"["']([^"']+)["']"#
                    if let fileRegex = try? NSRegularExpression(pattern: filePattern) {
                        let fileRange = NSRange(filesStr.startIndex..., in: filesStr)
                        let fileMatches = fileRegex.matches(in: filesStr, range: fileRange)
                        for fileMatch in fileMatches {
                            if fileMatch.numberOfRanges >= 2, let range = Range(fileMatch.range(at: 1), in: filesStr) {
                                let fileName = String(filesStr[range])
                                // Skip key name itself
                                if fileName == key { continue }
                                var fullUrl: String
                                if let path = basePath {
                                    if path.hasPrefix("http") {
                                        fullUrl = path + (path.hasSuffix("/") ? "" : "/") + fileName
                                    } else {
                                        fullUrl = baseUrl + path + fileName
                                    }
                                } else if fileName.hasPrefix("http") || fileName.hasPrefix("//") {
                                    fullUrl = resolveUrl(fileName)
                                } else {
                                    fullUrl = resolveUrl(fileName)
                                }
                                if !seen.contains(fullUrl) {
                                    seen.insert(fullUrl)
                                    pages.append(Page(index: pages.count, url: "", imageUrl: fullUrl))
                                }
                            }
                        }
                    }
                    if !pages.isEmpty {
                        print("[JS] Pattern 3 found \(pages.count) pages via key '\(key)'")
                        break
                    }
                }
            }
        }

        // ---- Pattern 4: Comma-separated URL list in a variable assignment ----
        // e.g.: var img_list = "url1|url2|url3" or "url1,url2,url3"
        if pages.isEmpty {
            // Look for a string with 3+ image URLs separated by | or ,
            let listPattern = #"["']((?:(?:https?:)?//[^"'|,]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^"'|,]*)?)(?:[|,](?:(?:https?:)?//[^"'|,]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^"'|,]*)?)){2,})["']"#
            if let regex = try? NSRegularExpression(pattern: listPattern) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let r = Range(match.range(at: 1), in: html) {
                    let listStr = String(html[r])
                    let separator = listStr.contains("|") ? "|" : ","
                    let urls = listStr.components(separatedBy: separator)
                    for rawUrl in urls {
                        let resolved = resolveUrl(rawUrl.trimmingCharacters(in: .whitespaces))
                        if !seen.contains(resolved) && looksLikeImageUrl(resolved) {
                            seen.insert(resolved)
                            pages.append(Page(index: pages.count, url: "", imageUrl: resolved))
                        }
                    }
                    if !pages.isEmpty {
                        print("[JS] Pattern 4 found \(pages.count) pages from delimited list")
                    }
                }
            }
        }

        return pages
    }

    /// Check if a URL looks like an image URL (not a logo/icon/avatar).
    private func looksLikeImageUrl(_ url: String) -> Bool {
        let lower = url.lowercased()
        // Must have image extension
        let hasImageExt = lower.contains(".jpg") || lower.contains(".jpeg") ||
            lower.contains(".png") || lower.contains(".gif") || lower.contains(".webp") ||
            lower.contains(".bmp") || lower.contains(".avif")
        if !hasImageExt { return false }
        // Skip obvious non-content images
        if lower.contains("logo") || lower.contains("favicon") || lower.contains("icon") ||
           lower.contains("avatar") || lower.contains("sprite") || lower.contains("button") { return false }
        return true
    }

    /// Strategy 5: Decode obfuscated/encoded image data commonly used by Chinese manga sites.
    /// Supports Dean Edwards packer (used by ManhuaGui, etc.) and base64 encoded data.
    private func extractPagesFromEncodedScripts(html: String) -> [Page] {
        var pages: [Page] = []

        // ---- Pattern A: Dean Edwards Packer ----
        // eval(function(p,a,c,k,e,d){...}('packed_code',base,count,'dict'.split('|'),0,{}))
        // Also handles: window["\x65\x76\x61\x6c"](function(p,a,c,k,e,d){...})
        pages = extractFromPacker(html: html)
        if !pages.isEmpty { return pages }

        // ---- Pattern B: Base64-encoded JSON data ----
        pages = extractFromBase64(html: html)
        if !pages.isEmpty { return pages }

        return pages
    }

    // MARK: - Dean Edwards Packer Decoder

    /// Extract pages from JavaScript packer-obfuscated code.
    /// This is the standard obfuscation used by ManhuaGui and many Chinese manga sites.
    private func extractFromPacker(html: String) -> [Page] {
        // Find packer function body end, then extract args.
        // ManhuaGui uses: window["\x65\x76\x61\x6c"](function(p,a,c,k,e,d){...}('p_val',62,106,'dict'['\x73\x70\x6c\x69\x63']('\x7c'),0,{}))
        // The function signature: function(p,a,c,k,e,d) or function(p,a,c,k,e,r)

        // Step 1: Find the function(p,a,c,k,e,d) pattern
        let funcPattern = #"function\s*\(\s*p\s*,\s*a\s*,\s*c\s*,\s*k\s*,\s*e\s*,\s*\w\s*\)"#
        guard let funcRegex = try? NSRegularExpression(pattern: funcPattern),
              let funcMatch = funcRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let funcRange = Range(funcMatch.range, in: html) else {
            debugLog("[Packer] No packer function signature found")
            return []
        }

        // Step 2: Find the end of function body (matching braces)
        let afterFunc = html[funcRange.upperBound...]
        var depth = 0
        var bodyEnd: String.Index?
        for i in afterFunc.indices {
            if afterFunc[i] == "{" { depth += 1 }
            else if afterFunc[i] == "}" {
                depth -= 1
                if depth == 0 {
                    bodyEnd = afterFunc.index(after: i)
                    break
                }
            }
        }

        guard let bodyEnd else {
            debugLog("[Packer] Failed to find function body end")
            return []
        }

        // Step 3: After the function body, extract the args: ('p_val', base, count, 'dict_val'...)
        let argsStr = String(html[bodyEnd...].prefix(5000))

        // Extract: ('p_val',base,count,'dict_val'
        let argsPattern = #"^\s*\(\s*'([^']+)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([^']+)'"#
        guard let argsRegex = try? NSRegularExpression(pattern: argsPattern, options: [.dotMatchesLineSeparators]),
              let argsMatch = argsRegex.firstMatch(in: argsStr, range: NSRange(argsStr.startIndex..., in: argsStr)),
              argsMatch.numberOfRanges >= 5,
              let pRange = Range(argsMatch.range(at: 1), in: argsStr),
              let aRange = Range(argsMatch.range(at: 2), in: argsStr),
              let cRange = Range(argsMatch.range(at: 3), in: argsStr),
              let kRange = Range(argsMatch.range(at: 4), in: argsStr) else {
            debugLog("[Packer] Failed to extract packer arguments")
            return []
        }

        let p = String(argsStr[pRange])
        let a = Int(argsStr[aRange]) ?? 62
        let c = Int(argsStr[cRange]) ?? 0
        let kRaw = String(argsStr[kRange])

        debugLog("[Packer] Found: p=\(p.count) chars, a=\(a), c=\(c), dictRaw=\(kRaw.count) chars")

        // Step 4: Determine if dictionary is LZString-compressed or pipe-separated
        var kArray: [String]
        if kRaw.contains("|") && kRaw.components(separatedBy: "|").count > 5 {
            // Plain pipe-separated dictionary
            kArray = kRaw.components(separatedBy: "|")
            debugLog("[Packer] Dict: plain pipe-separated, \(kArray.count) words")
        } else {
            // Likely LZString compressed — try decompressing
            if let decompressed = LZString.decompressFromBase64(kRaw), !decompressed.isEmpty {
                kArray = decompressed.components(separatedBy: "|")
                debugLog("[Packer] Dict: LZString decompressed, \(kArray.count) words")
                debugLog("[Packer] First 15 words: \(kArray.prefix(15).joined(separator: ", "))")
            } else {
                // Fallback: try as plain
                kArray = kRaw.components(separatedBy: "|")
                debugLog("[Packer] Dict: LZString failed, using raw, \(kArray.count) words")
            }
        }

        guard kArray.count > 1 else {
            debugLog("[Packer] Dictionary too small: \(kArray.count)")
            return []
        }

        // Step 5: Unpack
        let unpacked = unpackJsPacker(packed: p, base: a, count: c, dict: kArray)
        debugLog("[Packer] Unpacked: \(unpacked.count) chars")
        debugLog("[Packer] Preview: \(String(unpacked.prefix(300)))")

        // Step 6: Extract image data from unpacked code
        return extractPagesFromUnpackedCode(unpacked)
    }

    /// Dean Edwards packer decoder: replaces base-N encoded tokens with dictionary words.
    private func unpackJsPacker(packed: String, base: Int, count: Int, dict: [String]) -> String {
        var result = packed

        // Build replacement function: encode index to base-N string
        func encode(_ c: Int) -> String {
            let prefix = c >= base ? encode(c / base) : ""
            let remainder = c % base
            let char: String
            if remainder >= 36 {
                char = String(UnicodeScalar(remainder + 29)!)
            } else if remainder >= 10 {
                char = String(UnicodeScalar(remainder + 87)!)  // a-z
            } else {
                char = String(remainder)
            }
            return prefix + char
        }

        // Replace each token (going from highest to lowest to avoid partial replacements)
        for i in stride(from: dict.count - 1, through: 0, by: -1) {
            let word = dict[i]
            if word.isEmpty { continue }
            let token = encode(i)
            // Replace whole-word matches
            let wordBoundary = "\\b\(NSRegularExpression.escapedPattern(for: token))\\b"
            if let tokenRegex = try? NSRegularExpression(pattern: wordBoundary) {
                result = tokenRegex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: NSRegularExpression.escapedTemplate(for: word)
                )
            }
        }

        return result
    }

    /// Extract page image URLs from unpacked JavaScript code.
    /// Handles ManhuaGui's SMH.reader({...}) / SMH.imgData({...}) format and other common patterns.
    private func extractPagesFromUnpackedCode(_ code: String) -> [Page] {
        var pages: [Page] = []
        var seen = Set<String>()

        // Try to find SMH.reader({...}) or SMH.imgData({...}) — ManhuaGui format
        // The JSON may contain nested objects like "sl":{"e":...,"m":"..."}
        // so we can't use [^{}]* — instead match from { to the end of the JSON using brace counting
        let jsonKeys = ["images", "files", "pages", "pics", "list"]
        for key in jsonKeys {
            let searchPattern = "\"\(key)\""
            if let keyRange = code.range(of: searchPattern) {
                // Walk backwards to find the opening {
                if let jsonStr = extractJsonObject(from: code, containing: keyRange.lowerBound) {
                    debugLog("[Packer] Found '\(key)' JSON (\(jsonStr.count) chars): \(String(jsonStr.prefix(150)))")
                    let extracted = extractPagesFromImgDataJson(jsonStr)
                    if !extracted.isEmpty { return extracted }
                }
            }
        }

        // Fallback: extract any image-like URLs from the unpacked code
        let urlPattern = #"(?:https?:)?//[^"'\s<>\\]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^"'\s<>\\]*)?"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let range = NSRange(code.startIndex..., in: code)
            for match in regex.matches(in: code, range: range) {
                if let r = Range(match.range, in: code) {
                    let url = resolveUrl(String(code[r]))
                    if !seen.contains(url) && looksLikeImageUrl(url) {
                        seen.insert(url)
                        pages.append(Page(index: pages.count, url: "", imageUrl: url))
                    }
                }
            }
        }

        // Also try image paths (like /ps4/q/...)
        if pages.isEmpty {
            let pathPattern = #""(/[^"]+\.(?:jpg|jpeg|png|gif|webp)(?:\?[^"]*)?)""#
            if let regex = try? NSRegularExpression(pattern: pathPattern) {
                let range = NSRange(code.startIndex..., in: code)
                for match in regex.matches(in: code, range: range) {
                    if match.numberOfRanges >= 2, let r = Range(match.range(at: 1), in: code) {
                        let path = String(code[r])
                        // Build full URL from path
                        let url = "https://i.hamreus.com" + path
                        if !seen.contains(url) {
                            seen.insert(url)
                            pages.append(Page(index: pages.count, url: "", imageUrl: url))
                        }
                    }
                }
            }
        }

        if !pages.isEmpty {
            debugLog("[Packer] Extracted \(pages.count) pages from unpacked code")
        }
        return pages
    }

    /// Extract a JSON object from code, given a position inside it.
    /// Walks backwards to find `{`, then forward counting braces to find matching `}`.
    private func extractJsonObject(from code: String, containing pos: String.Index) -> String? {
        // Walk backwards to find the opening {
        var start = pos
        var depth = 0
        while start > code.startIndex {
            start = code.index(before: start)
            if code[start] == "}" { depth += 1 }
            else if code[start] == "{" {
                if depth == 0 { break }
                depth -= 1
            }
        }
        guard code[start] == "{" else { return nil }

        // Walk forwards to find the matching }
        depth = 0
        var end = start
        while end < code.endIndex {
            if code[end] == "{" { depth += 1 }
            else if code[end] == "}" {
                depth -= 1
                if depth == 0 {
                    return String(code[start...end])
                }
            }
            end = code.index(after: end)
        }
        return nil
    }

    /// Parse ManhuaGui's reader/imgData JSON format:
    /// {"images":["/path/001.jpg",...], "sl":{"e":...,"m":"..."}} — SMH.reader()
    /// {"files":["/path/001.jpg",...], "sl":{"e":...,"m":"..."}}  — SMH.imgData()
    private func extractPagesFromImgDataJson(_ jsonStr: String) -> [Page] {
        var pages: [Page] = []

        // Extract image array — try "images" first (SMH.reader), then "files" (SMH.imgData)
        let arrayPattern = #""(?:images|files)"\s*:\s*\[([^\]]+)\]"#
        guard let filesRange = jsonStr.range(of: arrayPattern, options: .regularExpression) else {
            debugLog("[ImgData] No images/files array found")
            return pages
        }
        let filesContent = String(jsonStr[filesRange])

        // Extract individual file paths
        let filePattern = #""([^"]+)""#
        guard let fileRegex = try? NSRegularExpression(pattern: filePattern) else { return pages }
        let fileRange = NSRange(filesContent.startIndex..., in: filesContent)
        var filePaths: [String] = []
        for match in fileRegex.matches(in: filesContent, range: fileRange) {
            if match.numberOfRanges >= 2, let r = Range(match.range(at: 1), in: filesContent) {
                let file = String(filesContent[r])
                if file != "files" && file != "images" { filePaths.append(file) }
            }
        }

        debugLog("[ImgData] Found \(filePaths.count) file paths")
        if filePaths.isEmpty { return pages }

        // Extract auth params from "sl":{"e":...,"m":"..."}
        var authSuffix = ""
        if let slRange = jsonStr.range(of: #""sl"\s*:\s*\{([^}]+)\}"#, options: .regularExpression) {
            let slContent = String(jsonStr[slRange])
            var e = "", m = ""
            if let eRange = slContent.range(of: #""e"\s*:\s*(\d+)"#, options: .regularExpression) {
                let eStr = String(slContent[eRange])
                if let numRange = eStr.range(of: #"\d+"#, options: .regularExpression) {
                    e = String(eStr[numRange])
                }
            }
            if let mRange = slContent.range(of: #""m"\s*:\s*"([^"]+)""#, options: .regularExpression) {
                let mStr = String(slContent[mRange])
                if let valRange = mStr.range(of: #":\s*"([^"]+)""#, options: .regularExpression) {
                    m = String(mStr[valRange]).replacingOccurrences(of: #"^:\s*""#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\"", with: "")
                }
            }
            if !e.isEmpty && !m.isEmpty {
                authSuffix = "?e=\(e)&m=\(m)"
                debugLog("[ImgData] Auth: e=\(e), m=\(m.prefix(10))...")
            }
        }

        // ManhuaGui CDN domains
        let cdnDomains = [
            "https://i.hamreus.com",
            "https://us.hamreus.com",
            "https://eu.hamreus.com",
        ]
        let cdnBase = cdnDomains[0]

        // Build full image URLs.
        // File paths from packed JS may be multi-level percent-encoded (e.g. %25E6 = double-encoded).
        // Fully decode, then re-encode exactly once so the CDN gets clean URLs.
        for (index, rawPath) in filePaths.enumerated() {
            // Fully decode: loop until stable (handles double/triple encoding)
            var decoded = rawPath
            while let next = decoded.removingPercentEncoding, next != decoded {
                decoded = next
            }

            // Re-encode the path portion only (non-ASCII + unsafe chars)
            let encodedPath = decoded.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? decoded

            let fullUrl: String
            if decoded.hasPrefix("http") {
                // Full URL — re-encode the whole thing properly
                fullUrl = Self.properlyEncodeUrl(decoded) + authSuffix
            } else if encodedPath.hasPrefix("/") {
                fullUrl = cdnBase + encodedPath + authSuffix
            } else {
                fullUrl = cdnBase + "/" + encodedPath + authSuffix
            }

            if index == 0 {
                debugLog("[ImgData] Raw path: \(rawPath.prefix(80))")
                debugLog("[ImgData] Decoded:  \(decoded.prefix(80))")
                debugLog("[ImgData] Final URL: \(fullUrl.prefix(120))")
            }
            pages.append(Page(index: index, url: "", imageUrl: fullUrl))
        }

        debugLog("[ImgData] Built \(pages.count) page URLs (CDN: \(cdnBase))")
        return pages
    }

    /// Extract pages from base64-encoded data in the HTML.
    private func extractFromBase64(html: String) -> [Page] {
        var pages: [Page] = []
        var seen = Set<String>()

        let base64Pattern = #"(?:atob|decode|Base64\.decode)\s*\(\s*["']([A-Za-z0-9+/=]{20,})["']"#
        if let regex = try? NSRegularExpression(pattern: base64Pattern) {
            let range = NSRange(html.startIndex..., in: html)
            for match in regex.matches(in: html, range: range) {
                if match.numberOfRanges >= 2, let r = Range(match.range(at: 1), in: html) {
                    let b64 = String(html[r])
                    if let data = Data(base64Encoded: b64),
                       let decoded = String(data: data, encoding: .utf8) {
                        let urlPattern = #"(?:https?:)?//[^\s"'<>]+\.(?:jpg|jpeg|png|gif|webp)"#
                        if let urlRegex = try? NSRegularExpression(pattern: urlPattern) {
                            let decRange = NSRange(decoded.startIndex..., in: decoded)
                            for urlMatch in urlRegex.matches(in: decoded, range: decRange) {
                                if let ur = Range(urlMatch.range, in: decoded) {
                                    let resolved = resolveUrl(String(decoded[ur]))
                                    if !seen.contains(resolved) {
                                        seen.insert(resolved)
                                        pages.append(Page(index: pages.count, url: "", imageUrl: resolved))
                                    }
                                }
                            }
                        }
                    }
                }
                if pages.count >= 2 { break }
            }
        }
        return pages
    }

    /// Decode \\xNN and \\uNNNN escape sequences
    private func decodeEscapedString(_ s: String) -> String {
        var result = s
        // \\xNN → character
        let hexPat = #"\\x([0-9a-fA-F]{2})"#
        if let regex = try? NSRegularExpression(pattern: hexPat) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let code = UInt8(result[hexRange], radix: 16) {
                    let char = String(UnicodeScalar(code))
                    result.replaceSubrange(Range(match.range, in: result)!, with: char)
                }
            }
        }
        // \\uNNNN → character
        let uniPat = #"\\u([0-9a-fA-F]{4})"#
        if let regex = try? NSRegularExpression(pattern: uniPat) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[hexRange], radix: 16),
                   let scalar = UnicodeScalar(code) {
                    result.replaceSubrange(Range(match.range, in: result)!, with: String(scalar))
                }
            }
        }
        return result
    }

    /// Log debug info to help diagnose page extraction failures.
    private func logDebugInfo(doc: Document, html: String) {
        debugLog("[Debug] === 解析失敗診斷 ===")

        // Count images in HTML
        let imgCount = (try? doc.select("img").size()) ?? 0
        debugLog("[Debug] <img> 標籤數: \(imgCount)")

        // List first 5 img src values
        if let imgs = try? doc.select("img").array().prefix(5) {
            for (i, img) in imgs.enumerated() {
                let src = (try? img.attr("src")) ?? "(none)"
                let dataSrc = (try? img.attr("data-src")) ?? "(none)"
                debugLog("[Debug] img[\(i)]: src=\(src.prefix(80)) data-src=\(dataSrc.prefix(80))")
            }
        }

        // Count script tags and look for image-related content
        if let scripts = try? doc.select("script").array() {
            debugLog("[Debug] <script> 標籤數: \(scripts.count)")
            for (i, script) in scripts.enumerated() {
                let text = (try? script.html()) ?? ""
                if text.contains(".jpg") || text.contains(".png") || text.contains(".webp") || text.contains("image") {
                    debugLog("[Debug] script[\(i)] 含圖片 (\(text.count)字): \(String(text.prefix(150)))")
                }
            }
        }

        // Check for iframes
        let iframeCount = (try? doc.select("iframe").size()) ?? 0
        if iframeCount > 0 {
            debugLog("[Debug] ⚠️ 發現 \(iframeCount) 個 iframe（閱讀器可能在 iframe 內）")
            if let iframes = try? doc.select("iframe").array().prefix(3) {
                for iframe in iframes {
                    let src = (try? iframe.attr("src")) ?? "(none)"
                    debugLog("[Debug] iframe src: \(src)")
                }
            }
        }

        // Check for canvas
        let canvasCount = (try? doc.select("canvas").size()) ?? 0
        if canvasCount > 0 {
            debugLog("[Debug] ⚠️ 發現 \(canvasCount) 個 canvas（圖片可能渲染在 canvas 上）")
        }

        // HTML title
        let title = (try? doc.title()) ?? "(none)"
        debugLog("[Debug] 頁面標題: \(title)")

        // Body snippet
        let bodyText = String((try? doc.body()?.text().prefix(300)) ?? "")
        debugLog("[Debug] 內文: \(bodyText)")
        debugLog("[Debug] === 診斷結束 ===")
    }

    // MARK: - Multi-theme Fallback

    private enum BrowseMode {
        case popular, latest
    }

    /// Try all themes in sequence; return the first that yields results.
    private func fallbackAllThemes(page: Int, mode: BrowseMode) async throws -> MangasPage {
        // First: try smart extraction from cached homepage HTML (fastest, no network needed)
        if let cachedHtml = cachedHomepageHtml,
           let result = try? extractMangaFromGenericHtml(cachedHtml),
           !result.mangas.isEmpty {
            print("[ParsedHttpSource] Smart extraction found \(result.mangas.count) entries from homepage for \(baseUrl)")
            return result
        }

        // Second: try all theme-specific URL patterns
        let themesToTry = ThemeDefinition.allThemes + [ThemeDefinition.generic]

        for candidate in themesToTry {
            // Skip the theme we already tried
            if candidate.name == self.theme?.name { continue }

            let urlPattern: String
            switch mode {
            case .popular: urlPattern = candidate.popularUrlPattern
            case .latest: urlPattern = candidate.latestUrlPattern
            }

            let urlStr = baseUrl + urlPattern.replacingOccurrences(of: "{page}", with: "\(page)")
            if let result = try? await fetchMangaList(urlStr: urlStr, theme: candidate),
               !result.mangas.isEmpty {
                // Found a working theme — cache it for future requests
                print("[ParsedHttpSource] Fallback matched theme \(candidate.name) for \(baseUrl)")
                self.theme = candidate
                return result
            }
        }

        // Third: if we haven't fetched the homepage yet, fetch it and try smart extraction
        if cachedHomepageHtml == nil, let url = URL(string: baseUrl) {
            if let (data, _) = try? await fetchWithHeaders(url: url),
               let html = decodeHtml(data) {
                cachedHomepageHtml = html
                if let result = try? extractMangaFromGenericHtml(html),
                   !result.mangas.isEmpty {
                    return result
                }
            }
        }

        let host = URL(string: baseUrl)?.host ?? baseUrl
        throw ScrapingError.noResults(host)
    }

    // MARK: - Theme Resolution

    private func resolveTheme() async throws -> ThemeDefinition {
        if let theme { return theme }

        let detected = try await detectTheme()
        self.theme = detected

        // Auto-detect filters from cached homepage
        if detectedGenres.isEmpty, let html = cachedHomepageHtml {
            detectFiltersFromHtml(html: html, theme: detected)
        }

        return detected
    }

    private func detectTheme() async throws -> ThemeDefinition {
        guard let url = URL(string: baseUrl) else {
            return .madara
        }

        let (data, response) = try await fetchWithHeaders(url: url)
        try checkHttpResponse(response)

        guard let html = decodeHtml(data) else {
            return .madara
        }

        // Cache homepage for potential generic fallback
        cachedHomepageHtml = html
        let lowered = html.lowercased()

        // Cloudflare detection
        if lowered.contains("cf-browser-verification") || lowered.contains("cloudflare")
            && lowered.contains("challenge-platform") {
            let host = url.host ?? baseUrl
            throw ScrapingError.cloudflareBlocked(host)
        }

        // Madara markers
        if lowered.contains("madara") || lowered.contains("wp-manga") ||
           lowered.contains("class=\"manga-genres") || lowered.contains("class=\"page-item-detail") {
            print("[ThemeDetector] Detected Madara for \(baseUrl)")
            return .madara
        }

        // MangaThemesia markers
        if lowered.contains("themesia") || lowered.contains("mangathemesia") ||
           lowered.contains("class=\"bsx\"") || lowered.contains("class=\"listupd\"") ||
           lowered.contains("ts-post-image") || lowered.contains("class=\"bs\"") {
            print("[ThemeDetector] Detected MangaThemesia for \(baseUrl)")
            return .mangaThemesia
        }

        // Mangabox markers
        if lowered.contains("mangakakalot") || lowered.contains("manganato") ||
           lowered.contains("chapmanganato") || lowered.contains("content-genres-item") ||
           lowered.contains("panel-search-story") || lowered.contains("navi-change-chapter") {
            print("[ThemeDetector] Detected Mangabox for \(baseUrl)")
            return .mangabox
        }

        // FMReader markers
        if lowered.contains("fmreader") || lowered.contains("thumb-item-flow") {
            print("[ThemeDetector] Detected FMReader for \(baseUrl)")
            return .fmreader
        }

        // Grouple markers
        if lowered.contains("grouple") || lowered.contains("readmanga") || lowered.contains("mintmanga") {
            print("[ThemeDetector] Detected Grouple for \(baseUrl)")
            return .grouple
        }

        // ManhuaGui markers
        if lowered.contains("manhuagui") || lowered.contains("mhgui") || lowered.contains("看漫画") ||
           lowered.contains("class=\"main-list\"") || lowered.contains("class=\"cont-list\"") {
            print("[ThemeDetector] Detected ManhuaGui for \(baseUrl)")
            return .manhuagui
        }

        // E-Hentai markers
        if lowered.contains("e-hentai") || lowered.contains("ehentai") || lowered.contains("exhentai") ||
           lowered.contains("f_cats") || lowered.contains("class=\"itg\"") ||
           lowered.contains("hentai galleries") {
            print("[ThemeDetector] Detected EHentai for \(baseUrl)")
            return .ehentai
        }

        // Try matching selector patterns against the homepage HTML
        if let doc = try? SwiftSoup.parse(html) {
            for theme in ThemeDefinition.allThemes {
                let items = try? doc.select(theme.mangaListSelector)
                if let items, items.size() > 0 {
                    print("[ThemeDetector] Matched theme \(theme.name) by selector for \(baseUrl)")
                    return theme
                }
            }
        }

        // Default to Madara (most common); fallback will try others if this fails
        print("[ThemeDetector] No theme detected for \(baseUrl), starting with Madara (fallback enabled)")
        return .madara
    }

    /// Detect genre links from the homepage HTML (nav menus, sidebars, genre lists).
    /// Parse homepage/listing HTML to auto-detect filters (genres, sort, status).
    private func detectFiltersFromHtml(html: String, theme: ThemeDefinition) {
        guard let doc = try? SwiftSoup.parse(html) else { return }

        // --- 1. Detect genres from navigation links ---
        let genreSelectors = [
            // Explicit genre/category containers
            "ul.genres a, ul.genre a, ul.genre-list a",
            "div.genres a, div.genre-list a, div.tag-links a",
            "ul.cat-list a, ul.categories a",
            "li.cat-item a",
            // Links with genre/category/tag in URL
            "a[href*=genre], a[href*=category], a[href*=tag]",
            "a[href*=list][href*=/]",
            // Sidebar and nav
            "ul.manga-cat a, div.sidebar a[href*=genre]",
            "nav a[href*=genre], nav a[href*=category]",
            // Select options for genre
            "select[name*=genre] option, select[name*=category] option, select[name*=type] option",
        ]

        var genres: [FilterOption] = []
        let seenGenres = NSMutableSet()
        // Skip common non-genre link text
        let skipNames: Set<String> = ["home", "首页", "all", "全部", "manga", "漫画", "comic", "login", "register",
                                       "bookmark", "history", "search", "about", "contact", "dmca", "privacy"]

        for selector in genreSelectors {
            guard let elements = try? doc.select(selector) else { continue }
            for el in elements.array() {
                let name: String
                let value: String

                if el.tagName() == "option" {
                    // <option value="xxx">Name</option>
                    guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                          let val = try? el.attr("value") else { continue }
                    name = text
                    value = val
                } else {
                    // <a href="...">Name</a>
                    guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                          let href = try? el.attr("href") else { continue }
                    name = text
                    // Extract slug from URL
                    if let urlObj = URL(string: href), let lastPath = urlObj.pathComponents.last, lastPath != "/" {
                        value = lastPath
                    } else {
                        value = text.lowercased().replacingOccurrences(of: " ", with: "-")
                    }
                }

                guard name.count >= 2, name.count < 50,
                      name.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }),
                      !seenGenres.contains(name.lowercased()),
                      !skipNames.contains(name.lowercased()) else { continue }
                seenGenres.add(name.lowercased())
                genres.append(FilterOption(name: name, value: value))
            }
            if genres.count >= 5 { break }
        }

        // --- 2. Detect sort options from <select> or links ---
        let sortSelectors = [
            "select[name*=order] option, select[name*=sort] option, select[name*=orderby] option",
            "ul.sort a, div.sort a, div.filter-sort a",
            "a[href*=order], a[href*=sort], a[href*=orderby]",
        ]

        var sortOpts: [FilterOption] = []
        let seenSort = NSMutableSet()

        for selector in sortSelectors {
            guard let elements = try? doc.select(selector) else { continue }
            for el in elements.array() {
                let name: String
                let value: String

                if el.tagName() == "option" {
                    guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                          let val = try? el.attr("value"), !val.isEmpty else { continue }
                    name = text; value = val
                } else {
                    guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                          let href = try? el.attr("href") else { continue }
                    name = text
                    // Try to extract sort value from URL query params
                    if let urlObj = URL(string: href),
                       let comps = URLComponents(url: urlObj, resolvingAgainstBaseURL: false),
                       let sortParam = comps.queryItems?.first(where: { ["order", "sort", "orderby", "m_orderby", "sortType", "type"].contains($0.name) })?.value {
                        value = sortParam
                    } else if let lastPath = URL(string: href)?.pathComponents.last, lastPath != "/" {
                        value = lastPath
                    } else {
                        continue
                    }
                }

                guard name.count >= 2, name.count < 40,
                      !seenSort.contains(name.lowercased()) else { continue }
                seenSort.add(name.lowercased())
                sortOpts.append(FilterOption(name: name, value: value))
            }
            if sortOpts.count >= 3 { break }
        }

        // --- 3. Detect status options from <select> or links ---
        let statusSelectors = [
            "select[name*=status] option, select[name*=state] option",
            "a[href*=status], a[href*=state]",
        ]

        var statusOpts: [FilterOption] = []
        let seenStatus = NSMutableSet()

        for selector in statusSelectors {
            guard let elements = try? doc.select(selector) else { continue }
            for el in elements.array() {
                let name: String
                let value: String

                if el.tagName() == "option" {
                    guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                          let val = try? el.attr("value") else { continue }
                    name = text; value = val
                } else {
                    guard let text = try? el.text().trimmingCharacters(in: .whitespacesAndNewlines),
                          let href = try? el.attr("href") else { continue }
                    name = text
                    if let urlObj = URL(string: href),
                       let comps = URLComponents(url: urlObj, resolvingAgainstBaseURL: false),
                       let statusParam = comps.queryItems?.first(where: { ["status", "state"].contains($0.name) })?.value {
                        value = statusParam
                    } else if let lastPath = URL(string: href)?.pathComponents.last, lastPath != "/" {
                        value = lastPath
                    } else {
                        continue
                    }
                }

                guard name.count >= 2, name.count < 40,
                      !seenStatus.contains(name.lowercased()) else { continue }
                seenStatus.add(name.lowercased())
                statusOpts.append(FilterOption(name: name, value: value))
            }
            if statusOpts.count >= 2 { break }
        }

        // Store results
        if !genres.isEmpty {
            detectedGenres = genres
            print("[ParsedHttpSource] Detected \(genres.count) genres for \(baseUrl)")
        }
        if !sortOpts.isEmpty {
            detectedSortOptions = sortOpts
            print("[ParsedHttpSource] Detected \(sortOpts.count) sort options for \(baseUrl)")
        }
        if !statusOpts.isEmpty {
            detectedStatusOptions = statusOpts
            print("[ParsedHttpSource] Detected \(statusOpts.count) status options for \(baseUrl)")
        }
    }

    // MARK: - HTML Parsing

    private func fetchMangaList(urlStr: String, theme: ThemeDefinition) async throws -> MangasPage {
        guard let url = URL(string: urlStr) else {
            return MangasPage(mangas: [], hasNextPage: false)
        }

        let (data, response) = try await fetchWithHeaders(url: url)
        try checkHttpResponse(response)

        guard let html = decodeHtml(data) else {
            return MangasPage(mangas: [], hasNextPage: false)
        }

        let doc = try SwiftSoup.parse(html)
        let elements = try doc.select(theme.mangaListSelector)

        var mangas: [SManga] = []
        for element in elements.array() {
            guard let linkEl = try? element.select(theme.mangaUrlSelector).first() ?? element.select("a").first(),
                  let href = try? linkEl.attr(theme.urlAttribute),
                  !href.isEmpty,
                  href != "#" else { continue }

            let title: String
            // Try title attribute first, then specific selector, then link text
            if let titleAttr = try? linkEl.attr("title"), !titleAttr.isEmpty {
                title = titleAttr
            } else if let titleText = try? element.select(theme.mangaTitleSelector).first()?.text(), !titleText.isEmpty {
                title = titleText
            } else if let linkText = try? linkEl.text(), !linkText.isEmpty {
                title = linkText
            } else {
                continue
            }

            // Skip very short titles (likely navigation elements)
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedTitle.count > 1 else { continue }

            let mangaUrl = href.hasPrefix("http") ? href : baseUrl + href

            var thumbnailUrl: String?
            if let imgEl = try? element.select(theme.mangaThumbnailSelector).first() {
                thumbnailUrl = try? extractImageUrl(from: imgEl)
            }

            mangas.append(SManga(
                url: mangaUrl,
                title: trimmedTitle,
                thumbnailUrl: thumbnailUrl
            ))
        }

        let hasNext = (try? doc.select(theme.nextPageSelector).first()) != nil
        return MangasPage(mangas: mangas, hasNextPage: hasNext && !mangas.isEmpty)
    }

    /// Smart extraction: analyzes the DOM for repeated (link + image) patterns
    /// that look like a manga/gallery listing. Works on most site structures.
    private func extractMangaFromGenericHtml(_ html: String) throws -> MangasPage {
        let doc = try SwiftSoup.parse(html)
        var mangas: [SManga] = []
        var seen = Set<String>()

        struct MangaCandidate {
            let href: String
            let title: String
            let thumbnailUrl: String?
        }

        var candidates: [MangaCandidate] = []

        // ── Strategy 1: Table rows (e.g., e-hentai, nhentai table view) ──
        // Each <tr> may have link and image in different <td> cells.
        let rows = try doc.select("tr").array()
        for row in rows {
            let links = try row.select("a[href]").array()
            let images = try row.select("img").array()
            guard !links.isEmpty && !images.isEmpty else { continue }

            // Find the best link (longest text or has title attribute, skip nav links)
            var bestHref: String?
            var bestTitle: String?
            for link in links {
                guard let href = try? link.attr("href"),
                      !href.isEmpty, href != "#",
                      !href.hasPrefix("javascript:") else { continue }
                let lh = href.lowercased()
                if lh.contains("login") || lh.contains("register") || lh.contains("popup") { continue }

                let title: String?
                if let t = try? link.attr("title"), !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = t.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let glink = try? link.select("[class*=link], [class*=title], [class*=name]").first()?.text(),
                          !glink.isEmpty {
                    title = glink
                } else if let t = try? link.text(), t.trimmingCharacters(in: .whitespacesAndNewlines).count > 2 {
                    title = t.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    title = nil
                }

                // Prefer links with longer titles (more likely the main content link)
                if let title, (bestTitle == nil || title.count > (bestTitle?.count ?? 0)) {
                    bestHref = href
                    bestTitle = title
                }
            }

            guard let href = bestHref, let title = bestTitle else { continue }
            let fullUrl = href.hasPrefix("http") ? href : baseUrl + (href.hasPrefix("/") ? href : "/\(href)")

            // Get thumbnail from any image in the row
            var thumbnailUrl: String?
            for img in images {
                if let url = try? extractImageUrl(from: img), !url.isEmpty,
                   !url.contains("td.png"), !url.contains("star"), !url.contains("icon") {
                    thumbnailUrl = url
                    break
                }
            }

            candidates.append(MangaCandidate(href: fullUrl, title: String(title.prefix(200)), thumbnailUrl: thumbnailUrl))
        }

        // ── Strategy 2: Links containing images (div/list-based layouts) ──
        if candidates.isEmpty {
            let allLinks = try doc.select("a[href]").array()
            for link in allLinks {
                guard let href = try? link.attr("href"),
                      !href.isEmpty, href != "#", href != "/",
                      !href.hasPrefix("javascript:"), !href.hasPrefix("mailto:") else { continue }

                // Check for image inside the link or in immediate parent
                let hasImg = (try? link.select("img").first()) != nil
                let hasImgNearby: Bool
                if !hasImg, let parent = link.parent() {
                    hasImgNearby = (try? parent.select("img").first()) != nil
                } else {
                    hasImgNearby = false
                }
                guard hasImg || hasImgNearby else { continue }

                let fullUrl = href.hasPrefix("http") ? href : baseUrl + (href.hasPrefix("/") ? href : "/\(href)")
                let lowerHref = href.lowercased()
                if lowerHref.hasSuffix("/") && lowerHref.count < 5 { continue }
                if lowerHref.contains("login") || lowerHref.contains("register") ||
                   lowerHref.contains("signup") || lowerHref.contains("account") { continue }

                let title: String
                if let t = try? link.attr("title"), !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = t.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let img = try? link.select("img").first(), let alt = try? img.attr("alt"), !alt.isEmpty {
                    title = alt.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let text = try? link.text(), text.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 {
                    title = text.trimmingCharacters(in: .whitespacesAndNewlines)
                } else {
                    continue
                }

                var thumbnailUrl: String?
                if let img = try? link.select("img").first() {
                    thumbnailUrl = try? extractImageUrl(from: img)
                } else if let parent = link.parent(), let img = try? parent.select("img").first() {
                    thumbnailUrl = try? extractImageUrl(from: img)
                }

                candidates.append(MangaCandidate(href: fullUrl, title: String(title.prefix(200)), thumbnailUrl: thumbnailUrl))
            }
        }

        // ── Strategy 3: URL path pattern detection ──
        // Find the dominant path pattern and filter candidates to it.
        let pathPatterns = candidates.compactMap { c -> String? in
            guard let url = URL(string: c.href) else { return nil }
            let comps = url.pathComponents.filter { $0 != "/" }
            return comps.first
        }
        let patternCounts = Dictionary(grouping: pathPatterns) { $0 }.mapValues { $0.count }
        let dominantPattern = patternCounts.max(by: { $0.value < $1.value })

        let filtered: [MangaCandidate]
        if let pattern = dominantPattern, pattern.value >= 3 {
            filtered = candidates.filter { c in
                guard let url = URL(string: c.href) else { return false }
                return url.pathComponents.filter { $0 != "/" }.first == pattern.key
            }
        } else {
            filtered = candidates
        }

        for c in filtered {
            guard !seen.contains(c.href), c.title.count > 1 else { continue }
            seen.insert(c.href)
            mangas.append(SManga(url: c.href, title: c.title, thumbnailUrl: c.thumbnailUrl))
        }

        // ── Strategy 4: Broad link search by common path keywords ──
        if mangas.isEmpty {
            let commonPaths = ["/manga/", "/comic/", "/series/", "/title/", "/g/",
                               "/read/", "/gallery/", "/book/", "/view/",
                               "/doujinshi/", "/webtoon/", "/manhua/", "/manhwa/"]

            for link in try doc.select("a[href]").array() {
                guard let href = try? link.attr("href"), !href.isEmpty, href != "#",
                      commonPaths.contains(where: { href.contains($0) }) else { continue }

                let fullUrl = href.hasPrefix("http") ? href : baseUrl + (href.hasPrefix("/") ? href : "/\(href)")
                guard !seen.contains(fullUrl) else { continue }
                seen.insert(fullUrl)

                let title: String
                if let t = try? link.attr("title"), !t.isEmpty { title = t }
                else if let t = try? link.text(), t.count > 2 { title = t }
                else { continue }

                var thumbnailUrl: String?
                if let img = try? link.select("img").first() { thumbnailUrl = try? extractImageUrl(from: img) }
                else if let p = link.parent(), let img = try? p.select("img").first() { thumbnailUrl = try? extractImageUrl(from: img) }

                mangas.append(SManga(url: fullUrl, title: title.trimmingCharacters(in: .whitespacesAndNewlines), thumbnailUrl: thumbnailUrl))
            }
        }

        let hasNext = (try? doc.select("a.next, a[rel=next], a:contains(Next), a:contains(>), a.nav-next, td.ptb a:last-child, a[onclick*=next]").first()) != nil
        return MangasPage(mangas: mangas, hasNextPage: hasNext && !mangas.isEmpty)
    }

    // MARK: - Generic Detail Extraction

    /// Extract manga details using common HTML patterns when theme selectors fail.
    private func extractGenericDetails(doc: Document, result: inout SManga) {
        // Title: og:title, <h1>, or <title>
        // Don't overwrite existing title from browse (usually more reliable)

        // Description: og:description, meta description, or common description containers
        if result.description == nil || result.description?.isEmpty == true {
            let descSelectors = [
                "meta[property=og:description]",
                "meta[name=description]",
                "meta[name=Description]",
            ]
            for sel in descSelectors {
                if let content = try? doc.select(sel).first()?.attr("content"),
                   !content.isEmpty {
                    result.description = content
                    break
                }
            }

            // Try common description containers (skip nav/header/footer)
            if result.description == nil || result.description?.isEmpty == true {
                let containerSelectors = [
                    "[class*=description]:not(nav *):not(header *):not(footer *)",
                    "[class*=summary]:not(nav *):not(header *):not(footer *)",
                    "[class*=synopsis]:not(nav *):not(header *):not(footer *)",
                    "[id*=description]", "[id*=summary]", "[id*=synopsis]",
                ]
                for sel in containerSelectors {
                    if let text = try? doc.select(sel).first()?.text(),
                       text.count > 20 {
                        result.description = text
                        break
                    }
                }
            }
        }

        // Genre / Tags: look for tag links within the manga detail area (not navigation)
        if result.genre == nil || result.genre?.isEmpty == true {
            // Only look in specific tag/genre containers — avoid broad selectors
            // that would match site-wide navigation categories
            let tagSelectors = [
                "[class*=tag]:not(nav):not(header):not(footer) a",
                "[class*=genre]:not(nav):not(header):not(footer) a",
                "[id*=tag] a", "[id*=genre] a",
            ]

            // Common navigation/category labels to exclude
            let navLabels: Set<String> = [
                "全部", "日本", "港台", "其它", "其他", "歐美", "欧美", "韓國", "韩国",
                "all", "home", "more", "next", "prev", "back",
                "login", "register", "search",
            ]

            for sel in tagSelectors {
                if let rawTags = try? doc.select(sel).array().compactMap({ try? $0.text() }) {
                    let cleaned = rawTags
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { tag in
                            guard tag.count >= 2, tag.count < 40 else { return false }
                            // Must contain at least one letter/CJK character
                            let hasText = tag.unicodeScalars.contains { scalar in
                                CharacterSet.letters.contains(scalar)
                            }
                            guard hasText else { return false }
                            return !navLabels.contains(tag.lowercased())
                        }
                    if cleaned.count >= 2 {
                        result.genre = cleaned
                        break
                    }
                }
            }
        }

        // Thumbnail: og:image
        if result.thumbnailUrl == nil {
            if let ogImage = try? doc.select("meta[property=og:image]").first()?.attr("content"),
               !ogImage.isEmpty {
                result.thumbnailUrl = resolveUrl(ogImage)
            }
        }

        // Author: look for common author patterns
        if result.author == nil || result.author?.isEmpty == true {
            let authorSelectors = [
                "[class*=author] a", "[class*=artist] a",
                "a[href*=author]", "a[href*=artist]",
            ]
            for sel in authorSelectors {
                if let text = try? doc.select(sel).first()?.text(),
                   !text.isEmpty, text.count < 100 {
                    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        result.author = cleaned
                        break
                    }
                }
            }
        }
    }

    // MARK: - Generic Chapter Extraction

    /// Extract chapters using common link patterns when theme selectors fail.
    private func extractGenericChapters(doc: Document, mangaUrl: String) -> [SChapter] {
        var chapters: [SChapter] = []
        var seen = Set<String>()

        // Common chapter link patterns
        let chapterKeywords = ["chapter", "ch.", "ch-", "episode", "ep.", "ep-",
                                "page", "read", "/c", "chap"]

        guard let allLinks = try? doc.select("a[href]").array() else { return [] }

        for link in allLinks {
            guard let href = try? link.attr("href"),
                  !href.isEmpty, href != "#",
                  !href.hasPrefix("javascript:") else { continue }

            let lowerHref = href.lowercased()

            // Check if URL looks like a chapter link
            let isChapterLink = chapterKeywords.contains(where: { lowerHref.contains($0) })

            // Also check if text looks like a chapter reference
            let text = (try? link.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let lowerText = text.lowercased()
            let isChapterText = chapterKeywords.contains(where: { lowerText.contains($0) })
                || lowerText.range(of: #"^\d+(\.\d+)?$"#, options: .regularExpression) != nil

            guard isChapterLink || isChapterText else { continue }

            // Skip navigation/UI links
            if lowerHref.contains("login") || lowerHref.contains("register") ||
               lowerHref.contains("comment") || lowerHref.contains("bookmark") ||
               lowerHref.contains("javascript") { continue }

            let fullUrl = href.hasPrefix("http") ? href : baseUrl + (href.hasPrefix("/") ? href : "/\(href)")
            guard !seen.contains(fullUrl) else { continue }
            seen.insert(fullUrl)

            let name = text.isEmpty ? "Chapter" : String(text.prefix(200))
            let chapterNum = extractChapterNumber(from: name.isEmpty ? href : name)

            chapters.append(SChapter(
                url: fullUrl,
                name: name,
                dateUpload: 0,
                chapterNumber: chapterNum
            ))
        }

        return chapters
    }

    // MARK: - Generic Page Extraction

    /// Extract reader page images using common patterns when theme selectors fail.
    private func extractGenericPages(doc: Document) -> [Page] {
        var pages: [Page] = []
        var seen = Set<String>()

        // Try common reader image selectors
        let selectors = [
            "img[class*=content]", "img[class*=page]", "img[class*=reader]",
            "img[class*=manga]", "img[class*=chapter]", "img[class*=scan]",
            "img[id*=page]", "img[id*=image]", "img[id*=content]",
            "[class*=reader] img", "[class*=content] img", "[class*=page] img",
            "[id*=reader] img", "[id*=content] img",
        ]

        for sel in selectors {
            guard let imgs = try? doc.select(sel).array(), !imgs.isEmpty else { continue }

            for img in imgs {
                guard let imgUrl = try? extractImageUrl(from: img),
                      !imgUrl.isEmpty, !seen.contains(imgUrl) else { continue }

                // Skip tiny images (icons, spacers, avatars)
                let width = Int((try? img.attr("width")) ?? "") ?? 0
                let height = Int((try? img.attr("height")) ?? "") ?? 0
                if (width > 0 && width < 100) || (height > 0 && height < 100) { continue }

                seen.insert(imgUrl)
                pages.append(Page(index: pages.count, url: "", imageUrl: imgUrl))
            }

            if pages.count >= 2 { break } // Found a working selector
        }

        // Broader fallback: all images above a certain threshold
        if pages.isEmpty {
            if let allImgs = try? doc.select("img").array() {
                for img in allImgs {
                    guard let imgUrl = try? extractImageUrl(from: img),
                          !imgUrl.isEmpty, !seen.contains(imgUrl) else { continue }

                    let src = imgUrl.lowercased()
                    // Skip obvious non-content images
                    if src.contains("logo") || src.contains("icon") || src.contains("avatar") ||
                       src.contains("banner") || src.contains("ads") || src.contains("button") ||
                       src.contains("favicon") || src.contains("sprite") { continue }

                    let width = Int((try? img.attr("width")) ?? "") ?? 0
                    let height = Int((try? img.attr("height")) ?? "") ?? 0
                    if (width > 0 && width < 200) || (height > 0 && height < 200) { continue }

                    seen.insert(imgUrl)
                    pages.append(Page(index: pages.count, url: "", imageUrl: imgUrl))
                }
            }
        }

        return pages
    }

    // MARK: - Network Helpers

    private func fetchWithHeaders(url: URL) async throws -> (Data, URLResponse) {
        let host = url.host ?? "unknown"
        let network = NetworkHelper.shared

        // Rate limiting — wait for permit on background thread
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                network.rateLimiterRegistry.limiter(for: host).acquire()
                continuation.resume()
            }
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        // UA rotation (per-host sticky)
        request.setValue(network.userAgentProvider.userAgent(for: host), forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(baseUrl, forHTTPHeaderField: "Referer")
        request.setValue(URL(string: baseUrl)?.host, forHTTPHeaderField: "Origin")

        // Cookie persistence (Cloudflare cf_clearance, etc.)
        network.cookieManager.applyCookies(to: &request)

        let (data, response) = try await session.data(for: request)

        // Store response cookies for future requests
        network.cookieManager.storeCookies(from: response, for: url)

        return (data, response)
    }

    private func checkHttpResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        let host = response.url?.host ?? baseUrl

        switch http.statusCode {
        case 200..<400:
            return // OK (includes redirects)
        default:
            if http.statusCode >= 400 {
                throw ScrapingError.httpError(http.statusCode, host)
            }
        }
    }

    /// Decode HTML data trying UTF-8 first, then Latin1 fallback
    private func decodeHtml(_ data: Data) -> String? {
        if let str = String(data: data, encoding: .utf8) { return str }
        if let str = String(data: data, encoding: .isoLatin1) { return str }
        return nil
    }

    // MARK: - Parsing Helpers

    private func extractImageUrl(from element: Element) throws -> String? {
        let attrs = ["data-src", "data-lazy-src", "data-original", "data-cfsrc", "srcset", "src"]
        for attr in attrs {
            if let value = try? element.attr(attr), !value.isEmpty,
               value != "about:blank", !value.hasPrefix("data:") {
                let raw: String
                if attr == "srcset" {
                    raw = value.components(separatedBy: " ").first ?? value
                } else {
                    raw = value
                }
                return resolveUrl(raw)
            }
        }
        return nil
    }

    /// Convert relative / protocol-relative URLs to absolute.
    private func resolveUrl(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }
        if trimmed.hasPrefix("//") {
            return "https:" + trimmed
        }
        if trimmed.hasPrefix("/") {
            return baseUrl + trimmed
        }
        return baseUrl + "/" + trimmed
    }

    private func parseStatus(_ text: String) -> MangaStatus {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lowered.contains("ongoing") || lowered.contains("publishing") { return .ongoing }
        if lowered.contains("completed") || lowered.contains("finished") { return .completed }
        if lowered.contains("hiatus") || lowered.contains("pause") { return .onHiatus }
        if lowered.contains("cancelled") || lowered.contains("dropped") { return .cancelled }
        if lowered.contains("licensed") { return .licensed }
        return .unknown
    }

    private func extractChapterNumber(from name: String) -> Double {
        let pattern = #"(?:ch(?:apter)?\.?\s*)(\d+(?:\.\d+)?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name),
           let number = Double(name[range]) {
            return number
        }
        return -1
    }


    /// Properly encode a full URL string that may contain raw Unicode characters.
    /// Uses URLComponents to encode path/query correctly without double-encoding.
    static func properlyEncodeUrl(_ rawUrl: String) -> String {
        // If URLComponents can parse it, it handles encoding automatically
        if var components = URLComponents(string: rawUrl) {
            // URLComponents auto-encodes when producing .url or .string
            if let result = components.url?.absoluteString ?? components.string {
                return result
            }
        }
        // Fallback: encode the entire string, treating % as allowed (to preserve existing encoding)
        return rawUrl.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawUrl
    }
}
