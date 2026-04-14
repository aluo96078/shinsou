import SwiftUI
import NukeUI
import Nuke

/// A UIKit-backed cover image view that reliably performs aspect-fill + center-crop.
/// Bypasses SwiftUI layout issues with NukeUI's LazyImage by using UIImageView directly.
public struct CoverImageView: UIViewRepresentable {
    let url: URL?
    let request: ImageRequest?

    public init(url: URL?) {
        self.url = url
        self.request = url.map { ImageRequest(url: $0) }
    }

    public init(request: ImageRequest?) {
        self.url = nil
        self.request = request
    }

    public func makeUIView(context: Context) -> _FillImageView {
        let iv = _FillImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
        iv.isUserInteractionEnabled = false
        return iv
    }

    public func updateUIView(_ iv: _FillImageView, context: Context) {
        guard let request else {
            iv.image = nil
            return
        }

        // Cancel previous task
        iv.currentTask?.cancel()

        let taskId = UUID()
        iv.taskId = taskId

        iv.currentTask = Task { @MainActor in
            guard let response = try? await ImagePipeline.shared.image(for: request),
                  iv.taskId == taskId else { return }
            iv.image = response
        }
    }

    /// Custom UIImageView that reports no intrinsic size,
    /// forcing SwiftUI to size it to the proposed (overlay) bounds.
    public class _FillImageView: UIImageView {
        var currentTask: Task<Void, Never>?
        var taskId: UUID?

        override public var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
    }
}
