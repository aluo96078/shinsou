import UIKit

// MARK: - ImageSplitter

/// Detects tall images (webtoon strips) and splits them into page-sized sub-images.
/// An image is considered "tall" when its height exceeds 2× its width.
enum ImageSplitter {

    /// The aspect-ratio threshold above which an image is considered tall.
    private static let tallImageThreshold: CGFloat = 2.0

    // MARK: - Public API

    /// Returns `true` when the image should be split based on height/width ratio.
    static func isTall(_ image: UIImage) -> Bool {
        guard image.size.width > 0 else { return false }
        return image.size.height / image.size.width > tallImageThreshold
    }

    /// Splits a tall image into an array of sub-images, each at most `targetHeight` pixels tall.
    /// If the image is not tall, a single-element array containing the original image is returned.
    ///
    /// - Parameters:
    ///   - image: The source image to split.
    ///   - targetHeight: The desired height of each slice in points. Defaults to the main screen height.
    /// - Returns: An ordered array of `UIImage` slices.
    static func split(_ image: UIImage, targetHeight: CGFloat = UIScreen.main.bounds.height) -> [UIImage] {
        guard isTall(image), let cgImage = image.cgImage else {
            return [image]
        }

        let scale = image.scale
        let imageWidth  = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Convert point-based target height to pixel height
        let sliceHeightPx = targetHeight * scale

        var slices: [UIImage] = []
        var yOffset: CGFloat = 0

        while yOffset < imageHeight {
            let remaining = imageHeight - yOffset
            let sliceH    = min(sliceHeightPx, remaining)

            let cropRect = CGRect(x: 0, y: yOffset, width: imageWidth, height: sliceH)
            if let cgSlice = cgImage.cropping(to: cropRect) {
                let sliceImage = UIImage(cgImage: cgSlice, scale: scale, orientation: image.imageOrientation)
                slices.append(sliceImage)
            }

            yOffset += sliceH
        }

        return slices.isEmpty ? [image] : slices
    }

    /// Splits a raw `Data` blob representing an image and returns the resulting slices as `Data`.
    /// Useful when you want to keep results in compressed form (e.g., JPEG) rather than decoded pixels.
    ///
    /// - Parameters:
    ///   - data: Raw image data (JPEG / PNG / WebP).
    ///   - targetHeight: Desired height per slice in points.
    ///   - compressionQuality: JPEG compression quality for output slices (0.0 – 1.0).
    /// - Returns: Ordered array of `Data` slices, or the original `data` wrapped in an array on failure.
    static func splitData(
        _ data: Data,
        targetHeight: CGFloat = UIScreen.main.bounds.height,
        compressionQuality: CGFloat = 0.9
    ) -> [Data] {
        guard let image = UIImage(data: data) else { return [data] }
        let slices = split(image, targetHeight: targetHeight)
        return slices.compactMap { $0.jpegData(compressionQuality: compressionQuality) }
    }
}
