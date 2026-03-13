# Mihon 擴充套件存儲庫與內容獲取系統 — 完整實現文件

> 基於 Mihon Android 原始碼分析，供 iOS 移植參考。

---

## 目錄

1. [系統架構總覽](#1-系統架構總覽)
2. [擴充套件存儲庫 (Extension Repository)](#2-擴充套件存儲庫-extension-repository)
3. [擴充套件 (Extension) 模型與生命週期](#3-擴充套件-extension-模型與生命週期)
4. [Source API 介面體系](#4-source-api-介面體系)
5. [漫畫內容獲取流程](#5-漫畫內容獲取流程)
6. [信任與簽名驗證系統](#6-信任與簽名驗證系統)
7. [關鍵檔案索引](#7-關鍵檔案索引)

---

## 1. 系統架構總覽

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
│  Extension API  │  │   Source (HttpSource)     │  │  SQLite DB │
│  index.min.json │  │   getPopularManga()       │  │  (SQLDelight)│
│  repo.json      │  │   getMangaDetails()       │  │            │
│  APK Download   │  │   getChapterList()        │  │            │
└─────────────────┘  │   getPageList()           │  └────────────┘
                     └──────────────────────────┘
```

### 核心流程

```
新增倉庫 URL → 獲取 repo.json → 驗證 → 儲存到 DB
                                          ↓
獲取 index.min.json → 列出可用擴充套件 → ⛔ 安裝 APK (iOS 不可用)
                                          ↓
⛔ 載入已安裝擴充 (ClassLoader 不可用) → 註冊 Sources → 瀏覽/搜尋漫畫
                                          ↓
                    取得漫畫詳情 → 章節列表 → 頁面列表 → 載入圖片
```

---

## 2. 擴充套件存儲庫 (Extension Repository)

### 2.1 資料模型

**檔案**: `domain/src/main/java/mihon/domain/extensionrepo/model/ExtensionRepo.kt`

```kotlin
data class ExtensionRepo(
    val baseUrl: String,                // 主鍵，例如 "https://raw.githubusercontent.com/user/repo/main"
    val name: String,                   // 倉庫名稱
    val shortName: String?,             // 簡稱（可選）
    val website: String,                // 倉庫網站
    val signingKeyFingerprint: String,  // 簽名金鑰指紋（唯一約束）
)
```

### 2.2 資料庫結構

**檔案**: `data/src/main/sqldelight/tachiyomi/data/extension_repos.sq`

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
| 倉庫元數據 | `{baseUrl}/repo.json` | 獲取倉庫基本資訊與簽名指紋 |
| 擴充索引 | `{baseUrl}/index.min.json` | 列出所有可用擴充套件 |
| APK 下載 | `{baseUrl}/apk/{apkName}` | 下載擴充套件安裝包 | ⛔ iOS 不可用：無法安裝/載入 APK |
| 圖示 | `{baseUrl}/icon/{pkgName}.png` | 擴充套件圖示 |

#### `repo.json` 格式

> **實際參考來源**: `https://raw.githubusercontent.com/keiyoushi/extensions/repo/repo.json`

```json
{
  "meta": {
    "name": "Keiyoushi",
    "website": "https://keiyoushi.github.io",
    "signingKeyFingerprint": "9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2"
  }
}
```

> **注意**: `shortName` 欄位在 keiyoushi 實際資料中不存在，為可選欄位。

#### `index.min.json` 格式

> **實際參考來源**: `https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json`

```json
[
  {
    "name": "Tachiyomi: MangaDex",
    "pkg": "eu.kanade.tachiyomi.extension.all.mangadex",
    "apk": "tachiyomi-all.mangadex-v1.4.206.apk",
    "lang": "all",
    "code": 206,
    "version": "1.4.206",
    "nsfw": 1,
    "sources": [
      {
        "name": "MangaDex",
        "lang": "en",
        "id": 2499283573021220255,
        "baseUrl": "https://mangadex.org"
      },
      {
        "name": "MangaDex",
        "lang": "ja",
        "id": 8033579885162383068,
        "baseUrl": "https://mangadex.org"
      }
    ]
  },
  {
    "name": "Tachiyomi: Komga",
    "pkg": "eu.kanade.tachiyomi.extension.all.komga",
    "apk": "tachiyomi-all.komga-v1.4.64.apk",
    "lang": "all",
    "code": 64,
    "version": "1.4.64",
    "nsfw": 0,
    "sources": [
      {
        "name": "Komga",
        "lang": "all",
        "id": 4508733312114627536,
        "baseUrl": ""
      }
    ]
  }
]
```

**欄位說明**:

| 欄位 | 型別 | 說明 |
|------|------|------|
| `name` | String | 擴充套件顯示名稱（格式：`Tachiyomi: {源名稱}`） |
| `pkg` | String | 套件識別碼（格式：`eu.kanade.tachiyomi.extension.{lang}.{name}`） |
| `apk` | String | APK 檔案名稱 |
| `lang` | String | 語言代碼（`en`, `ja`, `zh`, `all` 等） |
| `code` | Int | 版本號（整數遞增） |
| `version` | String | 版本字串（格式：`1.4.{code}`） |
| `nsfw` | Int | NSFW 標記（`0`=安全, `1`=成人內容） |
| `sources` | Array | 此擴充包含的來源列表 |

**sources 子欄位**:

| 欄位 | 型別 | 說明 |
|------|------|------|
| `name` | String | 來源顯示名稱 |
| `lang` | String | 來源語言代碼 |
| `id` | Int64 | 來源唯一 ID（數字，可超出 JS 安全整數範圍） |
| `baseUrl` | String | 內容網站 base URL（可為空字串，如 Komga 等自建站源） |

> **keiyoushi 統計**: 該倉庫包含約 1000+ 個擴充套件，涵蓋 `en`, `ja`, `zh`, `ko`, `fr`, `es`, `pt-BR`, `ru`, `vi`, `id`, `th`, `tr`, `ar`, `it`, `de` 等數十種語言。
> 單一擴充套件可包含多個 sources（如 MangaDex 包含數十種語言的 source）。

#### iOS 模型對照驗證

iOS 專案中 `Packages/MihonSourceAPI/Sources/MihonSourceAPI/Plugin/PluginManifest.swift` 已定義 `ExtensionIndexEntry`，與 keiyoushi 真實格式的對照：

| JSON 欄位 | iOS 型別 | 匹配狀態 | 備註 |
|-----------|---------|---------|------|
| `name` | `String` | ✅ 完全匹配 | |
| `pkg` | `String` | ✅ 完全匹配 | |
| `apk` | `String` | ✅ 完全匹配 | iOS 端可忽略此欄位，改用自定義 `script` 欄位 |
| `lang` | `String` | ✅ 完全匹配 | |
| `code` | `Int` | ✅ 完全匹配 | |
| `version` | `String` | ✅ 完全匹配 | |
| `nsfw` | `Int` | ✅ 完全匹配 | |
| `sources` | `[SourceIndexEntry]?` | ✅ 完全匹配 | |

`SourceIndexEntry` 對照：

| JSON 欄位 | iOS 型別 | 匹配狀態 | 備註 |
|-----------|---------|---------|------|
| `name` | `String` | ✅ 完全匹配 | |
| `lang` | `String` | ✅ 完全匹配 | |
| `id` | `Int64` | ✅ 完全匹配 | JSON 中為數字（非字串），Int64 可正確解碼 |
| `baseUrl` | `String?` | ✅ 完全匹配 | 可為空字串（如 Komga） |

> **結論**: iOS 現有的 `ExtensionIndexEntry` 模型**已完全對齊** keiyoushi 倉庫的真實 `index.min.json` 格式，可直接解析線上資料。

### 2.4 倉庫管理 Interactors（Use Cases）

#### CreateExtensionRepo — 新增倉庫

**檔案**: `domain/src/main/java/mihon/domain/extensionrepo/interactor/CreateExtensionRepo.kt`

```kotlin
suspend fun await(indexUrl: String): Result {
    // 1. 驗證 URL 格式：^https://.*/index\.min\.json$
    val formattedIndexUrl = indexUrl.trim()
    if (!formattedIndexUrl.matches(repoRegex)) return Result.InvalidUrl

    // 2. 提取 baseUrl
    val baseUrl = formattedIndexUrl.removeSuffix("/index.min.json")

    // 3. 獲取倉庫元數據
    val repo = service.fetchRepoDetails(baseUrl) ?: return Result.InvalidUrl

    // 4. 衝突檢查
    //    - baseUrl 已存在 → RepoAlreadyExists
    //    - 相同 signingKeyFingerprint → DuplicateFingerprint
    val existingRepos = repository.getAll()
    if (existingRepos.any { it.baseUrl == repo.baseUrl }) return Result.RepoAlreadyExists
    val matchingFingerprintRepo = existingRepos.find {
        it.signingKeyFingerprint == repo.signingKeyFingerprint
    }
    if (matchingFingerprintRepo != null) {
        return Result.DuplicateFingerprint(matchingFingerprintRepo, repo)
    }

    // 5. 儲存到資料庫
    repository.insertRepo(repo.baseUrl, repo.name, repo.shortName, repo.website, repo.signingKeyFingerprint)
    return Result.Success
}

sealed interface Result {
    data object Success : Result
    data object InvalidUrl : Result
    data object RepoAlreadyExists : Result
    data class DuplicateFingerprint(val oldRepo: ExtensionRepo, val newRepo: ExtensionRepo) : Result
}
```

> **URL 驗證正則**: `^https://.*/index\.min\.json$`

#### DeleteExtensionRepo — 刪除倉庫

```kotlin
suspend fun await(baseUrl: String) {
    repository.deleteRepo(baseUrl)
}
```

#### GetExtensionRepo — 查詢倉庫

```kotlin
fun subscribeAll(): Flow<List<ExtensionRepo>>  // 即時監聽
suspend fun getAll(): List<ExtensionRepo>       // 一次性查詢
```

#### UpdateExtensionRepo — 更新倉庫元數據

```kotlin
suspend fun awaitAll() = coroutineScope {
    repository.getAll()
        .map { async { await(it) } }
        .awaitAll()
}

suspend fun await(repo: ExtensionRepo) {
    val newRepo = service.fetchRepoDetails(repo.baseUrl) ?: return
    // 僅在指紋相符或為佔位值時才更新
    if (repo.signingKeyFingerprint.startsWith("NOFINGERPRINT") ||
        repo.signingKeyFingerprint == newRepo.signingKeyFingerprint) {
        repository.upsertRepo(newRepo)
    }
}
```

#### ReplaceExtensionRepo — 完全替換倉庫

```kotlin
suspend fun await(repo: ExtensionRepo) {
    repository.replaceRepo(repo)
}
```

#### GetExtensionRepoCount — 倉庫數量

```kotlin
fun subscribe(): Flow<Int> = repository.getCount()
```

### 2.5 倉庫服務（網路層）

**檔案**: `domain/src/main/java/mihon/domain/extensionrepo/service/ExtensionRepoService.kt`

```kotlin
interface ExtensionRepoService {
    suspend fun fetchRepoDetails(repo: String): ExtensionRepo?
}
```

**DTO 模型**:

```kotlin
@Serializable
data class ExtensionRepoMetaDto(
    val meta: ExtensionRepoDto,
)

@Serializable
data class ExtensionRepoDto(
    val name: String,
    val shortName: String?,
    val website: String,
    val signingKeyFingerprint: String,
)
```

---

## 3. 擴充套件 (Extension) 模型與生命週期

### 3.1 Extension Sealed Class

**檔案**: `app/src/main/java/eu/kanade/tachiyomi/extension/model/Extension.kt`

```kotlin
sealed class Extension {
    abstract val name: String
    abstract val pkgName: String
    abstract val versionName: String
    abstract val versionCode: Long
    abstract val libVersion: Double
    abstract val lang: String?
    abstract val isNsfw: Boolean

    // ⛔ iOS 不可用：整個 Installed 機制依賴 APK ClassLoader 動態載入
    // pkgFactory 使用反射實例化、Drawable 為 Android 專屬型別
    data class Installed(
        // ...共用屬性...
        val pkgFactory: String?,       // ⛔ SourceFactory 類名（透過反射載入，iOS 無法實作）
        val sources: List<Source>,     // ⛔ 由 ClassLoader 動態實例化的源物件
        val icon: Drawable?,           // ⛔ Android Drawable 型別
        val hasUpdate: Boolean = false,
        val isObsolete: Boolean = false,
        val isShared: Boolean,
        val repoUrl: String? = null,
    ) : Extension()

    // 📦 可用的遠端擴充
    data class Available(
        // ...共用屬性...
        val sources: List<Source>,     // 源的元數據（非實例）
        val apkName: String,           // APK 檔案名稱
        val iconUrl: String,           // 圖示 URL
        val repoUrl: String,           // 來源倉庫 URL
    ) : Extension() {
        data class Source(
            val id: Long,
            val lang: String,
            val name: String,
            val baseUrl: String,
        )
    }

    // ⛔ iOS 不可用：APK 簽名驗證為 Android 專屬機制
    data class Untrusted(
        // ...共用屬性...
        val signatureHash: String,     // ⛔ 基於 APK 簽名，iOS 需另設計驗證機制
    ) : Extension()
}
```

### 3.2 擴充索引獲取

**檔案**: `app/src/main/java/eu/kanade/tachiyomi/extension/api/ExtensionApi.kt`

```kotlin
suspend fun findExtensions(): List<Extension.Available> {
    val repos = getExtensionRepo.getAll()  // 從 DB 取得所有倉庫

    val extensions = repos.flatMap { repo ->
        // GET {repo.baseUrl}/index.min.json
        val response = networkService.client.newCall(GET("${repo.baseUrl}/index.min.json")).await()
        val jsonArray = response.parseAs<List<ExtensionJsonObject>>()

        jsonArray
            .filter { it.extractLibVersion() in 1.4..1.5 }  // 版本相容性
            .map { json ->
                Extension.Available(
                    name = json.name.substringAfter("Tachiyomi: "),
                    pkgName = json.pkg,
                    versionName = json.version,
                    versionCode = json.code,
                    libVersion = json.extractLibVersion(),
                    lang = json.lang,
                    isNsfw = json.nsfw == 1,
                    sources = json.sources?.map { src ->
                        Extension.Available.Source(src.id, src.lang, src.name, src.baseUrl)
                    } ?: emptyList(),
                    apkName = json.apk,
                    iconUrl = "${repo.baseUrl}/icon/${json.pkg}.png",
                    repoUrl = repo.baseUrl,
                )
            }
    }
    return extensions
}
```

### 3.3 安裝流程

> ⛔ **iOS 完全不可用** — 整個安裝流程為 Android 專屬機制。
> iOS 無法安裝 APK、無 PackageInstaller、無 BroadcastReceiver、無 ClassLoader。
> **iOS 需完全重新設計擴充載入架構**（例如：JavaScript 解釋器、WASM、或純 JSON 設定檔驅動）。

```
使用者點擊「安裝」
    ↓
ExtensionManager.installExtension(ext: Extension.Available)
    ↓
ExtensionApi.getApkUrl() → "{ext.repoUrl}/apk/{ext.apkName}"  ⛔ APK 格式
    ↓
ExtensionInstaller.downloadAndInstall(url, extension)           ⛔ APK 安裝
    ↓ 下載 APK 到 cache_dir/extension_{pkgName}.apk             ⛔ APK 檔案
    ↓ InstallStep: Downloading → Installing
    ↓
安裝方式選擇:                                                    ⛔ 全部不可用
  1. System: 啟動系統 PackageInstaller 對話框                     ⛔ Android PackageInstaller
  2. Private: 複製到 filesDir/exts/{pkgName}.ext（僅限私有安裝）   ⛔ Android 私有安裝
    ↓
ExtensionInstallReceiver 通知完成                                 ⛔ BroadcastReceiver
    ↓
ExtensionManager 重新載入擴充
```

### 3.4 InstallStep 狀態機

```kotlin
enum class InstallStep {
    Idle,        // 閒置
    Pending,     // 等待
    Downloading, // 下載中
    Installing,  // 安裝中
    Installed,   // 已安裝
    Error;       // 錯誤

    fun isCompleted() = this == Installed || this == Error || this == Idle
}
```

### 3.5 擴充載入（App 啟動時）

> ⛔ **iOS 完全不可用** — 此流程的每一步都依賴 Android 專屬 API。
> iOS 不支援動態 ClassLoader、無法讀取 APK manifest metadata、無法反射實例化 Kotlin/Java 類別。
> **這是 Mihon iOS 移植的最大技術障礙。**

**檔案**: `app/src/main/java/eu/kanade/tachiyomi/extension/util/ExtensionLoader.kt`

```
ExtensionLoader.loadExtensions(context)
    ↓
1. 發現已安裝的擴充包:                                    ⛔ iOS 不可用
   - System: getInstalledPackages() 搜索元數據             ⛔ Android PackageManager API
   - Private: filesDir/exts/*.ext 檔案                     ⛔ 依賴 APK 格式
    ↓
2. 簽名驗證:                                              ⛔ iOS 不可用
   - TrustExtension.isTrusted(pkgInfo, fingerprints)       ⛔ Android PackageInfo
   - 不信任 → LoadResult.Untrusted
    ↓
3. ClassLoader 載入:                                      ⛔ iOS 完全不可用
   - 使用 ChildFirstPathClassLoader（子優先策略）           ⛔ JVM ClassLoader
   - 讀取 manifest metadata:                               ⛔ AndroidManifest.xml
     * tachiyomi.extension.class → 源類名稱（分號分隔）
     * tachiyomi.extension.factory → SourceFactory 類名
   - 反射實例化                                            ⛔ Java Reflection
   - 調用 SourceFactory.createSources()                    ⛔ 動態類別載入
    ↓
4. 建立 Extension.Installed:
   - 包含 name, pkgName, versionName, versionCode
   - libVersion（從版本字串提取）
   - sources: List<Source>（實際可用的源實例）               ⛔ 動態實例化的物件
    ↓
回傳 List<LoadResult> (Success | Untrusted | Error)
```

### 3.6 更新檢測

```kotlin
suspend fun checkForUpdates(): List<Extension.Installed>? {
    // 1. 速率限制 — 每天最多檢查一次
    if (Instant.now() < lastExtCheck + 1.days) return null

    // 2. 先更新所有倉庫元數據
    updateExtensionRepo.awaitAll()

    // 3. 獲取最新的擴充索引
    val availableExtensions = findExtensions()

    // 4. 與已安裝的擴充比較版本
    val installedExtensions = ExtensionLoader.loadExtensions(context)
    val extensionsWithUpdate = installedExtensions.filter { installed ->
        availableExtensions.any { available ->
            available.pkgName == installed.pkgName &&
            (available.versionCode > installed.versionCode ||
             available.libVersion > installed.libVersion)
        }
    }

    // 5. 發送更新通知
    if (extensionsWithUpdate.isNotEmpty()) {
        ExtensionUpdateNotifier(context).promptUpdates(extensionsWithUpdate.map { it.name })
    }

    return extensionsWithUpdate
}
```

---

## 4. Source API 介面體系

### 4.1 介面繼承層級

```
Source (基礎)
  ├── CatalogueSource (瀏覽+搜尋)
  │     └── HttpSource (abstract, HTTP 實現)
  │           └── ParsedHttpSource (abstract, HTML 解析)
  ├── ResolvableSource (URI 解析)
  └── ConfigurableSource (使用者偏好設定)
```

### 4.2 Source — 基礎介面

```kotlin
interface Source {
    val id: Long          // 唯一識別碼（MD5 hash of name+lang+versionId）
    val name: String      // 源名稱
    val lang: String      // ISO 639-1 語言碼

    suspend fun getMangaDetails(manga: SManga): SManga
    suspend fun getChapterList(manga: SManga): List<SChapter>
    suspend fun getPageList(chapter: SChapter): List<Page>
}
```

### 4.3 CatalogueSource — 目錄瀏覽介面

```kotlin
interface CatalogueSource : Source {
    val supportsLatest: Boolean

    suspend fun getPopularManga(page: Int): MangasPage
    suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage
    suspend fun getLatestUpdates(page: Int): MangasPage
    fun getFilterList(): FilterList
}
```

### 4.4 HttpSource — HTTP 源抽象類

> ⛔ **iOS 部分不可用** — `Request`/`Response` 為 OkHttp 型別，需替換為 `URLRequest`/`URLResponse`。
> 整個抽象類的實現由 APK 擴充透過 ClassLoader 動態提供，iOS 無法使用相同機制。
> **iOS 需以其他方式（如 JS/WASM 解釋器）提供每個 source 的具體解析邏輯。**

```kotlin
abstract class HttpSource : CatalogueSource {
    abstract val baseUrl: String
    open val versionId = 1

    // ID 自動生成
    override val id by lazy { generateId(name, lang, versionId) }

    // 每個操作都是「請求 + 解析」配對（⛔ Request/Response 為 OkHttp 型別）
    protected abstract fun popularMangaRequest(page: Int): Request
    protected abstract fun popularMangaParse(response: Response): MangasPage

    protected abstract fun searchMangaRequest(page: Int, query: String, filters: FilterList): Request
    protected abstract fun searchMangaParse(response: Response): MangasPage

    protected abstract fun latestUpdatesRequest(page: Int): Request
    protected abstract fun latestUpdatesParse(response: Response): MangasPage

    protected abstract fun mangaDetailsRequest(manga: SManga): Request
    protected abstract fun mangaDetailsParse(response: Response): SManga

    protected abstract fun chapterListRequest(manga: SManga): Request
    protected abstract fun chapterListParse(response: Response): List<SChapter>

    protected abstract fun pageListRequest(chapter: SChapter): Request
    protected abstract fun pageListParse(response: Response): List<Page>

    // 圖片 URL 解析（部分源需要二次請求）
    protected open fun imageUrlRequest(page: Page): Request
    protected open fun imageUrlParse(response: Response): String
    open fun imageRequest(page: Page): Request
}
```

### 4.5 ParsedHttpSource — HTML 解析源

> ⛔ **iOS 部分不可用** — Jsoup 為 Java HTML 解析器，iOS 需替換為 SwiftSoup 或 Kanna。
> `Element` 型別與 Jsoup API 不可直接使用。

```kotlin
abstract class ParsedHttpSource : HttpSource() {
    // 使用 Jsoup CSS 選擇器解析 HTML（⛔ Jsoup = Java 專屬，iOS 需用 SwiftSoup/Kanna）
    override fun popularMangaParse(response: Response): MangasPage {
        val document = response.asJsoup()
        val mangas = document.select(popularMangaSelector()).map {
            popularMangaFromElement(it)
        }
        val hasNextPage = popularMangaNextPageSelector()?.let {
            document.select(it).first()
        } != null
        return MangasPage(mangas, hasNextPage)
    }

    protected abstract fun popularMangaSelector(): String
    protected abstract fun popularMangaFromElement(element: Element): SManga
    protected abstract fun popularMangaNextPageSelector(): String?

    // 同樣的模式適用於:
    // searchManga, latestUpdates, mangaDetails, chapterList, pageList
}
```

### 4.6 ResolvableSource — URI 解析介面

```kotlin
interface ResolvableSource : Source {
    fun getUriType(uri: String): UriType
    suspend fun getManga(uri: String): SManga?
    suspend fun getChapter(uri: String): SChapter?
}

sealed interface UriType {
    data object Manga : UriType
    data object Chapter : UriType
    data object Unknown : UriType
}
```

### 4.7 ConfigurableSource — 可配置源

> ⛔ **iOS 不可用** — `SharedPreferences` 和 `PreferenceScreen` 為 Android 專屬 API。
> iOS 替代：`UserDefaults` + SwiftUI `Form`/`Settings` 畫面。

```kotlin
interface ConfigurableSource : Source {
    fun getSourcePreferences(): SharedPreferences      // ⛔ Android SharedPreferences
    fun setupPreferenceScreen(screen: PreferenceScreen) // ⛔ Android PreferenceScreen UI
}
```

### 4.8 資料模型

#### SManga

```kotlin
interface SManga : Serializable {
    var url: String              // 相對路徑（如 "/manga/123"）
    var title: String
    var artist: String?
    var author: String?
    var description: String?
    var genre: String?           // 逗號分隔的標籤
    var status: Int              // UNKNOWN=0, ONGOING=1, COMPLETED=2, LICENSED=3, ...
    var thumbnail_url: String?
    var update_strategy: UpdateStrategy  // ALWAYS_UPDATE / ONLY_FETCH_ONCE
    var initialized: Boolean
}
```

#### SChapter

```kotlin
interface SChapter : Serializable {
    var url: String
    var name: String
    var date_upload: Long        // 上傳時間戳
    var chapter_number: Float    // 章節編號
    var scanlator: String?       // 翻譯組
}
```

#### Page

```kotlin
open class Page(
    val index: Int,              // 頁面索引
    val url: String = "",        // 頁面 URL（可能需要二次請求）
    var imageUrl: String? = null // 圖片直連 URL
) {
    val number: Int get() = index + 1

    sealed interface State {
        data object Queue : State
        data object LoadPage : State
        data object DownloadImage : State
        data object Ready : State
        data class Error(val error: Throwable) : State
    }
}
```

#### MangasPage

```kotlin
data class MangasPage(
    val mangas: List<SManga>,
    val hasNextPage: Boolean
)
```

### 4.9 過濾器系統

```kotlin
sealed class Filter<T>(val name: String, var state: T) {
    open class Header(name: String) : Filter<Any>(name, 0)
    open class Separator(name: String = "") : Filter<Any>(name, 0)
    abstract class Select<V>(name: String, val values: Array<V>, state: Int = 0)
        : Filter<Int>(name, state)
    abstract class Text(name: String, state: String = "")
        : Filter<String>(name, state)
    abstract class CheckBox(name: String, state: Boolean = false)
        : Filter<Boolean>(name, state)
    abstract class TriState(name: String, state: Int = STATE_IGNORE)
        : Filter<Int>(name, state) {
        companion object {
            const val STATE_IGNORE = 0
            const val STATE_INCLUDE = 1
            const val STATE_EXCLUDE = 2
        }
    }
    abstract class Sort(name: String, val values: Array<String>, state: Selection? = null)
        : Filter<Sort.Selection?>(name, state) {
        data class Selection(val index: Int, val ascending: Boolean)
    }
    abstract class Group<V>(name: String, state: List<V>)
        : Filter<List<V>>(name, state)
}

data class FilterList(val list: List<Filter<*>>) : List<Filter<*>> by list
```

---

## 5. 漫畫內容獲取流程

### 5.1 SourceManager — 源管理器

**介面**: `domain/src/main/java/tachiyomi/domain/source/service/SourceManager.kt`

```kotlin
interface SourceManager {
    val isInitialized: StateFlow<Boolean>
    val catalogueSources: Flow<List<CatalogueSource>>
    fun get(sourceKey: Long): Source?
    fun getOrStub(sourceKey: Long): Source  // 如擴充已卸載，回傳 StubSource
    fun getCatalogueSources(): List<CatalogueSource>
    fun getStubSources(): List<StubSource>
}
```

**實現**: `app/src/main/java/eu/kanade/tachiyomi/source/AndroidSourceManager.kt`

> ⛔ **iOS 部分不可用** — 源註冊依賴 `extensionManager.installedExtensionsFlow`，
> 而 `installedExtensionsFlow` 的來源是 APK ClassLoader 動態載入的 Source 實例。
> iOS 需設計替代的 Source 實例化與註冊機制。

#### 源註冊流程:

```kotlin
init {
    scope.launch {
        extensionManager.installedExtensionsFlow       // ⛔ 依賴 APK 動態載入
            .collectLatest { extensions ->
                val mutableMap = ConcurrentHashMap<Long, Source>(
                    mapOf(LocalSource.ID to LocalSource(...))
                )
                extensions.forEach { ext ->
                    ext.sources.forEach { source ->      // ⛔ source 由 ClassLoader 實例化
                        mutableMap[source.id] = source
                        registerStubSource(StubSource.from(source))
                    }
                }
                sourcesMapFlow.value = mutableMap
                _isInitialized.value = true
            }
    }
}
```

### 5.2 瀏覽漫畫流程

```
┌─────────────┐    ┌──────────────────┐    ┌──────────────┐
│ Sources 畫面 │───▶│ Browse Source 畫面│───▶│ 漫畫詳情畫面  │
│ (源列表)     │    │ (漫畫列表)        │    │ (章節列表)    │
└─────────────┘    └──────────────────┘    └──────────────┘
```

#### 架構分層:

```
SourcesScreen (UI)
    ↓
BrowseSourceScreenModel (Presentation)
    ↓
GetRemoteManga (Domain Interactor)
    ↓
SourceRepositoryImpl (Data)
    ↓
SourcePagingSource (Paging)
    ↓
CatalogueSource.getPopularManga() / getLatestUpdates() / getSearchManga()
```

#### 分頁數據流:

```kotlin
// BrowseSourceScreenModel
val mangaPagerFlow = Pager(PagingConfig(pageSize = 25)) {
    getRemoteManga(sourceId, listing.query, listing.filters)
}.flow.cachedIn(coroutineScope)

// GetRemoteManga — 路由不同請求
operator fun invoke(sourceId: Long, query: String, filterList: FilterList): SourcePagingSource {
    return when (query) {
        QUERY_POPULAR -> repository.getPopular(sourceId)
        QUERY_LATEST  -> repository.getLatest(sourceId)
        else          -> repository.search(sourceId, query, filterList)
    }
}

// SourcePagingSource — 實際 API 呼叫
override suspend fun load(params: LoadParams<Long>): LoadResult<Long, Manga> {
    val page = params.key ?: 1
    val mangasPage = source.getPopularManga(page.toInt())  // 調用源實現
    return LoadResult.Page(
        data = mangasPage.mangas.map { it.toDomainManga(source.id) },
        prevKey = null,
        nextKey = if (mangasPage.hasNextPage) page + 1 else null,
    )
}
```

### 5.3 漫畫詳情與章節獲取

**ScreenModel**: `eu/kanade/tachiyomi/ui/manga/MangaScreenModel.kt`

```kotlin
// 先顯示本地快取，同時在後台更新
init {
    screenModelScope.launchIO {
        val manga = getMangaAndChapters.awaitManga(mangaId)
        val chapters = getMangaAndChapters.awaitChapters(mangaId)

        mutableState.update {
            State.Success(
                manga = manga,
                source = sourceManager.getOrStub(manga.source),
                chapters = chapters.toChapterListItems(manga),
            )
        }

        // 後台更新
        if (needRefreshInfo) fetchMangaFromSource()
        if (needRefreshChapter) fetchChaptersFromSource()
    }
}

// 從源獲取最新資料
private suspend fun fetchMangaFromSource() {
    val networkManga = state.source.getMangaDetails(state.manga.toSManga())
    updateManga.awaitUpdateFromSource(state.manga, networkManga)
}

private suspend fun fetchChaptersFromSource() {
    val chapters = state.source.getChapterList(state.manga.toSManga())
    syncChaptersWithSource.await(chapters, state.manga, state.source)
}
```

### 5.4 頁面與圖片載入

#### PageLoader 類型:

| Loader | 用途 |
|--------|------|
| `HttpPageLoader` | 線上源（漫畫網站） |
| `DownloadPageLoader` | 已下載章節 |
| `DirectoryPageLoader` | 本地資料夾 |
| `ArchivePageLoader` | ZIP/RAR 壓縮檔 |
| `EpubPageLoader` | EPUB 格式 |

#### HttpPageLoader 流程:

```kotlin
// 1. 取得頁面列表
override suspend fun getPages(): List<ReaderPage> {
    val pages = try {
        chapterCache.getPageListFromCache(chapter)  // 優先快取
    } catch (e: Throwable) {
        source.getPageList(chapter)                  // 回退到網路
    }
    return pages.mapIndexed { index, page ->
        ReaderPage(index, page.url, page.imageUrl)
    }
}

// 2. 載入頁面圖片（帶預載入）
override suspend fun loadPage(page: ReaderPage) {
    // 加入優先隊列（當前頁優先級 1）
    queue.offer(PriorityPage(page, priority = 1))
    // 預載入接下來 4 頁（優先級 0）
    preloadNextPages(page, preloadSize = 4)
}
```

---

## 6. 信任與簽名驗證系統

### 6.1 TrustExtension

> ⛔ **iOS 部分不可用** — `PackageInfo` 為 Android 專屬型別，APK 簽名提取與驗證機制無法在 iOS 使用。
> iOS 需設計替代的驗證方案（如：對下載的擴充資源計算 SHA256 雜湊值進行比對）。

**檔案**: `app/src/main/java/eu/kanade/domain/extension/interactor/TrustExtension.kt`

```kotlin
suspend fun isTrusted(pkgInfo: PackageInfo, fingerprints: List<String>): Boolean {
    //                ⛔ PackageInfo = Android 專屬型別
    // 1. 取得所有倉庫的信任簽名指紋
    val trustedFingerprints = extensionRepoRepository.getAll()
        .map { it.signingKeyFingerprint }
        .toHashSet()

    // 2. 自動信任：倉庫簽名指紋匹配
    if (trustedFingerprints.any { fingerprints.contains(it) }) return true

    // 3. 手動信任：使用者確認後記錄
    val key = "${pkgInfo.packageName}:${versionCode}:${fingerprints.last()}" // ⛔ PackageInfo
    return key in preferences.trustedExtensions().get()
}

fun trust(pkgName: String, versionCode: Long, signatureHash: String) {
    preferences.trustedExtensions().getAndSet { exts ->
        val cleaned = exts.filterNot { it.startsWith("$pkgName:") }.toMutableSet()
        cleaned += "$pkgName:$versionCode:$signatureHash"
        cleaned
    }
}
```

### 6.2 信任機制

> ⛔ **iOS 部分不可用** — APK 簽名驗證為 Android 專屬。
> 倉庫指紋比對邏輯可復用，但簽名提取來源需重新設計。

```
擴充載入
    ↓
驗證 APK 簽名 → 取得 fingerprint                          ⛔ APK 簽名 = Android 專屬
    ↓
┌─── 檢查是否在倉庫信任列表 ───┐
│  repo.signingKeyFingerprint   │                          ✅ 邏輯可復用
│  ==                           │
│  extension.signatureHash      │                          ⛔ 來源為 APK 簽名
└───────────┬───────────────────┘
            │ YES → ✅ 自動信任 (LoadResult.Success)
            │ NO ↓
┌─── 檢查使用者手動信任列表 ────┐                           ✅ 邏輯可復用
│  "pkgName:versionCode:hash"   │
│  in                           │
│  preferences.trustedExtensions│
└───────────┬───────────────────┘
            │ YES → ✅ 手動信任 (LoadResult.Success)
            │ NO → ⚠️ 不信任 (LoadResult.Untrusted)
```

---

## 7. 關鍵檔案索引

### Domain Layer

| 檔案 | 說明 |
|------|------|
| `domain/src/.../extensionrepo/model/ExtensionRepo.kt` | 倉庫資料模型 |
| `domain/src/.../extensionrepo/interactor/CreateExtensionRepo.kt` | 新增倉庫 |
| `domain/src/.../extensionrepo/interactor/DeleteExtensionRepo.kt` | 刪除倉庫 |
| `domain/src/.../extensionrepo/interactor/GetExtensionRepo.kt` | 查詢倉庫 |
| `domain/src/.../extensionrepo/interactor/UpdateExtensionRepo.kt` | 更新倉庫元數據 |
| `domain/src/.../extensionrepo/interactor/ReplaceExtensionRepo.kt` | 替換倉庫 |
| `domain/src/.../extensionrepo/interactor/GetExtensionRepoCount.kt` | 倉庫數量 |
| `domain/src/.../extensionrepo/service/ExtensionRepoService.kt` | 倉庫網路服務介面 |
| `domain/src/.../extensionrepo/repository/ExtensionRepoRepository.kt` | 倉庫 Repository 介面 |
| `domain/src/.../source/service/SourceManager.kt` | 源管理器介面 |
| `domain/src/.../source/interactor/GetRemoteManga.kt` | 遠端漫畫獲取 |

### Data Layer

| 檔案 | 說明 |
|------|------|
| `data/src/.../sqldelight/.../extension_repos.sq` | 倉庫 DB Schema |
| `data/src/.../source/SourceRepositoryImpl.kt` | 源 Repository 實現 |
| `data/src/.../source/SourcePagingSource.kt` | 分頁數據源 |

### App Layer

| 檔案 | 說明 |
|------|------|
| `app/src/.../extension/api/ExtensionApi.kt` | 擴充 API（fetch index.min.json、APK URL） |
| `app/src/.../extension/ExtensionManager.kt` | 擴充管理器（安裝、更新、卸載） |
| `app/src/.../extension/util/ExtensionInstaller.kt` | 擴充安裝器 |
| `app/src/.../extension/util/ExtensionLoader.kt` | 擴充載入器（ClassLoader） |
| `app/src/.../extension/model/Extension.kt` | Extension sealed class |
| `app/src/.../extension/model/InstallStep.kt` | 安裝步驟狀態 |
| `app/src/.../extension/model/LoadResult.kt` | 載入結果 |
| `app/src/.../domain/extension/interactor/TrustExtension.kt` | 信任驗證 |
| `app/src/.../source/AndroidSourceManager.kt` | 源管理器實現 |

### Source API

| 檔案 | 說明 |
|------|------|
| `source-api/src/.../api/source/Source.kt` | 基礎源介面 |
| `source-api/src/.../api/source/CatalogueSource.kt` | 目錄源介面 |
| `source-api/src/.../api/source/HttpSource.kt` | HTTP 源抽象類 |
| `source-api/src/.../api/source/ParsedHttpSource.kt` | HTML 解析源 |
| `source-api/src/.../api/source/ConfigurableSource.kt` | 可配置源 |
| `source-api/src/.../api/source/ResolvableSource.kt` | URI 解析源 |
| `source-api/src/.../model/SManga.kt` | 漫畫模型 |
| `source-api/src/.../model/SChapter.kt` | 章節模型 |
| `source-api/src/.../model/Page.kt` | 頁面模型 |
| `source-api/src/.../model/MangasPage.kt` | 漫畫分頁結果 |
| `source-api/src/.../model/Filter.kt` | 過濾器系統 |

---

## 附錄：iOS 移植注意事項

### ⛔ iOS 不可用項目總覽

| 嚴重度 | 項目 | 涉及章節 | 說明 |
|--------|------|---------|------|
| 🔴 **致命** | APK ClassLoader 動態載入 | §3.3, §3.5, §5.1 | iOS 無法動態載入 JVM 類別，**整個擴充載入機制需重新設計** |
| 🔴 **致命** | APK 安裝（System/Private） | §3.3 | iOS 無 PackageInstaller，無法安裝 APK |
| 🔴 **致命** | Java Reflection 實例化 Source | §3.5 | SourceFactory.createSources() 透過反射，iOS 完全不支援 |
| 🟠 **重大** | APK 簽名驗證 (PackageInfo) | §3.5, §6.1, §6.2 | Android 專屬簽名機制，需替代驗證方案 |
| 🟠 **重大** | BroadcastReceiver 安裝監聽 | §3.3 | Android 專屬 IPC 機制 |
| 🟡 **中等** | OkHttp Request/Response | §4.4 | 需替換為 URLSession，介面設計可保留 |
| 🟡 **中等** | Jsoup HTML 解析 | §4.5 | 需替換為 SwiftSoup/Kanna，選擇器語法相容 |
| 🟡 **中等** | SharedPreferences + PreferenceScreen | §4.7 | 需替換為 UserDefaults + SwiftUI Form |
| 🟢 **輕微** | Android Drawable 型別 | §3.1 | 替換為 UIImage/Image 即可 |
| 🟢 **輕微** | SQLDelight | §2.2 | 替換為 SwiftData/GRDB/SQLite.swift |

### Android 特有機制（iOS 需替代方案）

| Android 機制 | 說明 | iOS 替代方向 | 嚴重度 |
|-------------|------|-------------|--------|
| APK 安裝 + ClassLoader | 動態載入擴充套件的 class | JavaScript/WASM 解釋器 或 JSON 配置驅動 | 🔴 致命 |
| Java Reflection | 從 APK 反射實例化 Source 類別 | JS 引擎 (JavaScriptCore) 或編譯時靜態連結 | 🔴 致命 |
| PackageManager | 掃描已安裝擴充 | 檔案系統掃描 + Bundle 管理 | 🟠 重大 |
| BroadcastReceiver | 監聰安裝/卸載事件 | FileMonitor / NotificationCenter | 🟠 重大 |
| PackageInfo (APK簽名) | 提取 APK 簽名指紋 | SHA256 雜湊值驗證 | 🟠 重大 |
| OkHttp | 網路請求 | URLSession / Alamofire | 🟡 中等 |
| Jsoup (HTML Parser) | ParsedHttpSource 使用 | SwiftSoup 或 Kanna | 🟡 中等 |
| SharedPreferences | 源的偏好設定 | UserDefaults / SwiftData | 🟡 中等 |
| PreferenceScreen | 源設定 UI | SwiftUI Form / Settings 畫面 | 🟡 中等 |
| Android Drawable | 擴充圖示 | UIImage / SwiftUI Image | 🟢 輕微 |
| SQLDelight | 跨平台 DB | SwiftData / GRDB / SQLite.swift | 🟢 輕微 |

### ✅ 可直接復用的設計

- 倉庫管理（`index.min.json` / `repo.json` 格式完全通用）
- 倉庫 CRUD Interactors 邏輯（CreateExtensionRepo, DeleteExtensionRepo 等）
- Source API 介面設計（`getPopularManga`, `getMangaDetails` 等方法簽名）
- 過濾器系統設計（Filter sealed class 層級結構）
- 信任指紋比對邏輯（倉庫 fingerprint vs 擴充 hash）
- 分頁瀏覽模式（Pager + PagingSource 模式）
- 擴充索引 JSON 解析（`index.min.json` 格式）
- 更新檢測版本比較邏輯
- 漫畫詳情、章節、頁面的資料流（先快取後網路）
