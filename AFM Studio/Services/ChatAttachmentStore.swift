import Foundation
import ImageIO

enum ChatAttachmentStore {
    enum AttachmentError: LocalizedError {
        case noImageData(URL)
        case cannotCreateDirectory(URL)

        var errorDescription: String? {
            switch self {
            case .noImageData:
                "That file does not look like an image."
            case .cannotCreateDirectory:
                "AFM Studio could not create its attachment folder."
            }
        }
    }

    static func makeAttachments(from sourceURLs: [URL]) throws -> [ChatImageAttachment] {
        try sourceURLs.map { try makeAttachment(from: $0) }
    }

    static func makeAttachment(from sourceURL: URL) throws -> ChatImageAttachment {
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let destinationDirectory = try attachmentDirectory()
        let destinationURL = destinationDirectory.appendingPathComponent(
            uniqueFileName(for: sourceURL),
            isDirectory: false
        )

        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        guard let dimensions = imageDimensions(for: destinationURL) else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw AttachmentError.noImageData(sourceURL)
        }

        let byteCount = try? destinationURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return ChatImageAttachment(
            fileURL: destinationURL,
            displayName: sourceURL.lastPathComponent.isEmpty ? destinationURL.lastPathComponent : sourceURL.lastPathComponent,
            byteCount: byteCount.map(Int64.init),
            pixelWidth: dimensions.width,
            pixelHeight: dimensions.height
        )
    }

    static func temporaryPasteURL(fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("afm-studio-paste-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
    }

    private static func attachmentDirectory() throws -> URL {
        guard let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AttachmentError.cannotCreateDirectory(FileManager.default.temporaryDirectory)
        }

        let directory = applicationSupportURL
            .appendingPathComponent("AFM Studio", isDirectory: true)
            .appendingPathComponent("ChatAttachments", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func uniqueFileName(for sourceURL: URL) -> String {
        let name = sourceURL.deletingPathExtension().lastPathComponent
        let fallbackName = name.isEmpty ? "image" : name
        let sanitizedName = fallbackName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")
        let fileExtension = sourceURL.pathExtension.isEmpty ? "image" : sourceURL.pathExtension
        return "\(UUID().uuidString)-\(sanitizedName.isEmpty ? "image" : sanitizedName).\(fileExtension)"
    }

    private static func imageDimensions(for url: URL) -> (width: Int, height: Int)? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return nil
        }

        let width = properties[kCGImagePropertyPixelWidth] as? Int
        let height = properties[kCGImagePropertyPixelHeight] as? Int
        if let width, let height {
            return (width, height)
        }
        return nil
    }
}
