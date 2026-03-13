import WidgetKit
import SwiftUI

@main
struct MihonWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentUpdatesWidget()
        LibraryWidget()
    }
}
