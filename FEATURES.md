# Shinsou iOS 完整功能清單

> 此文件記錄 Shinsou iOS 漫畫閱讀器的完整功能實作狀態。

---

## 目錄

1. [應用架構概覽](#1-應用架構概覽)
2. [圖書館（Library）](#2-圖書館library)
3. [更新（Updates）](#3-更新updates)
4. [歷史（History）](#4-歷史history)
5. [瀏覽（Browse）](#5-瀏覽browse)
6. [更多（More）](#6-更多more)
7. [漫畫詳情（Manga Details）](#7-漫畫詳情manga-details)
8. [閱讀器（Reader）](#8-閱讀器reader)
9. [下載管理（Download Manager）](#9-下載管理download-manager)
10. [追蹤系統（Tracking）](#10-追蹤系統tracking)
11. [備份與還原（Backup & Restore）](#11-備份與還原backup--restore)
12. [iCloud 同步](#12-icloud-同步)
13. [設定（Settings）](#13-設定settings)
14. [安全與隱私（Security & Privacy）](#14-安全與隱私security--privacy)
15. [Widget 小工具](#15-widget-小工具)
16. [遷移系統（Migration）](#16-遷移系統migration)
17. [Deep Linking](#17-deep-linking)
18. [資料模型與資料庫](#18-資料模型與資料庫)
19. [國際化（i18n）](#19-國際化i18n)
20. [關於（About）](#20-關於about)

---

## 1. 應用架構概覽

### 導航結構
- **底部導航列**：5 個主要分頁
  - 圖書館（Library）
  - 更新（Updates）
  - 歷史（History）
  - 瀏覽（Browse）
  - 更多（More）
- **導航框架**：SwiftUI NavigationStack / NavigationSplitView
- **UI 框架**：SwiftUI
- **狀態管理**：@Observable / @StateObject（MVVM 模式）
- **依賴注入**：DIContainer 單例

### 模組架構

| 模組 | 職責 |
|------|------|
| `ShinsouApp` | 主應用（UI + 業務邏輯）|
| `ShinsouDomain` | 領域層（模型與 Repository 介面）|
| `ShinsouData` | 資料層（GRDB 資料庫 + Repository 實作）|
| `ShinsouCore` | 核心工具與常數 |
| `ShinsouSourceAPI` | 來源 API 介面（Source、HttpSource、CatalogueSource）|
| `ShinsouSourceLocal` | 本地來源實作 |
| `ShinsouUI` | 共用 UI 元件 |
| `ShinsouI18n` | 國際化 |

---

## 2. 圖書館（Library）

### 2.1 顯示模式
- **緊湊網格**（Compact Grid）：小型封面卡片
- **舒適網格**（Comfortable Grid）：大型封面卡片，附帶標題
- **列表模式**（List）：水平列表顯示
- **欄位數自訂**：豎屏/橫屏分別設定

### 2.2 分類管理（Categories）
- 建立 / 編輯 / 刪除自訂分類
- 分類排序（拖曳排序）
- 分類標籤頁顯示
- 預設分類設定（新漫畫預設加入的分類）
- 分類項目數量顯示
- 每個分類獨立的顯示設定

### 2.3 篩選功能
- **下載狀態**：已下載 / 未下載
- **閱讀狀態**：未讀 / 已讀
- **開始狀態**：未開始 / 已開始
- **完成狀態**：已完成
- **書籤狀態**：有書籤 / 無書籤
- **追蹤篩選**：依各追蹤服務篩選

### 2.4 排序方式
- 按名稱 / 最後更新時間 / 未讀章節數 / 總章節數
- 按最後閱讀時間 / 最新上傳章節 / 加入日期
- 升序 / 降序切換

### 2.5 徽章顯示
- 未讀章節數量
- 下載章節數量
- 本地源標記
- 語言標記

### 2.6 其他功能
- 「繼續閱讀」按鈕
- 批量選擇與操作（分類設定、標記已讀、下載、刪除）
- 全域搜尋入口
- 下拉刷新更新圖書館

---

## 3. 更新（Updates）

### 3.1 核心功能
- 顯示所有已收藏漫畫的最新章節更新
- 按日期分組顯示

### 3.2 操作
- 點擊章節直接開始閱讀
- 長按進入選擇模式
- 批量標記為已讀 / 未讀
- 批量下載 / 刪除章節
- 批量加入 / 移除書籤

---

## 4. 歷史（History）

### 4.1 核心功能
- 顯示所有已閱讀章節的完整歷史
- 按日期分組
- 搜尋歷史記錄

### 4.2 項目操作
- 點擊繼續閱讀
- 刪除單筆歷史記錄
- 刪除該漫畫所有歷史
- 顯示漫畫封面、標題、章節名稱、最後閱讀時間

---

## 5. 瀏覽（Browse）

### 5.1 來源（Sources）子分頁
- 來源列表（按語言分組）
- 來源啟用 / 停用
- 來源釘選（常用優先顯示）
- 來源語言篩選
- NSFW 來源顯示 / 隱藏

### 5.2 插件系統（Extensions）子分頁

Shinsou 使用 JavaScript 插件系統替代 Android 的 APK 擴展安裝機制。

#### 5.2.1 插件列表與分組
- **更新待機組**：有新版本可更新的插件
- **已安裝組**：目前已安裝的插件
- **可用組**：按語言分組顯示可安裝的插件
- **未信任組**：雜湊值未驗證的插件

#### 5.2.2 插件安裝
- 從社群倉庫下載 `.js` 插件腳本與 `.json` manifest
- 安裝至 `Documents/Plugins/` 目錄
- 安裝後自動載入為來源
- **安裝流程**：Idle → Downloading → Installing → Installed / Error

#### 5.2.3 插件驗證
- SHA-256 雜湊驗證：計算 `.js` 檔案的 SHA-256，與 manifest 中的 `signature` 欄位比對
- **PluginTrustStore**：以 `{pkg}:{versionCode}:{sha256}` 格式持久化信任記錄於 UserDefaults
- 已簽名插件：雜湊匹配後自動加入信任庫
- 未簽名插件：拒絕載入（除非已在信任庫中）

#### 5.2.4 插件載入（App 啟動時）
- `PluginLoader.loadAllPlugins()` 掃描 `Documents/Plugins/` 目錄的 `.js` 檔案
- 為每個 `.js` 檔案讀取同名 `.json` manifest
- 透過 `PluginVerifier` 驗證雜湊與信任狀態
- 成功驗證後建立 `JSSourceProxy` 實例（實作 `CatalogueSource` 協定）

#### 5.2.5 JS 插件執行環境
- **引擎**：Apple JavaScriptCore
- **Bridge API**：`JSBridge` 提供原生能力給 JS 插件
  - HTTP 請求（GET/POST，含自訂 Header）
  - DOM 解析（基於 SwiftSoup 的 handle-based API）
  - 偏好設定讀寫
  - 日誌記錄
- **DOM 模擬庫**：`JSDomLib` 注入 Jsoup 相容的 DOM API（`Jsoup.parse()`、`Element.select()` 等）
- **兩種插件模式**：
  1. **Full mode** — 插件定義完整的 `source` 物件
  2. **ParsedHttpSource mode** — 插件定義 CSS 選擇器，由執行時處理 HTML 解析

### 5.3 插件倉庫管理（Extension Repos）

#### 5.3.1 倉庫資料模型
```
ExtensionRepo:
  - baseUrl: String（主鍵，倉庫 URL）
  - name: String（倉庫名稱）
  - shortName: String?（縮寫）
  - website: String（倉庫網站）
  - signingKeyFingerprint: String（簽名金鑰指紋）
```

#### 5.3.2 倉庫管理功能
- 新增倉庫（輸入 URL → 獲取 `repo.json` → 驗證 → 儲存）
- 更新倉庫元資料
- 刪除倉庫
- URL 格式驗證、重複 URL 檢查、簽名指紋重複檢查

#### 5.3.3 插件索引格式（`index.json`）

社群插件倉庫（如 `shinsou_plugin`）使用以下格式：

```json
[{
  "id": "en.mangadex",
  "name": "MangaDex",
  "version": "1.0.0",
  "versionCode": 1,
  "lang": "en",
  "nsfw": 0,
  "scriptUrl": "plugins/en.mangadex.js",
  "iconUrl": "icons/en.mangadex.png",
  "description": "MangaDex source plugin",
  "sources": [{ "name": "MangaDex", "lang": "en", "id": 2499283573021220255, "baseUrl": "https://mangadex.org" }]
}]
```

同時相容 Android Mihon 倉庫的 `index.min.json` 格式（`ExtensionIndexEntry`），可讀取來源元資料。

### 5.4 瀏覽來源（Browse Source）
- 搜尋特定來源的漫畫
- 高級篩選選項（依來源提供）
- 最新更新 / 人氣排行

### 5.5 全域搜尋（Global Search）
- 跨所有已啟用來源搜尋
- 即時搜尋結果
- 來源篩選

---

## 6. 更多（More）

### 6.1 頁面項目
- **下載隊列**：管理當前下載任務
- **統計**：閱讀統計數據
- **設定**：完整設定選單
- **關於**：版本、授權、隱私權政策

### 6.2 快速切換
- **下載專用模式**（Download Only）：僅閱讀已下載章節
- **隱身模式**（Incognito Mode）：不記錄閱讀歷史

---

## 7. 漫畫詳情（Manga Details）

### 7.1 資訊顯示
- 封面圖片（可點擊放大 / 儲存 / 分享 / 設為封面）
- 標題、作者 / 繪者
- 狀態（連載中 / 已完結 / 暫停 / 授權 / 未知）
- 來源名稱、描述 / 簡介
- 標籤 / 流派（可點擊搜尋）

### 7.2 操作按鈕
- 加入收藏 / 移除收藏
- 追蹤管理
- WebView 開啟原始網頁
- 分享連結

### 7.3 筆記功能（Notes）
- 為每部漫畫撰寫個人筆記

### 7.4 章節列表
- 章節名稱 / 編號顯示、掃描組資訊、上傳日期
- 閱讀進度指示、書籤標記、下載狀態指示

### 7.5 章節篩選與排序
- 依閱讀狀態 / 下載狀態 / 書籤狀態篩選
- 按來源 / 章節編號 / 上傳日期 / 字母排序
- 升序 / 降序

### 7.6 批量操作
- 多選章節
- 批量標記已讀 / 未讀、下載、刪除
- 批量加入 / 移除書籤
- 標記前面所有為已讀

---

## 8. 閱讀器（Reader）

### 8.1 閱讀模式

| 模式 | 說明 |
|------|------|
| **左到右翻頁**（L2R Pager）| 從左到右翻頁 |
| **右到左翻頁**（R2L Pager）| 從右到左翻頁（日本漫畫）|
| **垂直翻頁**（Vertical Pager）| 上下翻頁 |
| **Webtoon 模式** | 連續垂直捲動（條漫）|

### 8.2 縮放與裁切
- 圖像縮放類型：適應螢幕 / 適應寬度 / 適應高度 / 原始大小
- 裁切邊框（Pager / Webtoon 各自獨立）
- 雙頁分割模式

### 8.3 顯示設定
- 頁碼指示器
- 全螢幕模式
- 保持螢幕常亮
- 閱讀器主題：黑色 / 灰色 / 白色 / 自動
- 章節轉換頁面

### 8.4 色彩濾鏡
- 自訂亮度
- 色彩濾鏡（RGBA 可調）
- 灰階模式、反色模式

### 8.5 控制方式
- 觸控區域導航
- 音量鍵翻頁（透過 KVO 監聽 `AVAudioSession.outputVolume`，以 `MPVolumeView` 抑制系統 HUD）
- 手勢操作：單擊、雙擊縮放、捲動、平移

### 8.6 頁面載入

| 載入器 | 適用場景 |
|--------|----------|
| HttpPageLoader | 線上來源（預載 4 頁）|
| DownloadPageLoader | 已下載章節 |
| ArchivePageLoader | CBZ/ZIP 壓縮檔 |
| EpubPageLoader | EPUB 格式 |
| DirectoryPageLoader | 本地資料夾 |

- 高圖像分割：將過長的圖片分割為多頁

---

## 9. 下載管理（Download Manager）

### 9.1 下載隊列
- 查看當前下載進度、暫停 / 恢復 / 取消下載
- 重新排序下載順序

### 9.2 下載設定
- 僅在 WiFi 下載
- 儲存格式：CBZ 壓縮 / 資料夾
- 並行來源數：1-10（預設 5）
- 每來源並行頁面數：1-15（預設 5）

### 9.3 自動下載
- 閱讀時自動下載下一章
- 新章節自動下載
- 按分類限制新章節下載

### 9.4 自動刪除章節
- 標記為已讀後刪除
- 排除已加書籤的章節

---

## 10. 追蹤系統（Tracking）

### 10.1 支援的追蹤服務

| 服務 | 認證方式 | 特殊功能 |
|------|----------|----------|
| **MyAnimeList** | OAuth2 | 標準追蹤 |
| **AniList** | OAuth2 | 多種評分類型 |
| **Kitsu** | 帳號密碼 | 日期追蹤 |
| **MangaUpdates** | 帳號密碼 | 漫畫元資料 |
| **Shikimori** | OAuth2 | 俄文社群 |
| **Bangumi** | OAuth2 | 中文社群 |
| **Komga** | 自託管 | 漫畫伺服器 |
| **Suwayomi** | 自託管 | Tachiyomi 伺服器 |
| **Kavita** | 自託管 | 漫畫伺服器 |

### 10.2 追蹤功能
- 搜尋遠端漫畫並綁定
- 同步閱讀進度（章節數）
- 設定閱讀狀態（閱讀中 / 計劃閱讀 / 已完成 / 暫停 / 棄讀 / 重讀）
- 設定評分、開始 / 完成日期
- 標記為已讀時自動更新追蹤
- 延遲追蹤更新機制（debounce 3 秒批量處理）

---

## 11. 備份與還原（Backup & Restore）

### 11.1 備份內容
- 漫畫資訊、分類、章節閱讀狀態與書籤
- 追蹤資料、閱讀歷史
- 應用設定、來源設定、擴展倉庫列表

### 11.2 備份格式
- **檔案副檔名**：`.shinsoubackup`（UTType: `com.shinsou.backup`）
- **向後相容**：支援匯入舊的 `.mihonbackup` 檔案（UTType: `com.mihon.backup`）
- **序列化格式**：Codable JSON + gzip 壓縮

### 11.3 自動備份
- 備份間隔：關閉 / 6 小時 / 12 小時 / 24 小時 / 48 小時 / 每週
- 保留份數：最近 3 份自動備份

### 11.4 還原功能
- 選擇性還原（可選擇還原哪些資料類別）
- 來源映射（舊來源 ID → 新來源的映射）

---

## 12. iCloud 同步

### 12.1 iCloud Drive 備份同步
- 自動將備份檔案上傳到 iCloud Drive（`Documents/Backups/`）
- 列舉雲端備份、下載還原
- 保留最近 3 份雲端備份
- 新裝置偵測：本機為空且 iCloud 有備份時提示還原
- 使用 `NSMetadataQuery` 監控雲端變更

### 12.2 CloudKit 即時同步
- 使用 `CKFetchRecordZoneChangesOperation` + `CKModifyRecordsOperation`（相容 iOS 16）
- 同步內容：閱讀進度、書庫變更、分類、追蹤資料、歷史記錄
- 衝突解決：`read` 欄位 OR 合併、`lastPageRead` / `lastChapterRead` 取 max、其餘 Last-Write-Wins
- 推送時機：DB 寫入後 debounce 3 秒批次推送
- 拉取時機：App 啟動、收到 CloudKit 推播、手動觸發
- 使用 GRDB TransactionObserver 自動攔截寫入操作

### 12.3 CloudKit 安全機制
- 執行時解析 `embedded.mobileprovision` 檢查 CloudKit 權限
- 無 CloudKit 權限時不建立 `CKContainer`（避免 SIGTRAP 崩潰）
- 切換 Toggle 時顯示提示 Alert

---

## 13. 設定（Settings）

### 13.1 外觀設定
- 主題模式：系統 / 淺色 / 深色
- AMOLED 深色模式（純黑背景）

### 13.2 圖書館設定
- 顯示模式與排序
- 欄數設定、分類管理
- 徽章與繼續閱讀按鈕設定

### 13.3 閱讀器設定
- 見第 8 節

### 13.4 下載設定
- 見第 9 節

### 13.5 瀏覽設定
- 來源語言篩選
- NSFW 來源顯示
- 擴展倉庫管理

### 13.6 追蹤設定
- 各追蹤服務認證管理

### 13.7 備份與還原設定
- 手動 / 自動備份（見第 11 節）

### 13.8 iCloud 同步設定
- iCloud 帳號狀態 / 上次同步時間
- iCloud Drive 備份同步開關、雲端備份列表
- CloudKit 即時同步開關、立即同步、重設雲端資料

### 13.9 網路與進階設定
- DNS over HTTPS（DoH）
- 自訂 User-Agent
- 資料庫清理功能

---

## 14. 安全與隱私（Security & Privacy）

### 14.1 應用鎖定
- 生物辨識鎖定（Face ID / Touch ID）
- 鎖定超時設定

### 14.2 安全螢幕
- 防止在最近使用清單中預覽螢幕內容

### 14.3 隱身模式（Incognito）
- 啟用時不記錄閱讀歷史
- 不更新閱讀進度

---

## 15. Widget 小工具

- 使用 WidgetKit 框架
- 顯示最近更新的漫畫封面
- 點擊直接開啟漫畫

---

## 16. 遷移系統（Migration）

### 16.1 核心功能
- 將漫畫從一個來源遷移到另一個來源
- 保留章節閱讀狀態、分類分配、追蹤資料

### 16.2 資料庫遷移
- 從 `mihon.db` 自動遷移到 `shinsou.db`（含 WAL/SHM 附屬檔案）
- 首次啟動時自動執行

---

## 17. Deep Linking

### 17.1 URL Scheme
- `shinsou://manga/{id}` — 導向特定漫畫
- `shinsou://chapter/{id}` — 導向特定章節
- `shinsou://library` — 打開圖書館
- `shinsou://updates` — 打開更新頁面
- `shinsou://source/{id}` — 導向特定來源

### 17.2 備份檔案
- 點擊 `.shinsoubackup` / `.mihonbackup` 檔案直接觸發還原流程

---

## 18. 資料模型與資料庫

### 18.1 資料庫引擎
- **GRDB.swift**（Swift SQLite ORM）
- 檔案名稱：`shinsou.db`

### 18.2 核心資料表

| 資料表 | 用途 |
|--------|------|
| `mangas` | 漫畫資訊（source, url, title, author, favorite, viewer, notes 等）|
| `chapters` | 章節資訊（manga_id, url, name, read, bookmark, last_page_read 等）|
| `categories` | 分類（name, sort, flags）|
| `mangas_categories` | 漫畫-分類關聯 |
| `manga_sync` | 追蹤同步資料 |
| `history` | 閱讀歷史 |
| `sources` | 來源資訊 |
| `extension_repos` | 擴展倉庫 |

---

## 19. 國際化（i18n）

### 19.1 支援語言

| 代碼 | 語言 |
|------|------|
| `en` | 英文（預設）|
| `zh-Hant` | 繁體中文 |
| `zh-Hans` | 簡體中文 |
| `ja` | 日文 |
| `ko` | 韓文 |
| `fr` | 法文 |
| `de` | 德文 |
| `es` | 西班牙文 |
| `pt` | 葡萄牙文 |

### 19.2 語言管理
- `LanguageManager` 支援執行時語言切換（無需重啟應用程式）
- 支援系統語言自動跟隨
- 所有 UI 字串透過 `ShinsouI18n` 套件的 `MR.strings` 統一管理

---

## 20. 關於（About）

### 20.1 頁面內容
- 應用程式圖示、名稱、版本號與 build number
- **GitHub** — 連結至 [https://github.com/aluo96078/shinsou](https://github.com/aluo96078/shinsou)
- **聯絡開發者** — 開啟郵件寄信至 aluo96078@gmail.com
- **開源憑證** — 指向專案的 MIT License（master 分支）
- **隱私權政策** — 完整的隱私權政策頁面

### 20.2 開源授權清單
- GRDB.swift（MIT）
- Nuke / NukeUI（MIT）
- JavaScriptCore（LGPL / Apple）
- Swift Collections（Apache 2.0）
- Swift Algorithms（Apache 2.0）
