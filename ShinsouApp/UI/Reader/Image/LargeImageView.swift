import UIKit

/// A UIView that uses CATiledLayer for rendering extremely large images (>4096 px)
/// without running out of memory. Intended for webtoon-style long-strip images.
class LargeImageView: UIView {
    var image: UIImage? {
        didSet { updateImage() }
    }

    override class var layerClass: AnyClass {
        CATiledLayer.self
    }

    private var tiledLayer: CATiledLayer {
        // swiftlint:disable:next force_cast
        layer as! CATiledLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        tiledLayer.levelsOfDetail      = 4
        tiledLayer.levelsOfDetailBias  = 3
        tiledLayer.tileSize            = CGSize(width: 512, height: 512)
        backgroundColor = .black
    }

    private func updateImage() {
        guard let image else { return }
        frame = CGRect(origin: frame.origin, size: image.size)
        tiledLayer.setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = image?.cgImage else { return }

        context.saveGState()
        // Flip coordinate system (Core Graphics uses bottom-left origin)
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)

        // Draw only the requested tile rect to keep memory usage low
        if let croppedImage = cgImage.cropping(to: rect) {
            context.draw(croppedImage, in: rect)
        }

        context.restoreGState()
    }
}
