import WidgetKit
import SwiftUI

@main
struct ShinsouWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentUpdatesWidget()
        LibraryWidget()
    }
}
