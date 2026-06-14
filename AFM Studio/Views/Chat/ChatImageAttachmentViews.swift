import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ChatImageAttachmentStrip: View {
    let attachments: [ChatImageAttachment]
    var thumbnailSize: CGFloat = 72
    var onRemove: ((ChatImageAttachment) -> Void)?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    ChatImageAttachmentThumbnail(
                        attachment: attachment,
                        thumbnailSize: thumbnailSize,
                        onRemove: onRemove
                    )
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ChatImageAttachmentThumbnail: View {
    let attachment: ChatImageAttachment
    let thumbnailSize: CGFloat
    var onRemove: ((ChatImageAttachment) -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ChatImageThumbnail(attachment: attachment)
                .frame(width: thumbnailSize, height: thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.platformSeparator.opacity(0.35), lineWidth: 1)
                )

            if let onRemove {
                Button {
                    onRemove(attachment)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.68))
                }
                .buttonStyle(.plain)
                .padding(4)
                .help("Remove image")
                .accessibilityLabel("Remove image")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(attachment.accessibilityLabel)
    }
}

private struct ChatImageThumbnail: View {
    let attachment: ChatImageAttachment

    var body: some View {
        #if os(macOS)
        if let image = NSImage(contentsOf: attachment.fileURL) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            fallback
        }
        #elseif os(iOS)
        if let image = UIImage(contentsOfFile: attachment.fileURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            fallback
        }
        #endif
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.platformControlBackground)
            Image(systemName: "photo")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
