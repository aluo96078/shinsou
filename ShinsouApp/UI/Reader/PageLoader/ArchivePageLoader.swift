import Foundation
import ShinsouSourceAPI
import Compression

/// Loads pages from a CBZ / ZIP archive.
///
/// Because the Swift standard library does not ship a high-level ZIP API,
/// this loader uses a two-phase approach:
///   1. It extracts the archive into a temporary directory on first access.
///   2. It then delegates to `DownloadPageLoader` to read the extracted files.
///
/// The temporary directory is cleaned up when the loader is deallocated.
final class ArchivePageLoader: PageLoader {

    private let archiveURL: URL
    private var extractedDirectory: URL?
    private var innerLoader: DownloadPageLoader?

    /// - Parameter archiveURL: Path to the `.cbz` / `.zip` archive file.
    init(archiveURL: URL) {
        self.archiveURL = archiveURL
    }

    deinit {
        // Best-effort cleanup of the temporary extraction directory.
        if let dir = extractedDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - PageLoader

    func getPages() async throws -> [ReaderPage] {
        let loader = try await prepareLoader()
        return try await loader.getPages()
    }

    func loadPage(_ page: ReaderPage) async throws {
        let loader = try await prepareLoader()
        try await loader.loadPage(page)
    }

    func cancel() {
        innerLoader?.cancel()
    }

    // MARK: - Private helpers

    private func prepareLoader() async throws -> DownloadPageLoader {
        if let existing = innerLoader { return existing }

        let extractDir = try extractArchive()
        extractedDirectory = extractDir
        let loader = DownloadPageLoader(chapterDirectory: extractDir)
        innerLoader = loader
        return loader
    }

    /// Extracts the ZIP/CBZ archive to a unique temporary directory and returns the directory URL.
    private func extractArchive() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("shinsou_archive_\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        try extractUsingBuiltIn(to: tmp)

        return tmp
    }

    // MARK: Pure-Swift ZIP extractor

    /// Minimal ZIP extractor that understands the local-file-header structure.
    /// Supports stored (method 0) and deflated (method 8) entries.
    private func extractUsingBuiltIn(to destination: URL) throws {
        let data = try Data(contentsOf: archiveURL, options: .mappedIfSafe)
        var offset = 0

        let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "avif"]

        while offset + 30 <= data.count {
            // Local file header signature: 0x04034b50
            let sig = data.load(offset: offset, as: UInt32.self).littleEndian
            guard sig == 0x04034B50 else { break }

            let compressionMethod = data.load(offset: offset + 8, as: UInt16.self).littleEndian
            let compressedSize    = Int(data.load(offset: offset + 18, as: UInt32.self).littleEndian)
            let uncompressedSize  = Int(data.load(offset: offset + 22, as: UInt32.self).littleEndian)
            let fileNameLength    = Int(data.load(offset: offset + 26, as: UInt16.self).littleEndian)
            let extraFieldLength  = Int(data.load(offset: offset + 28, as: UInt16.self).littleEndian)

            let fileNameStart = offset + 30
            let fileNameEnd   = fileNameStart + fileNameLength
            let dataStart     = fileNameEnd + extraFieldLength
            let dataEnd       = dataStart + compressedSize

            guard dataEnd <= data.count else { break }

            if let entryName = String(data: data[fileNameStart..<fileNameEnd], encoding: .utf8),
               !entryName.hasSuffix("/") {

                let ext = URL(fileURLWithPath: entryName).pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    let compressedData = data[dataStart..<dataEnd]
                    let outputData: Data

                    switch compressionMethod {
                    case 0: // Stored
                        outputData = Data(compressedData)
                    case 8: // Deflated
                        outputData = try inflateDeflate(Data(compressedData), expectedSize: uncompressedSize)
                    default:
                        offset = dataEnd
                        continue
                    }

                    // Flatten path — use only the filename component to avoid directory traversal.
                    let fileName     = URL(fileURLWithPath: entryName).lastPathComponent
                    let destFile     = destination.appendingPathComponent(fileName)
                    try outputData.write(to: destFile, options: .atomic)
                }
            }

            offset = dataEnd
        }
    }

    /// Inflates a raw DEFLATE stream using the Compression framework.
    private func inflateDeflate(_ input: Data, expectedSize: Int) throws -> Data {
        // Remove the 2-byte zlib header if present (first byte 0x78)
        let rawInput: Data = input.first == 0x78 ? input.dropFirst(2) : input

        var outputBuffer = [UInt8](repeating: 0, count: max(expectedSize, rawInput.count * 4))

        let result = rawInput.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
            guard let src = srcPtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                &outputBuffer, outputBuffer.count,
                src.assumingMemoryBound(to: UInt8.self), rawInput.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard result > 0 else {
            throw ArchiveError.extractionFailed("DEFLATE decompression failed for entry")
        }

        return Data(outputBuffer[0..<result])
    }
}

// MARK: - Data helpers

private extension Data {
    func load<T>(offset: Int, as type: T.Type) -> T {
        withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: T.self)
        }
    }
}

// MARK: - ArchiveError

enum ArchiveError: LocalizedError {
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let msg): return "Archive extraction failed: \(msg)"
        }
    }
}
