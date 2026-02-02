import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ImageAttachmentView: View {
    let imageData: Data
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 400, maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 200, height: 150)
                    .overlay(
                        ProgressView()
                    )
                    .cornerRadius(12)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        if let nsImage = NSImage(data: imageData) {
            image = nsImage
        }
    }
}

// Extension to handle NSImage conversion
extension MessageAttachment {
    var nsImage: NSImage? {
        NSImage(data: data)
    }
}

// MARK: - Pending Attachment for Preview

/// Represents a file attachment pending to be sent with a message
struct PendingAttachment: Identifiable, Equatable {
    let id: UUID
    let data: Data
    let filename: String
    let mimeType: String
    let fileType: AttachmentFileType

    enum AttachmentFileType: Equatable {
        case image
        case pdf
        case text
        case other

        var iconName: String {
            switch self {
            case .image: return "photo"
            case .pdf: return "doc.fill"
            case .text: return "doc.text"
            case .other: return "doc"
            }
        }
    }

    init(data: Data, filename: String, mimeType: String) {
        self.id = UUID()
        self.data = data
        self.filename = filename
        self.mimeType = mimeType

        if mimeType.hasPrefix("image/") {
            self.fileType = .image
        } else if mimeType == "application/pdf" {
            self.fileType = .pdf
        } else if mimeType.hasPrefix("text/") || mimeType == "application/json" {
            self.fileType = .text
        } else {
            self.fileType = .other
        }
    }

    /// Convert to MessageAttachment for sending
    func toMessageAttachment() -> MessageAttachment {
        MessageAttachment(
            id: id,
            data: data,
            mimeType: mimeType,
            filename: filename
        )
    }

    /// Get human-readable file size
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(data.count))
    }
}

// MARK: - Attachment Preview View

/// Preview view for pending attachments before sending
struct AttachmentPreviewView: View {
    let attachment: PendingAttachment
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            contentView
                .frame(width: 80, height: 80)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            // Remove button
            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white, .red)
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .help("\(attachment.filename)\n\(attachment.formattedSize)")
    }

    @ViewBuilder
    private var contentView: some View {
        switch attachment.fileType {
        case .image:
            if let nsImage = NSImage(data: attachment.data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                iconView
            }
        case .pdf, .text, .other:
            iconView
        }
    }

    private var iconView: some View {
        VStack(spacing: 4) {
            Image(systemName: attachment.fileType.iconName)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text(attachment.filename)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Attachment Strip View

/// Horizontal strip showing all pending attachments
struct AttachmentStripView: View {
    let attachments: [PendingAttachment]
    let onRemove: (PendingAttachment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentPreviewView(attachment: attachment) {
                        onRemove(attachment)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Drop Delegate and Utilities

/// Supported file types for drag & drop
enum SupportedDropType {
    static let imageTypes: [UTType] = [.png, .jpeg, .gif, .webP, .heic, .tiff, .bmp]
    static let documentTypes: [UTType] = [.pdf, .plainText, .json, .xml, .html, .sourceCode]
    static let allTypes: [UTType] = imageTypes + documentTypes + [.fileURL]

    /// Get MIME type from UTType
    static func mimeType(for utType: UTType) -> String {
        if let mimeType = utType.preferredMIMEType {
            return mimeType
        }

        // Fallback mappings
        switch utType {
        case .png: return "image/png"
        case .jpeg: return "image/jpeg"
        case .gif: return "image/gif"
        case .webP: return "image/webp"
        case .heic: return "image/heic"
        case .tiff: return "image/tiff"
        case .bmp: return "image/bmp"
        case .pdf: return "application/pdf"
        case .plainText: return "text/plain"
        case .json: return "application/json"
        case .xml: return "application/xml"
        case .html: return "text/html"
        default: return "application/octet-stream"
        }
    }

    /// Get MIME type from file extension
    static func mimeType(forExtension ext: String) -> String {
        let lowercased = ext.lowercased()
        switch lowercased {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic", "heif": return "image/heic"
        case "tiff", "tif": return "image/tiff"
        case "bmp": return "image/bmp"
        case "pdf": return "application/pdf"
        case "txt": return "text/plain"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "html", "htm": return "text/html"
        case "swift", "py", "js", "ts", "rb", "go", "rs", "c", "cpp", "h", "hpp", "java", "kt", "m", "mm":
            return "text/plain"
        case "md", "markdown": return "text/markdown"
        case "css": return "text/css"
        case "yaml", "yml": return "text/yaml"
        default: return "application/octet-stream"
        }
    }

    /// Check if file extension is supported
    static func isSupported(extension ext: String) -> Bool {
        let supportedExtensions = [
            "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tiff", "tif", "bmp",
            "pdf", "txt", "json", "xml", "html", "htm",
            "swift", "py", "js", "ts", "rb", "go", "rs", "c", "cpp", "h", "hpp", "java", "kt", "m", "mm",
            "md", "markdown", "css", "yaml", "yml"
        ]
        return supportedExtensions.contains(ext.lowercased())
    }
}

// MARK: - Clipboard Paste Handler

/// Utility for handling clipboard paste operations
struct ClipboardHandler {
    /// Check if clipboard contains an image
    static func hasImage() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadItem(withDataConformingToTypes: [
            NSPasteboard.PasteboardType.png.rawValue,
            NSPasteboard.PasteboardType.tiff.rawValue,
            "public.jpeg",
            "public.heic"
        ])
    }

    /// Get image from clipboard as PendingAttachment
    static func getImage() -> PendingAttachment? {
        let pasteboard = NSPasteboard.general

        // Try to get PNG data first (best quality)
        if let data = pasteboard.data(forType: .png) {
            return PendingAttachment(
                data: data,
                filename: "pasted-image.png",
                mimeType: "image/png"
            )
        }

        // Try TIFF
        if let data = pasteboard.data(forType: .tiff) {
            // Convert TIFF to PNG for better compatibility
            if let image = NSImage(data: data),
               let tiffRep = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffRep),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                return PendingAttachment(
                    data: pngData,
                    filename: "pasted-image.png",
                    mimeType: "image/png"
                )
            }
            return PendingAttachment(
                data: data,
                filename: "pasted-image.tiff",
                mimeType: "image/tiff"
            )
        }

        // Try reading as NSImage and converting
        if let image = NSImage(pasteboard: pasteboard) {
            if let tiffRep = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffRep),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                return PendingAttachment(
                    data: pngData,
                    filename: "pasted-image.png",
                    mimeType: "image/png"
                )
            }
        }

        return nil
    }

    /// Check if clipboard contains files
    static func hasFiles() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue])
    }

    /// Get files from clipboard as PendingAttachments
    static func getFiles() -> [PendingAttachment] {
        let pasteboard = NSPasteboard.general
        var attachments: [PendingAttachment] = []

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return attachments
        }

        for url in urls {
            if let attachment = loadFile(from: url) {
                attachments.append(attachment)
            }
        }

        return attachments
    }

    /// Load a file from URL into PendingAttachment
    static func loadFile(from url: URL) -> PendingAttachment? {
        let ext = url.pathExtension
        guard SupportedDropType.isSupported(extension: ext) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let mimeType = SupportedDropType.mimeType(forExtension: ext)
            return PendingAttachment(
                data: data,
                filename: url.lastPathComponent,
                mimeType: mimeType
            )
        } catch {
            print("Failed to load file from \(url): \(error)")
            return nil
        }
    }
}
