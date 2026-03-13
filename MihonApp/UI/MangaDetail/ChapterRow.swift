import SwiftUI
import MihonDomain
import MihonI18n

struct ChapterRow: View {
    let chapter: Chapter
    let isSelected: Bool
    let isSelectionMode: Bool
    /// Whether this chapter has duplicates in another scanlator group (7.11)
    var isDuplicate: Bool = false
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if chapter.bookmark {
                            Image(systemName: "bookmark.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(chapter.name)
                            .font(.body)
                            .foregroundStyle(chapter.read ? .secondary : .primary)
                            .lineLimit(1)

                        // Duplicate indicator (7.11)
                        if isDuplicate {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .help(MR.strings.mangaDuplicateHint)
                        }
                    }

                    HStack(spacing: 8) {
                        if chapter.dateUpload > 0 {
                            Text(formatDate(chapter.dateUpload))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if let scanlator = chapter.scanlator, !scanlator.isEmpty {
                            Text(scanlator)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        if chapter.read && chapter.lastPageRead > 0 {
                            Text("Page \(chapter.lastPageRead)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.1) : .clear)
        }
        .buttonStyle(.plain)
        .onLongPressGesture { onLongPress() }
    }

    private func formatDate(_ epochMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(epochMillis) / 1000.0)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Missing Chapters Divider (7.9)

struct MissingChaptersDivider: View {
    let from: Double
    let to: Double

    var body: some View {
        HStack(spacing: 8) {
            VStack { Divider() }
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(label)
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize()
            VStack { Divider() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var label: String {
        let start = formatChapterNum(from + 1)
        let end = formatChapterNum(to - 1)
        if start == end {
            return "Missing ch. \(start)"
        }
        return "Missing ch. \(start)–\(end)"
    }

    private func formatChapterNum(_ num: Double) -> String {
        if num == num.rounded() {
            return String(Int(num))
        }
        return String(format: "%.1f", num)
    }
}
