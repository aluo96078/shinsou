import Foundation

public extension Date {
    var epochMillis: Int64 {
        Int64(timeIntervalSince1970 * 1000)
    }

    init(epochMillis: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
    }

    func relativeString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
