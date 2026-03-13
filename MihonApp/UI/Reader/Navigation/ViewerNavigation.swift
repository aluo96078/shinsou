import CoreGraphics

enum NavigationRegion {
    case left, right, menu
}

protocol ViewerNavigation {
    func getAction(at point: CGPoint, in bounds: CGSize) -> NavigationRegion
}

/// Default: right side = next, left side = prev, centre/top = menu
struct RightAndLeftNavigation: ViewerNavigation {
    func getAction(at point: CGPoint, in bounds: CGSize) -> NavigationRegion {
        let x = point.x / bounds.width
        let y = point.y / bounds.height

        // Top 5% is always menu
        if y < 0.05 { return .menu }

        if x < 0.33 { return .left  }
        if x > 0.66 { return .right }
        return .menu
    }
}

/// L-shaped navigation
struct LNavigation: ViewerNavigation {
    func getAction(at point: CGPoint, in bounds: CGSize) -> NavigationRegion {
        let x = point.x / bounds.width
        let y = point.y / bounds.height

        if y < 0.05 { return .menu }

        // Top half: only right side is next
        if y < 0.5 {
            if x > 0.66 { return .right }
            return .menu
        }

        // Bottom half: left 33% = prev, rest = next
        if x < 0.33 { return .left }
        return .right
    }
}

/// Kindle-style navigation
struct KindlishNavigation: ViewerNavigation {
    func getAction(at point: CGPoint, in bounds: CGSize) -> NavigationRegion {
        let x = point.x / bounds.width
        let y = point.y / bounds.height

        if y < 0.05 { return .menu }

        if x < 0.33 {
            return y < 0.5 ? .menu : .left
        }
        return .right
    }
}

/// Edge navigation — only the edges trigger page turns
struct EdgeNavigation: ViewerNavigation {
    func getAction(at point: CGPoint, in bounds: CGSize) -> NavigationRegion {
        let x = point.x / bounds.width
        let y = point.y / bounds.height

        if y < 0.05 { return .menu }

        if x < 0.15 { return .left  }
        if x > 0.85 { return .right }
        return .menu
    }
}

/// Disabled — all taps show the menu
struct DisabledNavigation: ViewerNavigation {
    func getAction(at point: CGPoint, in bounds: CGSize) -> NavigationRegion {
        .menu
    }
}
