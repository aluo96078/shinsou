import SwiftUI

public enum ShinsouColors {
    public static let primary = Color.accentColor
    public static let onPrimary = Color.white
    public static let error = Color.red
    public static let unread = Color.accentColor
    public static let downloaded = Color.green
    public static let bookmarked = Color.yellow

    #if canImport(UIKit)
    public static let background = Color(.systemBackground)
    public static let surface = Color(.secondarySystemBackground)
    public static let onSurface = Color(.label)
    public static let onSurfaceVariant = Color(.secondaryLabel)
    public static let outline = Color(.separator)
    #else
    public static let background = Color.white
    public static let surface = Color.gray.opacity(0.1)
    public static let onSurface = Color.primary
    public static let onSurfaceVariant = Color.secondary
    public static let outline = Color.gray.opacity(0.3)
    #endif
}
