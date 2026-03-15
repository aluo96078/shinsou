import WidgetKit
import SwiftUI

// MARK: - WidgetCoverImageView
/// 封面圖片元件：優先使用預先快取的 Data，其次嘗試從 URL 載入，最後顯示佔位符
struct WidgetCoverImageView: View {
    let coverData: Data?
    let coverUrl: String?

    var body: some View {
        if let data = coverData, let uiImage = UIImage(data: data) {
            // 使用主 App 預先取得的封面資料（最可靠的方式）
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let urlString = coverUrl, let url = URL(string: urlString) {
            // 嘗試從系統快取載入（僅限 URL Cache 中已存在的資料）
            // Widget 環境中無法主動發起新的 HTTP 請求
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    WidgetCoverPlaceholderContent()
                @unknown default:
                    WidgetCoverPlaceholderContent()
                }
            }
        } else {
            WidgetCoverPlaceholderContent()
        }
    }
}

// MARK: - WidgetCoverPlaceholder
/// 尚未有封面時的空白佔位框（帶有圖示）
struct WidgetCoverPlaceholder: View {
    var body: some View {
        WidgetCoverPlaceholderContent()
            .aspectRatio(2/3, contentMode: .fit)
            .cornerRadius(6)
    }
}

/// 佔位符的內容（避免重複定義）
struct WidgetCoverPlaceholderContent: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "book.closed")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color(.systemGray2))
        }
    }
}

// MARK: - WidgetEmptyView
/// Widget 沒有資料時顯示的空白提示
struct WidgetEmptyView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - WidgetBadgeView
/// 未讀章節數量徽章
struct WidgetBadgeView: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.accentColor, in: Capsule())
        }
    }
}

// MARK: - Previews

struct WidgetViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // 封面佔位符預覽
            HStack(spacing: 8) {
                WidgetCoverPlaceholder()
                    .frame(width: 60, height: 90)

                WidgetCoverImageView(coverData: nil, coverUrl: nil)
                    .frame(width: 60, height: 90)
                    .cornerRadius(6)
            }

            // 空白提示預覽
            WidgetEmptyView(message: "尚無資料")
                .frame(height: 80)
                .background(Color(.systemBackground))
                .cornerRadius(8)

            // 徽章預覽
            HStack(spacing: 8) {
                WidgetBadgeView(count: 5)
                WidgetBadgeView(count: 99)
                WidgetBadgeView(count: 100)
                WidgetBadgeView(count: 0)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Widget Views")
    }
}
