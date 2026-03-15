import SwiftUI
import ShinsouDomain
import ShinsouData
import ShinsouI18n
import Nuke
import NukeUI

// MARK: - UpcomingScreen

/// 顯示預測更新日曆。月視圖上的日期若有漫畫預計更新，會顯示圓點標記。
/// 選取特定日期後，列表會顯示該日預計更新的漫畫。
struct UpcomingScreen: View {
    @StateObject private var viewModel = UpcomingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                Spacer()
                ProgressView("Calculating update schedule...")
                    .padding()
                Spacer()
            } else {
                calendarSection
                Divider()
                mangaListSection
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 0) {
            // Month Navigation Header
            HStack {
                Button {
                    viewModel.shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .padding(8)
                        .contentShape(Rectangle())
                }

                Spacer()

                Text(viewModel.monthTitle)
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)

            // Weekday Labels
            HStack(spacing: 0) {
                ForEach(viewModel.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(viewModel.calendarDays) { day in
                    CalendarDayCell(
                        day: day,
                        isSelected: viewModel.calendar.isDate(day.date, inSameDayAs: viewModel.selectedDate),
                        hasUpdates: viewModel.hasUpdates(on: day.date)
                    )
                    .onTapGesture {
                        if day.isCurrentMonth {
                            viewModel.selectedDate = day.date
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Manga List Section

    @ViewBuilder
    private var mangaListSection: some View {
        let items = viewModel.mangaForSelectedDate

        if items.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text(MR.strings.upcomingNoUpdates)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            List(items) { item in
                UpcomingMangaRow(item: item)
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - CalendarDayCell

private struct CalendarDayCell: View {
    let day: CalendarDay
    let isSelected: Bool
    let hasUpdates: Bool

    private var isToday: Bool {
        Calendar.current.isDateInToday(day.date)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 34, height: 34)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                }

                Text("\(day.dayNumber)")
                    .font(.system(size: 15, weight: isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(
                        !day.isCurrentMonth ? Color.secondary.opacity(0.4) :
                        isSelected ? .white :
                        isToday ? Color.accentColor : Color.primary
                    )
            }
            .frame(width: 36, height: 36)

            // Update dot
            Circle()
                .fill(hasUpdates ? Color.accentColor : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .opacity(day.isCurrentMonth ? 1.0 : 0.4)
    }
}

// MARK: - UpcomingMangaRow

private struct UpcomingMangaRow: View {
    let item: UpcomingMangaItem

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = item.manga.thumbnailUrl, let imageUrl = URL(string: urlString) {
                LazyImage(request: .proxied(url: imageUrl)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 44, height: 60)
                .clipped()
                .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 44, height: 60)
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.manga.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let interval = item.averageIntervalDays {
                    Text(MR.strings.upcomingEveryDays(Int(interval)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(item.formattedExpectedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - CalendarDay Model

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
}

// MARK: - UpcomingMangaItem Model

struct UpcomingMangaItem: Identifiable {
    let id: Int64
    let manga: Manga
    let expectedDate: Date
    let averageIntervalDays: Double?

    var formattedExpectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: expectedDate)
    }
}

// MARK: - UpcomingViewModel

@MainActor
final class UpcomingViewModel: ObservableObject {

    @Published var isLoading = true
    @Published var selectedDate: Date = Date()
    @Published var displayMonth: Date = Date()

    /// 所有預測更新項目 (expectedDate -> items)
    private var upcomingByDate: [DateComponents: [UpcomingMangaItem]] = [:]

    let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 1 // Sunday first
        return cal
    }()

    // MARK: Computed

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth)
    }

    var weekdaySymbols: [String] {
        // Short weekday symbols starting from firstWeekday
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var calendarDays: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayMonth) else {
            return []
        }

        let monthStart = monthInterval.start
        let monthEnd = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end

        // Weekday offset for the first day of the month (0-based, relative to firstWeekday)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [CalendarDay] = []

        // Trailing days from previous month
        for i in (1...max(1, offset)).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: monthStart) {
                let num = calendar.component(.day, from: date)
                days.append(CalendarDay(date: date, dayNumber: num, isCurrentMonth: false))
            }
        }
        // Remove dummy entry if offset == 0
        if offset == 0 { days = [] }

        // Current month days
        var current = monthStart
        while current <= monthEnd {
            let num = calendar.component(.day, from: current)
            days.append(CalendarDay(date: current, dayNumber: num, isCurrentMonth: true))
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
        }

        // Trailing days to complete last week row (42 cells = 6 rows)
        let trailing = (42 - days.count) % 7
        for i in 1...max(1, trailing == 0 ? 7 : trailing) {
            if let date = calendar.date(byAdding: .day, value: i, to: monthEnd) {
                let num = calendar.component(.day, from: date)
                days.append(CalendarDay(date: date, dayNumber: num, isCurrentMonth: false))
            }
            if days.count >= 42 { break }
        }

        return days
    }

    var mangaForSelectedDate: [UpcomingMangaItem] {
        let components = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        return upcomingByDate[components] ?? []
    }

    // MARK: Helpers

    func hasUpdates(on date: Date) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return !(upcomingByDate[components]?.isEmpty ?? true)
    }

    func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayMonth) {
            displayMonth = newMonth
        }
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let mangaRepo = DIContainer.shared.mangaRepository
            let chapterRepo = DIContainer.shared.chapterRepository

            let favorites = try await mangaRepo.getFavorites()

            var result: [DateComponents: [UpcomingMangaItem]] = [:]

            for manga in favorites {
                guard let expectedDate = await predictNextUpdate(manga: manga, chapterRepo: chapterRepo) else {
                    continue
                }
                let intervalDays = await averageIntervalDays(manga: manga, chapterRepo: chapterRepo)
                let item = UpcomingMangaItem(
                    id: manga.id,
                    manga: manga,
                    expectedDate: expectedDate,
                    averageIntervalDays: intervalDays
                )
                let components = calendar.dateComponents([.year, .month, .day], from: expectedDate)
                result[components, default: []].append(item)
            }

            upcomingByDate = result
        } catch {
            print("UpcomingViewModel load error: \(error)")
        }
    }

    // MARK: - Prediction Logic

    /// 根據最近 N 章節的上傳日期，計算平均更新間隔，並以最後一章節日期加上間隔來預測下次更新日。
    private func predictNextUpdate(manga: Manga, chapterRepo: ChapterRepository) async -> Date? {
        guard let chapters = try? await chapterRepo.getChaptersByMangaId(mangaId: manga.id) else {
            return nil
        }

        // 使用 dateUpload（來源上傳日期）而非 dateFetch（抓取日期），以提高準確度
        let uploadDates = chapters
            .filter { $0.dateUpload > 0 }
            .map { Date(timeIntervalSince1970: Double($0.dateUpload) / 1000.0) }
            .sorted()

        guard uploadDates.count >= 2 else {
            // 資料不足，如果有 lastUpdate 就以 2 週後作為估計
            if manga.lastUpdate > 0 {
                let last = Date(timeIntervalSince1970: Double(manga.lastUpdate) / 1000.0)
                return last.addingTimeInterval(14 * 86400)
            }
            return nil
        }

        let recentDates = uploadDates.suffix(10) // 最近 10 章
        guard recentDates.count >= 2 else { return nil }

        let intervals = zip(recentDates, recentDates.dropFirst()).map { $1.timeIntervalSince($0) }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        // 平均間隔至少 1 天，最長 180 天
        let clampedInterval = max(86400, min(avgInterval, 180 * 86400))

        let lastDate = recentDates.last!
        let predicted = lastDate.addingTimeInterval(clampedInterval)

        // 只預測未來日期（過去的預測仍顯示以提示「更新中」）
        return predicted
    }

    private func averageIntervalDays(manga: Manga, chapterRepo: ChapterRepository) async -> Double? {
        guard let chapters = try? await chapterRepo.getChaptersByMangaId(mangaId: manga.id) else {
            return nil
        }
        let dates = chapters
            .filter { $0.dateUpload > 0 }
            .map { Date(timeIntervalSince1970: Double($0.dateUpload) / 1000.0) }
            .sorted()

        guard dates.count >= 2 else { return nil }
        let recent = dates.suffix(10)
        let intervals = zip(recent, recent.dropFirst()).map { $1.timeIntervalSince($0) / 86400.0 }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        return avg.rounded(toPlaces: 1)
    }
}

// MARK: - Double Extension

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
