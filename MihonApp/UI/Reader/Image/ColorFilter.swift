import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ColorFilterType: Int, CaseIterable {
    case none = 0
    case grayscale = 1
    case invertColors = 2
    case customBrightness = 3
    case sepia = 4

    var displayName: String {
        switch self {
        case .none: return "None"
        case .grayscale: return "Grayscale"
        case .invertColors: return "Invert"
        case .customBrightness: return "Custom Brightness"
        case .sepia: return "Sepia"
        }
    }
}

class ColorFilterOverlay: UIView {
    var filterType: ColorFilterType = .none {
        didSet { updateFilter() }
    }
    var brightness: CGFloat = 0 {
        didSet { updateFilter() }
    }
    var customColorR: CGFloat = 0 {
        didSet { updateFilter() }
    }
    var customColorG: CGFloat = 0 {
        didSet { updateFilter() }
    }
    var customColorB: CGFloat = 0 {
        didSet { updateFilter() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateFilter() {
        switch filterType {
        case .none:
            backgroundColor = .clear
            layer.compositingFilter = nil
        case .grayscale:
            backgroundColor = .clear
            layer.compositingFilter = "saturationBlendMode"
        case .invertColors:
            backgroundColor = .white
            layer.compositingFilter = "differenceBlendMode"
        case .customBrightness:
            let alpha = max(0, min(1, abs(brightness)))
            backgroundColor = brightness < 0
                ? UIColor.black.withAlphaComponent(alpha)
                : UIColor.white.withAlphaComponent(alpha)
            layer.compositingFilter = nil
        case .sepia:
            backgroundColor = UIColor(red: 0.4, green: 0.3, blue: 0.1, alpha: 0.3)
            layer.compositingFilter = nil
        }
    }
}
