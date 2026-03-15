# Shinsou

Shinsou 是一款 iOS 原生漫畫閱讀器，靈感來自 [Mihon](https://github.com/mihonapp/mihon)（原 Tachiyomi）Android 漫畫閱讀器，使用 Swift 與 SwiftUI 從零打造，提供完整的漫畫瀏覽、閱讀與管理體驗。

## 功能特色

- **漫畫庫管理** — 收藏、分類、篩選、排序，支援多種顯示模式（網格/列表/舒適網格）
- **多模式閱讀器** — Webtoon 長條式、翻頁式、雙頁模式，支援色彩濾鏡、大圖分割、音量鍵翻頁
- **JavaScript 插件系統** — 透過 JavaScriptCore 執行 JS 插件，動態擴充漫畫來源
- **來源系統** — 本地來源、HTTP 來源、社群 JS 插件來源
- **追蹤整合** — AniList、MyAnimeList、Kitsu、Bangumi、MangaUpdates、Shikimori、Komga、Kavita、Suwayomi
- **iCloud 同步** — iCloud Drive 備份同步 + CloudKit 即時增量同步
- **下載管理** — 佇列管理、進度追蹤、並發控制
- **備份與還原** — 手動/自動備份（`.shinsoubackup`），向後相容 `.mihonbackup` 格式
- **安全與隱私** — 應用程式鎖（Face ID/Touch ID）、隱私模式、防截圖
- **Widget 支援** — iOS Widget 快捷存取
- **多語系** — 9 種語言（英文、繁體中文、簡體中文、日文、韓文、法文、德文、西班牙文、葡萄牙文）

## 系統需求

- iOS 16.0+
- Xcode 16.3+
- Swift 5.10
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## 技術架構

### 架構模式

採用 **Clean Architecture**，分為三層：

```
ShinsouApp (展示層 - UI + ViewModel)
    ↓
ShinsouDomain (領域層 - Model + Repository 介面)
    ↓
ShinsouData (資料層 - Repository 實作 + 資料庫)
```

### 模組化結構

```
shinsou/
├── ShinsouApp/                     # 主應用程式
│   ├── App/                        # 進入點、DI 容器、AppDelegate
│   ├── UI/                         # SwiftUI 畫面
│   │   ├── Library/                # 漫畫庫
│   │   ├── Browse/                 # 瀏覽來源
│   │   ├── Reader/                 # 閱讀器
│   │   ├── Settings/               # 設定
│   │   ├── MangaDetail/            # 漫畫詳情
│   │   ├── Updates/                # 更新
│   │   ├── History/                # 歷史
│   │   ├── More/                   # 更多（含 About）
│   │   ├── Backup/                 # 備份還原
│   │   ├── Track/                  # 追蹤
│   │   ├── Onboarding/             # 入門引導
│   │   └── WebView/                # 網頁檢視
│   ├── Source/                     # 來源管理
│   │   ├── JSPlugin/               # JS 插件引擎（JSBridge、PluginLoader 等）
│   │   ├── Interactor/             # 來源用例
│   │   └── Network/                # 來源網路層
│   ├── Sync/                       # iCloud 同步
│   │   ├── CloudKit/               # CloudKit 增量同步引擎
│   │   └── UI/                     # 同步設定畫面
│   ├── Track/                      # 追蹤服務整合
│   ├── Download/                   # 下載管理
│   ├── Backup/                     # 備份系統
│   ├── Security/                   # 安全功能
│   ├── Navigation/                 # 深度連結
│   ├── Network/                    # 網路中介層
│   └── Notification/               # 通知系統
├── Packages/
│   ├── ShinsouDomain/              # 領域模型與 Repository 介面
│   ├── ShinsouData/                # GRDB 資料庫與 Repository 實作
│   ├── ShinsouSourceAPI/           # 來源 API 協定（Source、HttpSource、CatalogueSource）
│   ├── ShinsouSourceLocal/         # 本地檔案來源
│   ├── ShinsouCore/                # 核心工具與常數
│   ├── ShinsouUI/                  # 共用 UI 元件
│   └── ShinsouI18n/                # 國際化（9 種語言）
├── ShinsouWidgetExtension/         # iOS Widget
├── docs/                           # 技術文件
└── project.yml                     # XcodeGen 專案設定
```

### 主要依賴

| 套件 | 用途 |
|------|------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) (6.29+) | SQLite 資料庫 ORM |
| [Nuke](https://github.com/kean/Nuke) (12.8+) | 圖片載入與快取 |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) (2.7+) | HTML 解析（JS 插件 DOM API） |

## 建置與執行

1. 確保已安裝 Xcode 16.3+ 與 [XcodeGen](https://github.com/yonaskolb/XcodeGen)

2. 產生 Xcode 專案：
   ```bash
   cd shinsou
   xcodegen generate
   ```

3. 開啟 `ShinsouIOS.xcodeproj`，選擇目標裝置後按 `Cmd + R` 執行

4. 命令列建置（可選）：
   ```bash
   xcodebuild build \
     -project ShinsouIOS.xcodeproj \
     -scheme ShinsouApp \
     -destination 'generic/platform=iOS' \
     -allowProvisioningUpdates
   ```

> **注意**：新增或刪除檔案後需重新執行 `xcodegen generate` 以更新 Xcode 專案。

## 插件系統

Shinsou 使用 JavaScriptCore 引擎執行 JS 插件來擴充漫畫來源。插件透過 `JSBridge` 與原生層溝通，提供標準化的 DOM 解析、HTTP 請求與偏好設定 API。

詳細文件請參考 [docs/shinsou-extension-system.md](docs/shinsou-extension-system.md)。

社群插件倉庫：[shinsou_plugin](https://github.com/aluo96078/shinsou_plugin)

## iCloud 同步

Shinsou 支援兩種 iCloud 同步方案，共存互補：

- **iCloud Drive 備份同步** — 自動將 `.shinsoubackup` 備份檔上傳至 iCloud Drive，提供完整還原能力
- **CloudKit 即時同步** — 即時同步閱讀進度、書庫變更等小型資料

> CloudKit 同步需要 Apple Developer Portal 中啟用 iCloud（CloudKit）能力。應用程式會在執行時自動偵測 provisioning profile 中的 CloudKit 權限，未啟用時不會崩潰。

## 專案配置

| 項目 | 值 |
|------|---|
| Bundle ID | `dev.shinsou.ios` |
| 最低部署版本 | iOS 16.0 |
| Swift 版本 | 5.10 |
| 套件管理 | Swift Package Manager |
| 資料庫 | GRDB.swift（`shinsou.db`）|
| iCloud Container | `iCloud.dev.shinsou.ios` |
| URL Scheme | `shinsou://` |
| 備份格式 | `.shinsoubackup` |

## 授權條款

本專案採用 [MIT License](LICENSE) 授權。Copyright (c) 2026 Aluo.
