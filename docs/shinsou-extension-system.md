# Shinsou 插件系統完整文件

> 此文件描述 Shinsou iOS 漫畫閱讀器的 JavaScript 插件系統架構與開發指南。

---

## 目錄

1. [系統架構總覽](#1-系統架構總覽)
2. [插件倉庫（Extension Repository）](#2-插件倉庫extension-repository)
3. [插件模型與生命週期](#3-插件模型與生命週期)
4. [Source API 介面體系](#4-source-api-介面體系)
5. [JS 插件執行環境](#5-js-插件執行環境)
6. [漫畫內容獲取流程](#6-漫畫內容獲取流程)
7. [信任與驗證系統](#7-信任與驗證系統)
8. [插件開發指南](#8-插件開發指南)
9. [關鍵檔案索引](#9-關鍵檔案索引)

---

## 1. 系統架構總覽

Shinsou 的插件系統使用 Apple 的 **JavaScriptCore** 引擎執行 JavaScript 腳本，替代 Android Mihon 的 APK 動態載入機制。每個插件是一個 `.js` 檔案，搭配同名的 `.json` manifest 描述其元資料。

```
┌──────────────────────────────────────────────────────────────────┐
│                         使用者介面 (UI)                          │
│  Sources 列表   │  Browse漫畫   │  漫畫詳情  │  Reader閱讀器      │
└────────┬────────┴──────┬────────┴─────┬──────┴──────┬────────────┘
         │               │              │             │
┌────────▼────────────────▼──────────────▼─────────────▼────────────┐
│                    Domain Layer (Use Cases)                       │
│  GetExtensionRepo  │  GetRemoteManga  │  GetManga  │  GetChapter │
└────────┬────────────┴──────┬───────────┴─────┬──────┴─────┬──────┘
         │                   │                 │            │
┌────────▼───────────────────▼─────────────────▼────────────▼──────┐
│                      Data Layer                                  │
│  ExtensionRepoRepository  │  SourceRepository  │  MangaRepo     │
└────────┬──────────────────┴─────────┬──────────┴────────┬───────┘
         │                            │                   │
┌────────▼────────┐  ┌───────────────▼──────────┐  ┌─────▼──────┐
│  Plugin Repo    │  │    JSSourceProxy          │  │  GRDB      │
│  index.json     │  │    (JavaScriptCore)       │  │  shinsou.db│
│  repo.json      │  │    ↕ JSBridge ↕           │  │            │
│  .js download   │  │    HTTP / DOM / Prefs     │  │            │
└─────────────────┘  └──────────────────────────┘  └────────────┘
```

### 核心流程

```
新增倉庫 URL → 獲取 repo.json → 驗證 → 儲存到 DB
                                         ↓
獲取 index.json → 列出可用插件 → 下載 .js + .json
                                         ↓
PluginLoader 掃描 Documents/Plugins/ → PluginVerifier 驗證 SHA-256
                                         ↓
JSSourceProxy 建立 JSContext → 注入 JSBridge → 執行插件腳本
                                         ↓
          註冊為 CatalogueSource → 瀏覽/搜尋漫畫
                                         ↓
            取得漫畫詳情 → 章節列表 → 頁面列表 → 載入圖片
```

---

## 2. 插件倉庫（Extension Repository）

### 2.1 資料模型

```swift
// ShinsouDomain
struct ExtensionRepo {
    let baseUrl: String                // 主鍵，倉庫 URL
    let name: String                   // 倉庫名稱
    let shortName: String?             // 簡稱（可選）
    let website: String                // 倉庫網站
    let signingKeyFingerprint: String  // 簽名金鑰指紋（唯一約束）
}
```

### 2.2 資料庫結構

```sql
CREATE TABLE extension_repos (
    base_url TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    short_name TEXT,
    website TEXT NOT NULL,
    signing_key_fingerprint TEXT UNIQUE NOT NULL
);
```

### 2.3 網路端點

| 端點 | URL 格式 | 用途 |
|------|---------|------|
| 倉庫元資料 | `{baseUrl}/repo.json` | 獲取倉庫基本資訊與簽名指紋 |
| 插件索引 | `{baseUrl}/index.json` | 列出所有可用 JS 插件 |
| 腳本下載 | `{baseUrl}/{scriptUrl}` | 下載 JS 插件腳本 |
| 圖示 | `{baseUrl}/{iconUrl}` | 插件圖示 |

#### `repo.json` 格式

```json
{
  "meta": {
    "name": "Shinsou Plugins",
    "website": "https://github.com/aluo96078/shinsou_plugin",
    "signingKeyFingerprint": "abcdef1234567890..."
  }
}
```

#### `index.json` 格式（Shinsou 原生格式）

```json
[
  {
    "id": "en.mangadex",
    "name": "MangaDex",
    "version": "1.0.0",
    "versionCode": 1,
    "lang": "en",
    "nsfw": 0,
    "scriptUrl": "plugins/en.mangadex.js",
    "iconUrl": "icons/en.mangadex.png",
    "description": "MangaDex source plugin",
    "sources": [
      {
        "name": "MangaDex",
        "lang": "en",
        "id": 2499283573021220255,
        "baseUrl": "https://mangadex.org"
      }
    ]
  }
]
```

**`PluginIndexEntry` 欄位說明：**

| 欄位 | 型別 | 說明 |
|------|------|------|
| `id` | String | 插件識別碼（格式：`{lang}.{name}`） |
| `name` | String | 插件顯示名稱 |
| `version` | String | 版本字串 |
| `versionCode` | Int | 版本號（整數遞增） |
| `lang` | String | 語言代碼 |
| `nsfw` | Int | NSFW 標記（`0`=安全, `1`=成人內容）|
| `scriptUrl` | String | JS 腳本相對路徑 |
| `iconUrl` | String? | 圖示相對路徑 |
| `description` | String? | 插件描述 |
| `sources` | Array? | 此插件包含的來源列表 |

#### `index.min.json` 相容格式（Android Mihon 倉庫）

Shinsou 同時支援讀取 Android Mihon 倉庫的 `index.min.json` 格式（`ExtensionIndexEntry`），可取得來源元資料：

```json
[{
  "name": "Tachiyomi: MangaDex",
  "pkg": "eu.kanade.tachiyomi.extension.all.mangadex",
  "apk": "tachiyomi-all.mangadex-v1.4.206.apk",
  "lang": "all",
  "code": 206,
  "version": "1.4.206",
  "nsfw": 1,
  "sources": [
    { "name": "MangaDex", "lang": "en", "id": 2499283573021220255, "baseUrl": "https://mangadex.org" }
  ]
}]
```

> **注意**：APK 欄位在 iOS 上被忽略，僅使用來源元資料。

### 2.4 倉庫管理 Interactors

#### CreateExtensionRepo — 新增倉庫

```
1. 驗證 URL 格式
2. 提取 baseUrl
3. 獲取 repo.json 元資料
4. 衝突檢查：URL 重複 / 簽名指紋重複
5. 儲存到資料庫
```

結果：`Success` / `InvalidUrl` / `RepoAlreadyExists` / `DuplicateFingerprint`

#### 其他 Interactors
- `DeleteExtensionRepo` — 刪除倉庫
- `GetExtensionRepo` — 查詢倉庫（即時監聽 / 一次性查詢）
- `UpdateExtensionRepo` — 更新倉庫元資料
- `ReplaceExtensionRepo` — 完全替換倉庫
- `GetExtensionRepoCount` — 倉庫數量

---

## 3. 插件模型與生命週期

### 3.1 插件 Manifest

每個 JS 插件搭配一個同名的 `.json` manifest 檔案：

```swift
// ShinsouSourceAPI/Plugin/PluginManifest.swift
struct PluginManifest: Codable, Sendable {
    let id: String               // 插件 ID，如 "en.mangadex"
    let name: String             // 顯示名稱
    let version: String          // 版本字串
    let versionCode: Int?        // 版本號
    let lang: String             // 語言代碼
    let nsfw: Bool               // NSFW 標記
    let script: String           // 腳本檔名
    let signature: String        // SHA-256 雜湊值
    let minRuntimeVersion: String? // 最低執行時版本
    let sources: [SourceIndexEntry]? // 來源元資料
}
```

### 3.2 插件安裝流程

```
使用者在 Extensions 畫面點擊「安裝」
    ↓
ExtensionManager 從倉庫下載 .js 腳本
    ↓
同時下載對應的 .json manifest
    ↓
儲存至 Documents/Plugins/{id}.js 與 {id}.json
    ↓
PluginVerifier.verify() 驗證 SHA-256 雜湊值
    ↓
PluginLoader 建立 JSSourceProxy 實例
    ↓
註冊到 SourceManager，可供瀏覽使用
```

### 3.3 插件載入流程（App 啟動時）

```
PluginLoader.loadAllPlugins()
    ↓
1. 掃描 Documents/Plugins/ 目錄中的 .js 檔案
    ↓
2. 讀取同名 .json manifest
    ↓
3. PluginVerifier.verify() 驗證
   - 計算 .js 檔案的 SHA-256
   - 與 manifest.signature 比對
   - 檢查 PluginTrustStore 信任記錄
    ↓
4. 建立 JSSourceProxy 實例
   - 建立 JSContext
   - 注入 JSBridge + JSDomLib
   - 執行 JS 腳本
   - 從 JS context 讀取 source 屬性（id, name, lang, baseUrl 等）
    ↓
5. 回傳 [JSSourceProxy] → 註冊到 SourceManager
```

### 3.4 更新檢測

```
1. 從所有倉庫獲取最新 index.json
2. 與本地已安裝插件的 versionCode 比對
3. 若遠端版本較高 → 標記為「有更新」
4. 使用者可單獨更新或全部更新
```

---

## 4. Source API 介面體系

### 4.1 介面繼承層級

```
Source (基礎協定)
  └── CatalogueSource (瀏覽 + 搜尋)
        └── HttpSource (HTTP 實作)

ConfigurableSource (可配置源，獨立協定)
```

### 4.2 Source — 基礎協定

```swift
// ShinsouSourceAPI/Source.swift
protocol Source: Sendable {
    var id: Int64 { get }
    var name: String { get }
    var lang: String { get }

    func getMangaDetails(manga: SManga) async throws -> SManga
    func getChapterList(manga: SManga) async throws -> [SChapter]
    func getPageList(chapter: SChapter) async throws -> [Page]
}
```

### 4.3 CatalogueSource — 目錄瀏覽協定

```swift
// ShinsouSourceAPI/CatalogueSource.swift
protocol CatalogueSource: Source {
    var supportsLatest: Bool { get }
    var baseUrl: String { get }

    func getPopularManga(page: Int) async throws -> MangasPage
    func getSearchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage
    func getLatestUpdates(page: Int) async throws -> MangasPage
    func getFilterList() -> FilterList
}
```

### 4.4 HttpSource — HTTP 源

```swift
// ShinsouSourceAPI/HttpSource.swift
protocol HttpSource: CatalogueSource {
    var baseUrl: String { get }
    var headers: [String: String] { get }
}
```

### 4.5 ConfigurableSource — 可配置源

```swift
// ShinsouSourceAPI/ConfigurableSource.swift
protocol ConfigurableSource: Source {
    func getPreference(key: String) -> String?
    func setPreference(key: String, value: String)
}
```

### 4.6 資料模型

#### SManga

```swift
struct SManga {
    var url: String              // 相對路徑（如 "/manga/123"）
    var title: String
    var artist: String?
    var author: String?
    var description: String?
    var genre: String?           // 逗號分隔的標籤
    var status: Int              // UNKNOWN=0, ONGOING=1, COMPLETED=2, LICENSED=3...
    var thumbnailUrl: String?
    var initialized: Bool
}
```

#### SChapter

```swift
struct SChapter {
    var url: String
    var name: String
    var dateUpload: Int64        // 上傳時間戳
    var chapterNumber: Float     // 章節編號
    var scanlator: String?       // 翻譯組
}
```

#### Page

```swift
struct Page {
    let index: Int               // 頁面索引
    var url: String              // 頁面 URL（可能需要二次請求）
    var imageUrl: String?        // 圖片直連 URL
}
```

#### MangasPage

```swift
struct MangasPage {
    let mangas: [SManga]
    let hasNextPage: Bool
}
```

### 4.7 過濾器系統

```swift
enum Filter {
    case header(name: String)
    case separator
    case select(name: String, values: [String], state: Int)
    case text(name: String, state: String)
    case checkBox(name: String, state: Bool)
    case triState(name: String, state: Int)  // 0=忽略, 1=包含, 2=排除
    case sort(name: String, values: [String], selection: (index: Int, ascending: Bool)?)
    case group(name: String, filters: [Filter])
}

typealias FilterList = [Filter]
```

---

## 5. JS 插件執行環境

### 5.1 JSSourceProxy

`JSSourceProxy` 是 JS 插件與原生 Swift 之間的橋樑，實作 `CatalogueSource` 協定：

```
JSSourceProxy (Swift, 實作 CatalogueSource)
    ↕
JSContext (JavaScriptCore 執行環境)
    ↕
JSBridge (原生能力注入)
    ↕
JS 插件腳本 (開發者編寫)
```

**初始化流程：**
1. 建立 `JSContext`
2. 建立 `JSBridge` 並注入為 `bridge` 全域變數
3. 注入 `console.log` / `console.error` 等
4. 執行 `JSDomLib.script`（注入 Jsoup 相容 DOM API）
5. 執行插件腳本
6. 從 JS context 讀取 `source` 物件的屬性

### 5.2 JSBridge API

`JSBridge` 透過 `@objc` 與 `JSExport` 將原生方法暴露給 JS：

#### HTTP 請求

所有 HTTP 請求會自動攜帶此來源的 per-source cookies，回應的 `Set-Cookie` 也會自動儲存至 per-source cookie jar。

| 方法 | 說明 |
|------|------|
| `bridge.httpGet(url)` | GET 請求，回傳回應內容 |
| `bridge.httpGetWithHeaders(url, headers)` | GET 請求（含自訂 Header）|
| `bridge.httpPost(url, body, headers)` | POST 請求 |

#### Cookie 管理

每個來源有獨立的 cookie jar，cookies 持久化至 UserDefaults，App 重啟後仍有效。使用者也可在 App「來源設定」畫面手動新增、匯入或刪除 cookies。

| 方法 | 說明 |
|------|------|
| `bridge.getCookie(name, url)` | 取得指定 cookie 的值 |
| `bridge.getCookies(url)` | 取得該 URL 所有 cookies（回傳 `{name: value}` 物件）|
| `bridge.setCookie(name, value, domain, path, expirySeconds)` | 設定 cookie。`expirySeconds=0` 為 session cookie |
| `bridge.deleteCookie(name, domain)` | 刪除指定 cookie |
| `bridge.clearCookies()` | 清除此來源所有 cookies |

#### 帳號密碼（Credentials）

使用者可在 App「來源設定」畫面儲存帳號密碼。插件可透過以下 API 讀取，無論是否宣告 `supportsLogin`。

| 方法 | 說明 |
|------|------|
| `bridge.getCredentialUsername()` | 取得已儲存帳號 |
| `bridge.getCredentialPassword()` | 取得已儲存密碼 |
| `bridge.setCredential(username, password)` | 儲存帳密 |
| `bridge.clearCredential()` | 清除帳密 |
| `bridge.hasCredential()` | 是否已儲存帳密 |

#### 登入支援

插件可宣告 `supportsLogin: true`，App 設定畫面會顯示登入按鈕：

```javascript
var source = {
    supportsLogin: true,

    // App 呼叫此方法，回傳 true 表示登入成功
    login: function(username, password) {
        var result = bridge.httpPost(this.baseUrl + "/login",
            "user=" + encodeURIComponent(username) + "&pass=" + encodeURIComponent(password),
            { "Content-Type": "application/x-www-form-urlencoded" }
        );
        // 回應的 Set-Cookie 會自動儲存至 per-source cookie jar
        return JSON.parse(result).success === true;
    },

    // App 呼叫此方法（選用）
    logout: function() {
        bridge.clearCookies();
    }
};
```

#### DOM 解析（Handle-based API，基於 SwiftSoup）

| 方法 | 說明 |
|------|------|
| `bridge.htmlParse(html)` | 解析 HTML，回傳 handle ID |
| `bridge.htmlParseFragment(html, baseUri)` | 解析 HTML 片段 |
| `bridge.domSelect(handleId, cssSelector)` | CSS 選擇器查詢，回傳 handle 陣列 |
| `bridge.domFirst(handleId, cssSelector)` | 取得第一個匹配元素的 handle |
| `bridge.domText(handleId)` | 取得元素文字內容 |
| `bridge.domOwnText(handleId)` | 取得元素自身文字（不含子元素）|
| `bridge.domHtml(handleId)` | 取得內部 HTML |
| `bridge.domOuterHtml(handleId)` | 取得外部 HTML |
| `bridge.domAttr(handleId, attrName)` | 取得屬性值 |
| `bridge.domHasAttr(handleId, attrName)` | 檢查屬性是否存在 |
| `bridge.domAbsUrl(handleId, attrName)` | 取得絕對 URL |
| `bridge.domTagName(handleId)` | 取得標籤名稱 |
| `bridge.domClassName(handleId)` | 取得 class 名稱 |
| `bridge.domId(handleId)` | 取得 ID |
| `bridge.domChildren(handleId)` | 取得子元素的 handle 陣列 |
| `bridge.domParent(handleId)` | 取得父元素 handle |
| `bridge.domNextSibling(handleId)` | 取得下一個兄弟元素 |
| `bridge.domPrevSibling(handleId)` | 取得上一個兄弟元素 |
| `bridge.domRemove(handleId)` | 從 DOM 移除元素 |
| `bridge.domRelease(handleId)` | 釋放單一 handle |
| `bridge.domReleaseAll()` | 釋放所有 handle |

#### 偏好設定

| 方法 | 說明 |
|------|------|
| `bridge.getPreference(key)` | 讀取偏好設定值 |
| `bridge.setPreference(key, value)` | 寫入偏好設定值 |

#### 日誌

| 方法 | 說明 |
|------|------|
| `bridge.log(message)` | 記錄日誌 |

### 5.3 JSDomLib — Jsoup 相容 DOM API

`JSDomLib` 注入了高階 DOM API，讓 JS 插件可以使用熟悉的 Jsoup 風格語法：

```javascript
// 解析 HTML
var doc = Jsoup.parse(html);

// CSS 選擇器查詢
var elements = doc.select("div.manga-item");

// 遍歷元素
for (var i = 0; i < elements.size(); i++) {
    var el = elements.get(i);
    var title = el.select("h3.title").text();
    var url = el.select("a").attr("href");
    var img = el.select("img").attr("src");
}

// 元素方法
element.text()        // 取得文字
element.attr("href")  // 取得屬性
element.absUrl("src") // 取得絕對 URL
element.html()        // 取得內部 HTML
element.select(css)   // 子查詢
element.first(css)    // 第一個匹配
```

所有 DOM 操作底層都委派給 `JSBridge` 的 handle-based API，由 SwiftSoup 在原生層執行實際的 HTML 解析。

### 5.4 兩種插件模式

#### Full Mode — 完整模式

插件定義一個 `source` 物件，包含所有必要的方法：

```javascript
var source = {
    id: 123456789,
    name: "ExampleSource",
    lang: "en",
    baseUrl: "https://example.com",
    supportsLatest: true,

    getPopularManga: function(page) {
        var html = bridge.httpGet(this.baseUrl + "/popular?page=" + page);
        var doc = Jsoup.parse(html);
        var mangas = [];
        var elements = doc.select("div.manga-item");
        for (var i = 0; i < elements.size(); i++) {
            var el = elements.get(i);
            mangas.push({
                url: el.select("a").attr("href"),
                title: el.select("h3").text(),
                thumbnailUrl: el.select("img").absUrl("src")
            });
        }
        var hasNext = doc.select("a.next-page").first() !== null;
        return { mangas: mangas, hasNextPage: hasNext };
    },

    getSearchManga: function(page, query, filters) { /* ... */ },
    getLatestUpdates: function(page) { /* ... */ },
    getMangaDetails: function(manga) { /* ... */ },
    getChapterList: function(manga) { /* ... */ },
    getPageList: function(chapter) { /* ... */ },
    getFilterList: function() { return []; }
};
```

#### ParsedHttpSource Mode — 選擇器模式

插件定義 CSS 選擇器與回呼函式，由執行時自動處理 HTML 獲取與解析：

```javascript
var source = {
    id: 123456789,
    name: "ExampleSource",
    lang: "en",
    baseUrl: "https://example.com",
    supportsLatest: true,

    // 人氣漫畫
    popularMangaRequest: function(page) {
        return { url: this.baseUrl + "/popular?page=" + page };
    },
    popularMangaSelector: function() { return "div.manga-item"; },
    popularMangaFromElement: function(element) {
        return {
            url: element.select("a").attr("href"),
            title: element.select("h3").text(),
            thumbnailUrl: element.select("img").absUrl("src")
        };
    },
    popularMangaNextPageSelector: function() { return "a.next-page"; },

    // 類似模式適用於 searchManga, latestUpdates, mangaDetails, chapterList, pageList
};
```

---

## 6. 漫畫內容獲取流程

### 6.1 SourceManager — 來源管理器

```swift
// ShinsouApp/Source/SourceManager.swift
protocol SourceManagerProtocol {
    func get(sourceId: Int64) -> Source?
    func getOrStub(sourceId: Int64) -> Source
    func getCatalogueSources() -> [CatalogueSource]
}
```

- 本地來源（LocalSource）固定 ID 為 `0`
- JS 插件來源由 `PluginLoader` 載入後註冊
- 若插件已卸載，回傳 `StubCatalogueSource`

### 6.2 瀏覽漫畫流程

```
Sources 畫面 (選擇來源)
    ↓
Browse Source 畫面 (漫畫列表)
    ↓ CatalogueSource.getPopularManga(page)
    ↓ CatalogueSource.getSearchManga(page, query, filters)
    ↓ CatalogueSource.getLatestUpdates(page)
    ↓
漫畫詳情畫面 (章節列表)
    ↓ Source.getMangaDetails(manga)
    ↓ Source.getChapterList(manga)
    ↓
Reader 閱讀器
    ↓ Source.getPageList(chapter)
    ↓ → 圖片 URL → Nuke 圖片載入與快取
```

### 6.3 先快取後網路策略

```
顯示漫畫詳情：
1. 從本地 DB 讀取快取的漫畫資訊與章節 → 立即顯示
2. 在背景呼叫 Source.getMangaDetails() 更新資訊
3. 在背景呼叫 Source.getChapterList() 更新章節列表
4. 寫回 DB → UI 自動更新
```

### 6.4 本地來源（LocalSource）

- 來源 ID 固定為 `0`
- 從檔案系統讀取本地漫畫
- 支援格式：資料夾、ZIP、CBZ、RAR、CBR、EPUB
- 支援 `ComicInfo.xml` 元資料解析

---

## 7. 信任與驗證系統

### 7.1 PluginVerifier

驗證 JS 插件的完整性與信任狀態：

```swift
// ShinsouApp/Source/JSPlugin/PluginVerifier.swift
enum PluginVerifier {
    static func verify(data: Data, manifest: PluginManifest, signingKeyFingerprint: String?) throws
}
```

**驗證流程：**

```
讀取 .js 檔案原始 Data
    ↓
計算 SHA-256 雜湊值
    ↓
┌─── manifest.signature 非空？ ───┐
│  是 → 比對 SHA-256              │
│       匹配 → 繼續               │
│       不匹配 → 拋出 hashMismatch│
│  否 → 繼續到信任檢查             │
└─────────────────────────────────┘
    ↓
┌─── PluginTrustStore 已記錄？ ───┐
│  是 → ✅ 通過驗證               │
│  否 ↓                          │
│  ┌─ manifest 有簽名？ ─┐       │
│  │ 是 → 自動加入信任庫  │       │
│  │ 否 → ❌ 拋出         │       │
│  │     untrustedPlugin   │       │
│  └──────────────────────┘       │
└─────────────────────────────────┘
```

### 7.2 PluginTrustStore

```swift
// ShinsouApp/Source/JSPlugin/PluginVerifier.swift
final class PluginTrustStore {
    static let shared: PluginTrustStore

    func isTrusted(pkg: String, versionCode: Int, hash: String) -> Bool
    func trust(pkg: String, versionCode: Int, hash: String)
    func revoke(pkg: String, versionCode: Int, hash: String)
    func revokeAll(pkg: String)
}
```

- 信任記錄格式：`{pkg}:{versionCode}:{sha256}`
- 持久化於 UserDefaults
- 已簽名且雜湊匹配的插件自動加入信任庫
- 未簽名插件必須由使用者手動信任

### 7.3 驗證錯誤

| 錯誤 | 說明 |
|------|------|
| `hashMismatch` | SHA-256 與 manifest 中的簽名不匹配 |
| `untrustedPlugin` | 插件未簽名且不在信任庫中 |
| `manifestMissing` | 找不到對應的 .json manifest |

---

## 8. 插件開發指南

### 8.1 檔案結構

每個插件由兩個檔案組成：

```
{id}.js    — JavaScript 腳本（主要邏輯）
{id}.json  — Manifest（元資料與簽名）
```

例如：
```
en.mangadex.js
en.mangadex.json
```

### 8.2 Manifest 範例

```json
{
  "id": "en.mangadex",
  "name": "MangaDex",
  "version": "1.0.0",
  "versionCode": 1,
  "lang": "en",
  "nsfw": false,
  "script": "en.mangadex.js",
  "signature": "a1b2c3d4e5f6...",
  "minRuntimeVersion": "1.0",
  "sources": [
    {
      "name": "MangaDex",
      "lang": "en",
      "id": 2499283573021220255,
      "baseUrl": "https://mangadex.org"
    }
  ]
}
```

### 8.3 必須實作的方法

| 方法 | 回傳值 | 說明 |
|------|--------|------|
| `getPopularManga(page)` | `MangasPage` | 人氣漫畫列表 |
| `getSearchManga(page, query, filters)` | `MangasPage` | 搜尋結果 |
| `getLatestUpdates(page)` | `MangasPage` | 最新更新（`supportsLatest` 為 true 時）|
| `getMangaDetails(manga)` | `SManga` | 漫畫詳細資訊 |
| `getChapterList(manga)` | `[SChapter]` | 章節列表 |
| `getPageList(chapter)` | `[Page]` | 頁面（圖片）列表 |
| `getFilterList()` | `FilterList` | 過濾器選項 |

### 8.4 回傳格式

#### MangasPage
```javascript
{
    mangas: [
        { url: "/manga/123", title: "Manga Title", thumbnailUrl: "https://..." },
        // ...
    ],
    hasNextPage: true
}
```

#### SManga
```javascript
{
    url: "/manga/123",
    title: "Manga Title",
    author: "Author Name",
    artist: "Artist Name",
    description: "Description...",
    genre: "Action, Adventure, Fantasy",
    status: 1,  // 0=Unknown, 1=Ongoing, 2=Completed, 3=Licensed
    thumbnailUrl: "https://..."
}
```

#### SChapter
```javascript
{
    url: "/chapter/456",
    name: "Chapter 1",
    dateUpload: 1700000000000,  // 毫秒時間戳
    chapterNumber: 1.0,
    scanlator: "Scan Group"
}
```

#### Page
```javascript
{
    index: 0,
    url: "",
    imageUrl: "https://img.example.com/page1.jpg"
}
```

### 8.5 完整插件範例

```javascript
var source = {
    id: 1234567890,
    name: "ExampleManga",
    lang: "en",
    baseUrl: "https://example-manga.com",
    supportsLatest: true,

    getPopularManga: function(page) {
        var url = this.baseUrl + "/popular?page=" + page;
        var html = bridge.httpGet(url);
        var doc = Jsoup.parse(html);
        var mangas = [];

        var items = doc.select("div.manga-card");
        for (var i = 0; i < items.size(); i++) {
            var el = items.get(i);
            mangas.push({
                url: el.select("a.title-link").attr("href"),
                title: el.select("a.title-link").text(),
                thumbnailUrl: el.select("img.cover").absUrl("src")
            });
        }

        var hasNext = doc.select("a.pagination-next").first() !== null;
        return { mangas: mangas, hasNextPage: hasNext };
    },

    getSearchManga: function(page, query, filters) {
        var url = this.baseUrl + "/search?q=" + encodeURIComponent(query) + "&page=" + page;
        var html = bridge.httpGet(url);
        var doc = Jsoup.parse(html);
        var mangas = [];

        var items = doc.select("div.search-result");
        for (var i = 0; i < items.size(); i++) {
            var el = items.get(i);
            mangas.push({
                url: el.select("a").attr("href"),
                title: el.select("h3").text(),
                thumbnailUrl: el.select("img").absUrl("src")
            });
        }

        return { mangas: mangas, hasNextPage: false };
    },

    getLatestUpdates: function(page) {
        var url = this.baseUrl + "/latest?page=" + page;
        var html = bridge.httpGet(url);
        var doc = Jsoup.parse(html);
        var mangas = [];

        var items = doc.select("div.update-item");
        for (var i = 0; i < items.size(); i++) {
            var el = items.get(i);
            mangas.push({
                url: el.select("a").attr("href"),
                title: el.select("span.title").text(),
                thumbnailUrl: el.select("img").absUrl("src")
            });
        }

        var hasNext = doc.select("a.next").first() !== null;
        return { mangas: mangas, hasNextPage: hasNext };
    },

    getMangaDetails: function(manga) {
        var html = bridge.httpGet(this.baseUrl + manga.url);
        var doc = Jsoup.parse(html);
        var info = doc.select("div.manga-info").first();

        return {
            url: manga.url,
            title: info.select("h1").text(),
            author: info.select("span.author").text(),
            artist: info.select("span.artist").text(),
            description: info.select("div.synopsis").text(),
            genre: info.select("span.genre").text(),
            status: 1,
            thumbnailUrl: info.select("img.cover").absUrl("src")
        };
    },

    getChapterList: function(manga) {
        var html = bridge.httpGet(this.baseUrl + manga.url);
        var doc = Jsoup.parse(html);
        var chapters = [];

        var items = doc.select("div.chapter-item");
        for (var i = 0; i < items.size(); i++) {
            var el = items.get(i);
            chapters.push({
                url: el.select("a").attr("href"),
                name: el.select("span.chapter-title").text(),
                dateUpload: 0,
                chapterNumber: parseFloat(el.select("span.chapter-num").text()) || 0
            });
        }

        return chapters;
    },

    getPageList: function(chapter) {
        var html = bridge.httpGet(this.baseUrl + chapter.url);
        var doc = Jsoup.parse(html);
        var pages = [];

        var imgs = doc.select("div.reader img");
        for (var i = 0; i < imgs.size(); i++) {
            pages.push({
                index: i,
                url: "",
                imageUrl: imgs.get(i).absUrl("src")
            });
        }

        return pages;
    },

    getFilterList: function() {
        return [];
    }
};
```

### 8.6 偏好設定使用

```javascript
// 讀取偏好設定（如使用者選擇的語言或品質）
var lang = bridge.getPreference("preferred_language") || "en";
var quality = bridge.getPreference("image_quality") || "high";

// 寫入偏好設定
bridge.setPreference("preferred_language", "ja");
```

### 8.7 HTTP 請求進階用法

```javascript
// 帶自訂 Header 的 GET 請求
var html = bridge.httpGetWithHeaders(url, {
    "Referer": "https://example.com",
    "Cookie": "session=abc123"
});

// POST 請求
var response = bridge.httpPost(
    "https://api.example.com/search",
    JSON.stringify({ query: "manga" }),
    { "Content-Type": "application/json" }
);
var data = JSON.parse(response);
```

### 8.8 注意事項

- JS 插件在 JavaScriptCore 中執行，**沒有** `window`、`document`、`XMLHttpRequest` 等瀏覽器 API
- 所有 HTTP 請求必須透過 `bridge.httpGet()` / `bridge.httpPost()`
- 所有 HTML 解析必須透過 `Jsoup.parse()` + DOM API 或 `bridge.htmlParse()` + handle API
- `console.log()` 會導向 `bridge.log()`，可在 debug 時查看
- ID 為 `Int64`，JS 中大數字可能超出安全整數範圍，使用時需注意

---

## 9. 關鍵檔案索引

### Source API 層（ShinsouSourceAPI 套件）

| 檔案 | 說明 |
|------|------|
| `Source.swift` | 基礎來源協定 |
| `CatalogueSource.swift` | 目錄瀏覽來源協定 |
| `HttpSource.swift` | HTTP 來源協定 |
| `ConfigurableSource.swift` | 可配置來源協定 |
| `Plugin/PluginManifest.swift` | 插件 Manifest + 索引模型 |
| `Model/SManga.swift` | 漫畫資料模型 |
| `Model/SChapter.swift` | 章節資料模型 |
| `Model/Page.swift` | 頁面資料模型 |
| `Model/MangasPage.swift` | 漫畫分頁結果 |
| `Model/Filter.swift` | 過濾器系統 |

### JS 插件引擎（ShinsouApp/Source/JSPlugin/）

| 檔案 | 說明 |
|------|------|
| `JSBridge.swift` | 原生能力橋接（HTTP、DOM、偏好設定）|
| `JSDomLib.swift` | Jsoup 相容 DOM API（JS 注入腳本）|
| `JSSourceProxy.swift` | JS 插件 → CatalogueSource 適配器 |
| `PluginLoader.swift` | 插件載入器（掃描、驗證、實例化）|
| `PluginVerifier.swift` | SHA-256 驗證 + 信任管理 |

### 來源管理（ShinsouApp/Source/）

| 檔案 | 說明 |
|------|------|
| `SourceManager.swift` | 來源管理器（註冊、查詢）|
| `ExtensionManager.swift` | 擴展管理器（安裝、更新、卸載）|
| `ExtensionRepoService.swift` | 倉庫網路服務 |
| `StubCatalogueSource.swift` | 已卸載插件的佔位來源 |
| `Interactor/` | 來源相關用例 |

### Domain 層

| 檔案 | 說明 |
|------|------|
| `ShinsouDomain/.../extensionrepo/` | 倉庫 CRUD Interactors |
| `ShinsouDomain/.../source/` | 來源管理介面 |

### Data 層

| 檔案 | 說明 |
|------|------|
| `ShinsouData/.../Database/` | GRDB 資料庫（含 extension_repos 表）|
| `ShinsouData/.../Repository/` | Repository 實作 |

---

## 附錄：與 Android Mihon 的差異

### iOS 插件系統 vs Android 擴展系統

| 面向 | Android Mihon | Shinsou iOS |
|------|--------------|-------------|
| **擴展格式** | APK（Android Package）| JS 腳本 + JSON Manifest |
| **執行引擎** | JVM ClassLoader（動態載入 .dex）| JavaScriptCore（執行 .js）|
| **載入方式** | PackageManager 掃描已安裝 APK | 檔案系統掃描 `Documents/Plugins/` |
| **HTML 解析** | Jsoup（Java HTML Parser）| SwiftSoup（透過 JSBridge handle API）|
| **HTTP 請求** | OkHttp | URLSession（透過 JSBridge）|
| **驗證機制** | APK 簽名（PackageInfo）| SHA-256 雜湊（PluginVerifier）|
| **偏好設定** | SharedPreferences + PreferenceScreen | UserDefaults + SwiftUI Form |
| **來源實例化** | Java Reflection 反射 | JSContext 腳本執行 |
| **倉庫索引** | `index.min.json`（APK 為主）| `index.json`（JS 腳本為主）|

### 設計原則

1. **相容性**：保持與 Android Mihon Source API 相同的方法簽名（`getPopularManga`、`getMangaDetails` 等），降低插件移植門檻
2. **安全性**：JS 在沙盒環境執行，無法直接存取檔案系統或網路；所有外部操作都透過 JSBridge 管控
3. **DOM 相容**：JSDomLib 提供 Jsoup 風格 API，讓熟悉 Android 擴展開發的開發者可以快速上手
4. **信任鏈**：倉庫指紋 → Manifest 簽名 → SHA-256 雜湊，確保插件完整性
