import Foundation

// MARK: - Category Flags Bit Constants
//
// Layout of the 64-bit `flags` field on Category:
//
//  Bits  0-1  : Display mode  (0=compactGrid, 1=comfortableGrid, 2=list, 3=coverOnlyGrid)
//  Bits  2-5  : Sort type     (0-9, matches LibrarySort.SortType raw values)
//  Bit   6    : Sort direction (0=ascending, 1=descending)
//  Remaining  : reserved / future use

public enum CategoryFlagMask: Int64 {
    // Display mode occupies bits 0-1 (2 bits → values 0-3)
    case displayModeMask = 0b0000_0011          // 0x03

    // Sort type occupies bits 2-5 (4 bits → values 0-15)
    case sortTypeMask    = 0b0011_1100          // 0x3C

    // Sort direction occupies bit 6 (1 bit)
    case sortDirMask     = 0b0100_0000          // 0x40
}

private enum CategoryFlagShift {
    static let displayMode: Int64 = 0
    static let sortType:    Int64 = 2
    static let sortDir:     Int64 = 6
}

// MARK: - Category + Flag Helpers

public extension Category {

    // MARK: Display Mode

    /// The per-category display mode stored in `flags`, or `nil` if not overridden.
    /// When `nil`, the global library display mode applies.
    var displayModeOverride: LibraryDisplayMode? {
        // A value of 0xFF in the display-mode bits signals "use global setting".
        // We store a sentinel: all display-mode bits set to their maximum (3) AND
        // the "has override" bit NOT set — but since 0 is a valid mode we use a
        // separate sentinel approach: store raw 0-3 as override, any other value as nil.
        // Here we simply treat whatever is stored as the override (callers decide
        // whether per-category override is enabled at a higher layer).
        let raw = Int((flags & CategoryFlagMask.displayModeMask.rawValue) >> CategoryFlagShift.displayMode)
        return LibraryDisplayMode(rawValue: raw)
    }

    /// Returns a new `Category` with the display mode override set.
    func withDisplayMode(_ mode: LibraryDisplayMode) -> Category {
        let cleared = flags & ~CategoryFlagMask.displayModeMask.rawValue
        let updated = cleared | (Int64(mode.rawValue) << CategoryFlagShift.displayMode)
        return Category(id: id, name: name, sort: sort, flags: updated)
    }

    // MARK: Sort Type

    /// The per-category sort type stored in `flags`.
    var sortTypeOverride: LibrarySort.SortType? {
        let raw = Int((flags & CategoryFlagMask.sortTypeMask.rawValue) >> CategoryFlagShift.sortType)
        return LibrarySort.SortType(rawValue: raw)
    }

    /// Returns a new `Category` with the sort type override set.
    func withSortType(_ type: LibrarySort.SortType) -> Category {
        let cleared = flags & ~CategoryFlagMask.sortTypeMask.rawValue
        let updated = cleared | (Int64(type.rawValue) << CategoryFlagShift.sortType)
        return Category(id: id, name: name, sort: sort, flags: updated)
    }

    // MARK: Sort Direction

    /// The per-category sort direction stored in `flags`.
    var sortDirectionOverride: LibrarySort.Direction {
        let raw = Int((flags & CategoryFlagMask.sortDirMask.rawValue) >> CategoryFlagShift.sortDir)
        return raw == 0 ? .ascending : .descending
    }

    /// Returns a new `Category` with the sort direction override set.
    func withSortDirection(_ direction: LibrarySort.Direction) -> Category {
        let cleared = flags & ~CategoryFlagMask.sortDirMask.rawValue
        let bit: Int64 = direction == .descending ? 1 : 0
        let updated = cleared | (bit << CategoryFlagShift.sortDir)
        return Category(id: id, name: name, sort: sort, flags: updated)
    }

    // MARK: Convenience

    /// Derives the effective `LibrarySort` from the flags stored in this category.
    var effectiveSort: LibrarySort {
        LibrarySort(
            type: sortTypeOverride ?? .alphabetical,
            direction: sortDirectionOverride
        )
    }

    /// Returns a copy of this category with both sort type and direction updated.
    func withSort(_ sort: LibrarySort) -> Category {
        withSortType(sort.type).withSortDirection(sort.direction)
    }
}
