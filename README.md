# Shinsou

Shinsou 是基於知名的 [Mihon](https://github.com/mihonapp/mihon)（原 Tachiyomi）Android 漫畫閱讀器的 iOS 移植版本，提供完整的漫畫瀏覽、閱讀與管理體驗。

## 功能特色

- **漫畫庫管理** — 收藏、分類、篩選、排序，支援多種顯示模式（網格/列表/舒適網格）
- **多模式閱讀器** — Webtoon 長條式、翻頁式、雙頁模式，支援色彩濾鏡、大圖分割、音量鍵翻頁
- **來源系統** — 本地來源、HTTP 來源、JavaScript 插件擴充來源
- **追蹤整合** — AniList、MyAnimeList、Kitsu、Bangumi、MangaUpdates、Shikimori、Komga、Kavita、Suwayomi
- **下載管理** — 佇列管理、進度追蹤、並發控制
- **備份與還原** — 手動/自動備份、跨裝置還原
- **安全與隱私** — 應用程式鎖（Face ID/Touch ID）、隱私模式、防截圖
- **Widget 支援** — iOS Widget 快捷存取
- **多語系** — 國際化支援

## 系統需求

- iOS 16.0+ / macOS 13.0+
- Xcode 16.3+
- Swift 5.10

## 技術架構

### 架構模式

採用 **Clean Architecture**，分為三層：

```
MihonApp (展示層 - UI + ViewModel)
    ↓
MihonDomain (領域層 - Model + Repository 介面)
    ↓
MihonData (資料層 - Repository 實作 + 資料庫)
```

### 模組化結構

```
shinsou/
├── MihonApp/                  # 主應用程式
│   ├── App/                   # 應用程式入口與 DI 容器
│   ├── UI/                    # SwiftUI 畫面（Library、Browse、Reader、Settings 等）
│   ├── Source/                # 來源管理與 JS 插件載入
│   ├── Track/                 # 追蹤服務整合
│   ├── Download/              # 下載管理
│   ├── Backup/                # 備份系統
│   ├── Security/              # 安全功能
│   └── Network/               # 網路中介層
├── Packages/
│   ├── MihonDomain/           # 領域模型與 Repository 介面
│   ├── MihonData/             # GRDB 資料庫與 Repository 實作
│   ├── MihonSourceAPI/        # 來源 API 協定（Source、HttpSource、CatalogueSource）
│   ├── MihonSourceLocal/      # 本地檔案來源
│   ├── MihonCore/             # 核心工具與常數
│   └── MihonUI/               # 共用 UI 元件
├── MihonWidgetExtension/      # iOS Widget
├── MihonShareExtension/       # 分享擴充
└── project.yml                # XcodeGen 專案設定
```

### 主要依賴

| 套件 | 用途 |
|------|------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) (6.29+) | SQLite 資料庫 ORM |
| [Nuke](https://github.com/kean/Nuke) (12.8+) | 圖片載入與快取 |
| [SwiftSoup](https://github.com/scinfu/SwiftSoup) (2.7+) | HTML 解析 |

## 建置與執行

1. 確保已安裝 Xcode 16.3+ 與 [XcodeGen](https://github.com/yonaskolb/XcodeGen)

2. 產生 Xcode 專案：
   ```bash
   cd shinsou
   xcodegen generate
   ```

3. 開啟 `MihonIOS.xcodeproj`，選擇目標裝置後按 `Cmd + R` 執行

## 插件系統

Shinsou 支援透過 JavaScript 插件擴充漫畫來源。插件透過 `JSBridge` 與原生層溝通，提供標準化的 API 介面。

詳細文件請參考 [docs/mihon-extension-system.md](docs/mihon-extension-system.md)。

社群插件倉庫：[shinsou_plugin](https://github.com/aluo96078/shinsou_plugin)

## 專案配置

| 項目 | 值 |
|------|---|
| Bundle ID | `dev.mihon.ios` |
| 最低部署版本 | iOS 16.0 |
| Swift 版本 | 5.10 |
| 套件管理 | Swift Package Manager |

## 授權條款

本專案採用 [MIT License](LICENSE) 授權。Copyright (c) 2026 Aluo.
