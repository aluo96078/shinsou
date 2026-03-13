# Mihon 完整功能清單

> 基於 Mihon Android 原始碼（v0.19.4）深度分析，作為 iOS 移植參考。

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
12. [設定（Settings）](#12-設定settings)
13. [安全與隱私（Security & Privacy）](#13-安全與隱私security--privacy)
14. [通知系統（Notifications）](#14-通知系統notifications)
15. [Widget 小工具](#15-widget-小工具)
16. [遷移系統（Migration）](#16-遷移系統migration)
17. [即將推出（Upcoming）](#17-即將推出upcoming)
18. [統計（Statistics）](#18-統計statistics)
19. [網路與進階設定](#19-網路與進階設定)
20. [入門引導（Onboarding）](#20-入門引導onboarding)
21. [Deep Linking](#21-deep-linking)
22. [資料模型與資料庫](#22-資料模型與資料庫)

---

## 1. 應用架構概覽

### 導航結構
- **底部導航列**：5 個主要分頁
  - 圖書館（Library）
  - 更新（Updates）
  - 歷史（History）
  - 瀏覽（Browse）
  - 更多（More）
- **導航框架**：Voyager（類型安全導航）
- **UI 框架**：Jetpack Compose + Material Design 3（Material You）
- **狀態管理**：ScreenModel（MVVM 模式）
- **平板適配**：自動偵測，手機用 NavigationBar、平板用 NavigationRail + 雙面板

### 模組架構
| 模組 | 職責 |
|------|------|
| `app` | 主應用（UI + 業務邏輯）|
| `domain` | 領域層（用例與業務規則）|
| `data` | 資料層（資料庫 + API）|
| `core` | 核心工具與常數 |
| `presentation-core` | 共用 UI 元件和主題 |
| `presentation-widget` | Android Widget |
| `source-api` | 漫畫源 API 介面 |
| `source-local` | 本地源實作 |
| `i18n` | 國際化 |

---

## 2. 圖書館（Library）

### 2.1 顯示模式
- **緊湊網格**（Compact Grid）：小型封面卡片
- **舒適網格**（Comfortable Grid）：大型封面卡片，附帶標題
- **列表模式**（List）：水平列表顯示
- **欄位數自訂**：豎屏/橫屏分別設定（1-10 欄）

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
- **追蹤篩選**：依各追蹤服務篩選（已追蹤 / 未追蹤）

### 2.4 排序方式
- 按名稱（字母順序）
- 按最後更新時間
- 按未讀章節數
- 按總章節數
- 按最後閱讀時間
- 按最新上傳章節
- 按加入日期
- **隨機排序**（含隨機種子控制）
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
- 更新計數顯示

### 3.2 篩選選項
- 已下載 / 未下載
- 已讀 / 未讀
- 已開始 / 未開始
- 已加書籤 / 未加書籤

### 3.3 操作
- 點擊章節直接開始閱讀
- 長按進入選擇模式
- 批量標記為已讀 / 未讀
- 批量下載 / 刪除章節
- 批量加入 / 移除書籤
- 刪除確認對話框

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
- 隱藏已在圖書館中的項目

### 5.2 擴展系統（Extensions）子分頁

#### 5.2.1 擴展列表與分組
- **更新待機組**：有新版本可更新的擴展
- **已安裝組**：目前已安裝的擴展
- **可用組**：按語言分組顯示可安裝的擴展
- **未信任組**：簽名未驗證、需要用戶手動信任的擴展
- 擴展更新計數徽章顯示

#### 5.2.2 擴展搜尋與篩選
- 搜尋擴展名稱、來源名稱、URL、來源 ID
- 支援多個查詢（逗號分隔同時搜尋多個關鍵字）
- 按語言篩選（語言篩選螢幕）
- NSFW 擴展顯示 / 隱藏

#### 5.2.3 擴展安裝
- **安裝來源**：從擴展倉庫下載 APK 並安裝
- **安裝狀態流程**：Idle → Pending → Downloading → Installing → Installed / Error
- **4 種安裝器實作**：
  | 安裝器 | 說明 |
  |--------|------|
  | **Legacy** | 啟動系統包安裝器 Intent（傳統方式）|
  | **PackageInstaller** | 使用系統 PackageInstaller API（建立 session、串流寫入、提交）|
  | **Shizuku** | 透過 Shizuku 權限執行安裝命令（需 Shizuku 服務）|
  | **Private** | 安裝到應用私有目錄（無需系統權限）|
- MIUI 包安裝器特殊處理（Bug 迴避）
- 前景服務管理安裝進程（`ExtensionInstallService`）
- 安裝完成廣播接收器（`ExtensionInstallReceiver`）

#### 5.2.4 擴展更新
- 自動檢查擴展更新（從倉庫 `index.min.json` 比對版本）
- 更新通知推送（顯示可更新擴展列表）
- 單獨更新 / 全部更新
- 更新後自動重新載入擴展

#### 5.2.5 擴展解除安裝
- 共享擴展：透過系統包管理器解除安裝
- 私有擴展：直接從應用私有目錄刪除
- 解除安裝確認對話框

#### 5.2.6 擴展信任與簽名驗證
- **簽名驗證機制**：
  - 載入時使用 SHA256 雜湊驗證 APK 簽名
  - 與倉庫的 `signingKeyFingerprint` 比對
  - 支援多簽名者
- **信任來源**：
  - 倉庫簽名指紋自動信任
  - 用戶手動信任（存儲格式：`{pkgName}:{versionCode}:{signatureHash}`）
- **未信任擴展處理**：
  - 顯示為「未信任」分組
  - 用戶確認信任後重新載入
- **版本驗證**：lib version 1.4 - 1.5

#### 5.2.7 擴展詳情頁面
- 擴展名稱、版本、語言
- NSFW 標記
- 包含的來源列表
- 每個來源可個別啟用 / 停用
- 每個來源的隱身模式開關
- 清除來源 Cookie
- 解除安裝按鈕
- 開啟來源偏好設定（`SourcePreferencesScreen`）

#### 5.2.8 來源偏好設定
- 每個 `ConfigurableSource` 可提供自訂設定畫面
- 使用 `PreferenceFragment` 動態渲染設定項目
- 設定隔離至每個來源 ID（獨立 SharedPreferences）
- 隱身模式下文字輸入加密顯示

#### 5.2.9 擴展載入機制
- **共享擴展**：從系統已安裝的 APK 載入（可被其他應用共享）
- **私有擴展**：從應用私有目錄載入
- **ClassLoader 動態載入**：使用 `PathClassLoader` 載入擴展中的 Source 類別
- **SourceFactory 模式**：單一擴展可建立多個來源實例
- **並行載入**：使用協程並行載入所有擴展

### 5.3 擴展倉庫管理（Extension Repos）

#### 5.3.1 倉庫資料模型
```
ExtensionRepo:
  - baseUrl: String（主鍵，倉庫 URL）
  - name: String（倉庫名稱）
  - shortName: String?（縮寫）
  - website: String（倉庫網站）
  - signingKeyFingerprint: String（簽名金鑰指紋，用於擴展驗證）
```

#### 5.3.2 倉庫管理功能
- **新增倉庫**：
  - 輸入倉庫 URL
  - 自動從 `{baseUrl}/repo.json` 獲取倉庫元資料
  - 驗證 URL 格式
  - 檢查 URL 重複
  - 檢查簽名指紋重複（防止同一簽名的多個倉庫）
- **更新倉庫**：重新獲取倉庫元資料
- **刪除倉庫**
- **替換倉庫**

#### 5.3.3 倉庫元資料格式
```json
{
  "meta": {
    "name": "Repository Name",
    "shortName": "Repo",
    "website": "https://example.com",
    "signingKeyFingerprint": "ABCDEF1234567890..."
  }
}
```

#### 5.3.4 擴展列表格式（index.min.json）
```json
[{
  "name": "Tachiyomi: ExtensionName",
  "pkg": "com.example.extension",
  "apk": "extension-v1.4.1.apk",
  "lang": "en",
  "code": 1,
  "version": "1.4.1",
  "nsfw": 0,
  "sources": [{ "name": "Source Name", "lang": "en", "id": 123456, "baseUrl": "..." }]
}]
```

#### 5.3.5 倉庫異常處理
| 異常 | 說明 |
|------|------|
| `InvalidUrl` | URL 格式不正確 |
| `RepoAlreadyExists` | 相同 URL 已存在 |
| `DuplicateFingerprint` | 相同簽名指紋已被其他倉庫使用 |

#### 5.3.6 Deep Link 新增倉庫
- 支援 `tachiyomi://` URI 協議自動新增擴展倉庫
- 備份還原時自動恢復倉庫列表

### 5.4 Source API（擴展開發介面）

#### 5.4.1 Source 介面（基礎）
```kotlin
interface Source {
    val id: Long              // 唯一識別碼
    val name: String          // 來源名稱
    val lang: String          // 語言代碼
    suspend fun getMangaDetails(manga: SManga): SManga
    suspend fun getChapterList(manga: SManga): List<SChapter>
    suspend fun getPageList(chapter: SChapter): List<Page>
}
```

#### 5.4.2 CatalogueSource 介面（可瀏覽的來源）
```kotlin
interface CatalogueSource : Source {
    val supportsLatest: Boolean
    suspend fun getPopularManga(page: Int): MangasPage
    suspend fun getSearchManga(page: Int, query: String, filters: FilterList): MangasPage
    suspend fun getLatestUpdates(page: Int): MangasPage
    fun getFilterList(): FilterList
}
```

#### 5.4.3 ConfigurableSource 介面（可設定的來源）
- 提供隔離的 SharedPreferences
- `setupPreferenceScreen()` 方法定義設定畫面

#### 5.4.4 SourceFactory 介面
- `createSources(): List<Source>` — 單一擴展建立多個來源

#### 5.4.5 本地來源（LocalSource）
- 來源 ID 固定為 `0L`
- 從檔案系統讀取本地漫畫
- **支援格式**：資料夾、ZIP、CBZ、RAR、CBR、7Z、CB7、EPUB
- 支援 `ComicInfo.xml` 元資料解析
- 標記為 `UnmeteredSource`（不消耗流量）

### 5.5 遷移（Migration）子分頁
- 按來源顯示可遷移的漫畫
- 遷移來源選擇

### 5.4 遷移（Migration）子分頁
- 按來源顯示可遷移的漫畫
- 遷移來源選擇

### 5.5 瀏覽來源（Browse Source）
- 搜尋特定來源的漫畫
- 高級篩選選項（依來源提供）
- 最新更新 / 人氣排行

### 5.6 全域搜尋（Global Search）
- 跨所有已啟用來源搜尋
- 即時搜尋結果
- 來源篩選

---

## 6. 更多（More）

### 6.1 頁面項目
- **下載隊列**：管理當前下載任務
- **統計**：閱讀統計數據
- **數據和儲存**：備份還原
- **設定**：完整設定選單
- **關於**：版本和授權

### 6.2 快速切換
- **下載專用模式**（Download Only）：僅閱讀已下載章節
- **隱身模式**（Incognito Mode）：不記錄閱讀歷史

---

## 7. 漫畫詳情（Manga Details）

### 7.1 資訊顯示
- 封面圖片（可點擊放大 / 儲存 / 分享 / 設為封面）
- 標題
- 作者 / 繪者
- 狀態（連載中 / 已完結 / 暫停 / 授權 / 未知）
- 來源名稱
- 描述 / 簡介
- 標籤 / 流派（可點擊搜尋）

### 7.2 操作按鈕
- 加入收藏 / 移除收藏
- 追蹤管理
- WebView 開啟原始網頁
- 分享連結

### 7.3 筆記功能（Notes）
- 為每部漫畫撰寫個人筆記
- 獨立筆記編輯螢幕
- 筆記預覽區段

### 7.4 章節列表
- 章節名稱 / 編號顯示
- 掃描組資訊
- 上傳日期
- 閱讀進度指示
- 書籤標記
- 下載狀態指示

### 7.5 章節篩選
- **依閱讀狀態**：已讀 / 未讀
- **依下載狀態**：已下載 / 未下載
- **依書籤狀態**：已書籤 / 未書籤

### 7.6 章節排序
- 按來源排序
- 按章節編號排序
- 按上傳日期排序
- 按字母排序
- 升序 / 降序

### 7.7 章節顯示
- 依名稱顯示
- 依編號顯示

### 7.8 掃描組過濾（Scanlator Filter）
- 排除特定掃描組
- 多掃描組選擇對話框

### 7.9 缺失章節
- 缺失章節指示器（如章節間有缺口）
- 可選擇隱藏缺失章節

### 7.10 批量操作
- 多選章節
- 批量標記已讀 / 未讀
- 批量下載
- 批量刪除
- 批量加入書籤 / 移除書籤
- 標記前面所有為已讀

### 7.11 重複章節
- 重複章節自動偵測
- 自動標記重複章節為已讀
- 重複漫畫對話框提示

### 7.12 章節跳過設定
- 跳過已讀章節
- 跳過已篩選的章節
- 跳過重複章節
- 閱讀隱藏章節閾值（低 / 中 / 高）

---

## 8. 閱讀器（Reader）

### 8.1 閱讀模式

| 模式 | 說明 |
|------|------|
| **左到右翻頁**（L2R Pager）| 像西方漫畫一樣從左到右翻頁 |
| **右到左翻頁**（R2L Pager）| 像日本漫畫一樣從右到左翻頁 |
| **垂直翻頁**（Vertical Pager）| 上下翻頁 |
| **Webtoon 模式** | 連續垂直捲動（適合條漫）|
| **連續垂直**（Continuous Vertical）| 垂直捲動但非連續（Vertical Plus）|

### 8.2 螢幕方向

| 方向 | 說明 |
|------|------|
| 系統預設 | 跟隨系統設定 |
| 自由旋轉 | 依感應器旋轉 |
| 肖像模式 | 強制直屏 |
| 橫屏模式 | 強制橫屏 |
| 鎖定肖像 | 鎖定直屏（忽略感應器）|
| 鎖定橫屏 | 鎖定橫屏（忽略感應器）|
| 反向肖像 | 上下顛倒直屏 |

### 8.3 導航模式（觸控區域）

**Pager 模式和 Webtoon 模式各有獨立導航設定**

| 導航模式 | 說明 |
|----------|------|
| **右左導航** | 左區=上一頁、中央=選單、右區=下一頁 |
| **L 型導航** | 上方=上一頁、下方=下一頁、中央=選單 |
| **Kindlish 導航** | 類似 Kindle 的操作方式 |
| **邊界導航** | 邊緣區域=下一頁、底部中央=上一頁 |
| **停用導航** | 點擊僅開啟選單 |

- **導航反轉**：無 / 水平反轉 / 垂直反轉 / 全部反轉

### 8.4 縮放與裁切

- **圖像縮放類型**：適應螢幕 / 拉伸 / 適應寬度 / 適應高度 / 原始大小 / 智慧適應
- **縮放起始位置**：自動 / 左 / 右 / 中央
- **裁切邊框**：Pager 和 Webtoon 各自獨立設定
- **橫向自動縮放**
- **雙擊縮放速度**設定
- **導航至平移**：頁面未完全顯示時，點擊導航改為平移

### 8.5 雙頁面模式
- **Pager 雙頁分割**：將跨頁圖片分成兩頁
- **Webtoon 雙頁分割**
- **雙頁反轉**：交換左右頁
- **旋轉以適應**：雙頁時旋轉螢幕

### 8.6 顯示設定
- **頁碼指示器**（當前頁/總頁數）
- **全螢幕模式**
- **保持螢幕常亮**
- **閱讀器主題**：黑色 / 灰色 / 白色 / 自動
- **頁面轉換動畫**
- **翻頁閃爍效果**（電子墨水螢幕適用，可選黑/白閃爍）
- **閃爍持續時間**設定
- **章節轉換頁面**：顯示上一章/下一章資訊

### 8.7 色彩濾鏡

- **自訂亮度**（-75 至 100）
- **色彩濾鏡**（RGBA 可調）
- **混合模式**：
  - SrcOver（預設覆蓋）
  - Modulate（乘法）
  - Screen（螢幕）
  - Overlay（疊加）- Android P+
  - Lighten（變亮）- Android P+
  - Darken（變暗）- Android P+
- **灰階模式**
- **反色模式**

### 8.8 控制方式
- **觸控區域導航**（依導航模式）
- **長按操作**（頁面操作選單）
- **音量鍵翻頁**（可開啟/關閉）
- **音量鍵反轉**
- **手勢操作**：
  - 單擊：翻頁 / 開啟選單
  - 雙擊：縮放
  - 捲動：Webtoon 模式捲動
  - 平移：放大後移動

### 8.9 頁面載入

| 載入器 | 適用場景 |
|--------|----------|
| HttpPageLoader | 線上來源（預載 4 頁）|
| DownloadPageLoader | 已下載章節 |
| ArchivePageLoader | CBZ/ZIP 壓縮檔 |
| EpubPageLoader | EPUB 格式 |
| DirectoryPageLoader | 本地資料夾 |

- **頁面狀態**：等待 → 載入中 → 已載入 / 錯誤
- **預載機制**：接近章節末尾（< 5 頁）時預載下一章
- **高圖像分割**：將過長的圖片分割為多頁

### 8.10 閱讀器工具列

**頂部工具列：**
- 漫畫標題
- 章節名稱
- 書籤按鈕
- 分享按鈕

**底部工具列：**
- 頁碼滑桿
- 閱讀模式切換
- 螢幕方向切換
- 裁切邊框切換
- 設定按鈕（開啟詳細設定面板）

### 8.11 Webtoon 專用設定
- 雙擊縮放（可開啟/關閉）
- 側邊間距（0-25%）
- 禁止縮小
- 邊界填充

### 8.12 圖像渲染
- **SubsamplingScaleImageView**：大型靜態圖（支援區域解碼，低記憶體）
- **PhotoView**：動畫圖像（GIF 等）
- **硬體點陣圖閾值**設定

---

## 9. 下載管理（Download Manager）

### 9.1 下載隊列
- 查看當前下載進度
- 暫停 / 恢復下載
- 取消下載
- 重新排序下載順序
- 清空下載隊列

### 9.2 下載設定
- **僅在 WiFi 下載**
- **儲存格式**：CBZ 壓縮 / 資料夾
- **高圖像分割為多頁**

### 9.3 並行限制
- **並行來源數**：1-10（預設 5）
- **每來源並行頁面數**：1-15（預設 5）

### 9.4 自動下載
- **閱讀時自動下載**：0-5 章
- **新章節自動下載**
- **按分類限制新章節下載**（包含 / 排除特定分類）
- **僅下載未讀章節**

### 9.5 自動刪除章節
- **標記為已讀後刪除**
- **刪除已加書籤前 N 章**（數量可設定）
- **排除已加書籤的章節**
- **排除特定分類**

### 9.6 下載指示
- 下載進度百分比
- 下載狀態圖示
- 下載錯誤提示

---

## 10. 追蹤系統（Tracking）

### 10.1 支援的追蹤服務

| 服務 | 認證方式 | 特殊功能 |
|------|----------|----------|
| **MyAnimeList** | OAuth2 | 標準追蹤 |
| **AniList** | OAuth2 | 多種評分類型（10分/百分比/5星/3分笑臉）|
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
- 設定評分
- 設定開始日期 / 完成日期
- 私密追蹤選項

### 10.3 自動追蹤更新
- 標記為已讀時自動更新追蹤（Always / Never）
- 延遲追蹤更新機制（批量處理）
- 多服務同時同步

---

## 11. 備份與還原（Backup & Restore）

### 11.1 備份內容選項
| 項目 | 說明 |
|------|------|
| 漫畫資訊 | 收藏的漫畫及章節 |
| 分類 | 自訂分類 |
| 章節詳情 | 章節閱讀狀態、書籤等 |
| 追蹤資料 | 各追蹤服務同步狀態 |
| 歷史記錄 | 閱讀歷史 |
| 應用設定 | 所有偏好設定 |
| 來源設定 | 各來源的自訂設定 |
| 擴展倉庫 | 自訂倉庫列表 |
| 未收藏的已讀漫畫 | 不在圖書館但有閱讀記錄的漫畫 |

### 11.2 備份格式
- **序列化格式**：Protocol Buffers + gzip 壓縮
- **檔案副檔名**：`.tachibk`

### 11.3 自動備份
- **備份間隔**：關閉 / 6 小時 / 12 小時 / 24 小時 / 48 小時 / 每週
- **保留份數**：最近 3 份自動備份
- **時間戳追蹤**

### 11.4 還原功能
- 選擇性還原（可選擇還原哪些資料類別）
- 來源映射（舊來源 ID → 新來源的映射）
- 衝突處理邏輯

---

## 12. 設定（Settings）

### 12.1 外觀設定（Appearance）
- **主題模式**：系統 / 淺色 / 深色
- **應用主題**：Default / Monet（Material You）/ 多種色彩方案
- **AMOLED 深色模式**（純黑背景）
- **相對時間顯示**（如「3 分鐘前」）
- **日期格式自訂**
- **平板 UI 模式**：自動偵測 / 強制手機 / 強制平板
- **描述中圖像渲染**

### 12.2 圖書館設定（Library）
- 顯示模式與排序（見第 2 節）
- 列數設定（豎屏/橫屏獨立）
- 分類標籤顯示
- 項目計數顯示
- 徽章設定
- 繼續閱讀按鈕
- 章節預設設定
- 縮放行為
- 檔名限制設定

### 12.3 閱讀器設定（Reader）
- 所有閱讀器相關設定（見第 8 節）

### 12.4 下載設定（Downloads）
- 所有下載相關設定（見第 9 節）

### 12.5 瀏覽設定（Browse）
- 來源顯示模式
- 啟用的來源語言
- 停用來源管理
- NSFW 來源顯示
- 隱藏已在圖書館中的項目
- 擴展倉庫管理
- 信任擴展管理

### 12.6 追蹤設定（Tracking）
- 各追蹤服務認證管理
- AniList 評分類型選擇
- 自動更新選項

### 12.7 安全設定（Security）
- 見第 13 節

### 12.8 數據設定（Data & Storage）
- 備份與還原（見第 11 節）

### 12.9 進階設定（Advanced）
- 見第 19 節

### 12.10 關於
- 版本資訊
- 檢查更新
- 開源授權清單
- 變更日誌

---

## 13. 安全與隱私（Security & Privacy）

### 13.1 應用鎖定
- **生物辨識鎖定**（指紋 / Face ID）
- **鎖定超時**：始終 / 1分鐘 / 2分鐘 / 5分鐘 / 10分鐘 / 從不
- **解鎖螢幕**：專門的解鎖 Activity

### 13.2 安全螢幕
- **安全螢幕模式**：始終 / 僅隱身模式 / 從不
- 防止在最近使用清單中預覽螢幕內容

### 13.3 隱私設定
- **隱藏通知內容**
- **Crashlytics 回報**（可選）
- **分析追蹤**（可選）

### 13.4 隱身模式（Incognito）
- 啟用時不記錄閱讀歷史
- 不更新閱讀進度
- 橫幅提示目前處於隱身模式

---

## 14. 通知系統（Notifications）

### 14.1 通知類型
- **圖書館更新通知**：新章節提醒
- **下載通知**：下載進度與完成
- **應用更新通知**：有新版本可用
- **擴展安裝通知**
- **備份通知**

### 14.2 通知功能
- 通知頻道分類管理
- 自訂通知接收器
- 通知內容隱藏選項

---

## 15. Widget 小工具

### 15.1 更新網格小工具（Updates Grid Widget）
- **顯示最近更新的漫畫封面網格**
- 點擊封面直接開啟漫畫
- 使用 Glance 框架（Jetpack Compose for Widgets）

### 15.2 全螢幕覆蓋小工具
- 漫畫封面全螢幕顯示
- 鎖定狀態指示（當應用鎖定時顯示鎖定圖示）

---

## 16. 遷移系統（Migration）

### 16.1 核心功能
- 將漫畫從一個來源遷移到另一個來源
- 保留章節閱讀狀態
- 保留分類分配
- 保留追蹤資料

### 16.2 遷移設定
- **來源選擇**：選擇目標來源
- **遷移旗標**：選擇要遷移的資料（章節、分類、追蹤等）
- **排序模式**：字母順序 / 按章節數
- **深度搜尋模式**：更精確但更慢的搜尋
- **按章節優先選擇**：優先選擇章節更多的來源
- **隱藏未匹配的漫畫**
- **隱藏沒有更新的漫畫**

### 16.3 智慧搜尋引擎
- `SmartSourceSearchEngine`：智慧匹配漫畫名稱
- 支援模糊搜尋
- 自動移除特殊字元
- 多語言名稱匹配

### 16.4 遷移流程 UI
- 遷移列表螢幕
- 遷移進度對話框
- 遷移退出確認對話框
- 單部漫畫遷移對話框

---

## 17. 即將推出（Upcoming）

### 17.1 核心功能
- 日曆視圖顯示即將發布的漫畫更新
- 按日期排列的漫畫列表
- 預計更新時間計算

### 17.2 UI 元件
- 日曆元件（月視圖）
- 即將更新的漫畫項目卡片

---

## 18. 統計（Statistics）

### 18.1 顯示資料
- 圖書館統計（收藏數量、分類分佈等）
- 閱讀統計（已讀章節、閱讀時間等）
- 時間序列數據

---

## 19. 網路與進階設定

### 19.1 網路設定
- **DNS over HTTPS（DoH）**：多個提供者可選
- **自訂 User-Agent**
- **詳細日誌記錄**

### 19.2 進階設定
- 自動清除章節快取
- 資料庫清理功能
- 重設閱讀器設定
- 清除下載快取

### 19.3 Debug 功能（僅限 Debug 版本）
- 備份架構檢視
- 調試資訊
- Worker 狀態資訊

---

## 20. 入門引導（Onboarding）

### 20.1 首次啟動流程
- 歡迎螢幕
- 權限請求（儲存、通知等）
- 基本設定引導
- 擴展倉庫設定提示

---

## 21. Deep Linking

### 21.1 支援的連結類型
- **Intent 搜尋**：從外部應用搜尋漫畫
- **備份檔案還原**：點擊 `.tachibk` 檔案直接還原
- **Tachiyomi URI**：`tachiyomi://` 協議（新增擴展倉庫）

### 21.2 應用捷徑（Shortcuts）
| 捷徑 | 目標 |
|------|------|
| Library | 圖書館 |
| Manga | 特定漫畫 |
| Updates | 更新頁面 |
| History | 歷史頁面 |
| Sources | 來源頁面 |
| Extensions | 擴展頁面 |
| Downloads | 下載頁面 |

---

## 22. 資料模型與資料庫

### 22.1 資料庫引擎
- **SQLDelight**（SQL + Kotlin 類型安全）

### 22.2 核心資料表

| 資料表 | 用途 | 主要欄位 |
|--------|------|----------|
| `mangas` | 漫畫資訊 | id, source, url, title, author, artist, description, genre, status, thumbnail_url, favorite, viewer, chapter_flags, notes |
| `chapters` | 章節資訊 | id, manga_id, url, name, scanlator, chapter_number, read, bookmark, last_page_read, date_fetch, date_upload |
| `categories` | 分類 | id, name, sort, flags |
| `mangas_categories` | 漫畫-分類關聯 | manga_id, category_id |
| `manga_sync` | 追蹤同步 | manga_id, sync_id, remote_id, title, last_chapter_read, total_chapters, status, score, start_date, finish_date |
| `history` | 閱讀歷史 | chapter_id, last_read, time_read |
| `sources` | 來源資訊 | source_id, name, lang |
| `extension_repos` | 擴展倉庫 | base_url, name, short_name, website, signing_key_fingerprint |
| `excluded_scanlators` | 排除掃描組 | manga_id, scanlator |

### 22.3 資料庫視圖

| 視圖 | 用途 |
|------|------|
| `libraryView` | 聚合漫畫+章節+歷史+分類，用於圖書館顯示 |
| `updatesView` | 最近更新的章節（含掃描組過濾）|

### 22.4 Manga 章節標記位元欄位
```
排序方向：CHAPTER_SORT_DESC / CHAPTER_SORT_ASC
顯示篩選：CHAPTER_SHOW_UNREAD / READ / DOWNLOADED / NOT_DOWNLOADED / BOOKMARKED / NOT_BOOKMARKED
排序方式：CHAPTER_SORTING_SOURCE / NUMBER / UPLOAD_DATE / ALPHABET
顯示方式：CHAPTER_DISPLAY_NAME / NUMBER
```

---

## 附錄：iOS 移植重點

### 需要替代方案的 Android 特有功能
| Android 功能 | iOS 替代方案建議 |
|-------------|-----------------|
| Jetpack Compose | SwiftUI |
| Voyager 導航 | SwiftUI NavigationStack / NavigationSplitView |
| Material Design 3 | 自訂設計系統 / 貼近 Material 風格 |
| SQLDelight | GRDB / Core Data / SQLite.swift |
| WorkManager（背景任務） | BGTaskScheduler |
| Glance Widgets | WidgetKit |
| Protocol Buffers 備份 | 可沿用或改用 Codable + JSON |
| 擴展系統（APK 安裝）| 需重新設計（無法動態安裝擴展）|
| Shizuku | 不適用 |
| Notification Channels | UNNotificationCategory |
| BiometricPrompt | LocalAuthentication（Face ID / Touch ID）|
| WebView | WKWebView |
| SubsamplingScaleImageView | 需尋找 iOS 替代或自行實作 |
| RecyclerView | UICollectionView / LazyVStack |

### iOS 無法實現的 Android 功能

以下功能因 iOS 平台限制而**完全無法實現**，不存在任何替代方案：

| 功能 | 原因 |
|------|------|
| **APK 動態擴展安裝**（5.2.3 四種安裝器：Legacy / PackageInstaller / Shizuku / Private） | iOS 禁止第三方 App 動態安裝或載入可執行程式碼（App Store Review Guidelines 2.5.2）。已採用 JavaScriptCore 插件系統替代 |
| **Shizuku 權限委派** | Android 專屬的 root/ADB 權限框架，iOS 無對應概念 |
| **ClassLoader 動態載入**（5.2.9 PathClassLoader 載入 .dex） | iOS code signing 機制禁止動態載入未簽名的可執行二進位 |
| **MIUI 包安裝器特殊處理**（5.2.3） | Android 廠商特定的 Bug workaround，iOS 不適用 |
| **共享擴展安裝**（5.2.9 多個 App 共用同一 APK） | iOS sandbox 模型禁止 App 之間共享可執行程式碼 |
| **Material You / Monet 動態取色**（12.1 從桌布自動提取主題色） | iOS 不開放桌布圖片存取 API，無法動態提取主題色。僅能提供預設色盤讓用戶手動選擇 |
| **通知頻道分類管理**（14.2 用戶在系統設定中逐類開關通知） | iOS 的 `UNNotificationCategory` 僅定義互動按鈕，無法讓用戶在系統層級單獨關閉特定類別的通知 |
| **電子墨水閃爍效果**（8.6 翻頁時黑/白閃爍） | 針對 Android E-Ink 裝置（如 Boox）的功能，iOS 無電子墨水裝置 |
| **Debug 版本 Worker 狀態資訊**（19.3） | iOS 的 `BGTaskScheduler` 執行狀態對開發者不透明，無法像 Android WorkManager 一樣查看排程詳情 |

### iOS 受限但有替代方案的功能

以下功能在 iOS 上受到限制，但有可行的替代或曲線方案：

| 功能 | 限制說明 | 替代方案 |
|------|----------|----------|
| **音量鍵翻頁**（8.8） | iOS 不開放音量鍵事件給第三方 App | ✅ 已實現：透過 KVO 監聽 `AVAudioSession.outputVolume` 變化，偵測後用隱藏的 `MPVolumeView` 內部 `UISlider` 重設音量，播放靜音音效壓住系統 HUD |
| **AMOLED 純黑主題**（12.1） | — | ✅ 可實現：iPhone X 以後全面使用 OLED 面板，背景色設為 `#000000` 即可關閉子像素省電，效果與 Android 一致 |
| **背景圖書館自動更新** | iOS `BGAppRefreshTask` 由系統智慧排程，無法保證精確間隔（Android 可設 6/12/24/48 小時） | 使用 `BGAppRefreshTask`，但無法承諾更新頻率 |
| **擴展自動更新推送**（5.2.4） | 無法在背景主動拉取 `index.min.json` 並推送更新 | 僅能在 App 前景時檢查更新 |
| **自訂 User-Agent**（19.1） | `URLSession` 可設定，但 `WKWebView` 的 UA 修改受限 | `URLSession` 層面可完整支援，`WKWebView` 部分受限 |

### iOS 優勢可利用的功能
- **CloudKit**：跨裝置同步
- **Core Spotlight**：系統搜尋整合
- **ShareExtension**：從 Safari 等分享漫畫連結
- **Shortcuts**：Siri 捷徑整合
- **Live Activities**：閱讀進度即時活動
