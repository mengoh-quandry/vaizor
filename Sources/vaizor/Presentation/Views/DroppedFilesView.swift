import SwiftUI
import UniformTypeIdentifiers

struct DroppedFilesView: View {
    let files: [URL]
    let onClear: () -> Void
    var onRemoveFile: ((URL) -> Void)?

    init(files: [URL], onClear: @escaping () -> Void, onRemoveFile: ((URL) -> Void)? = nil) {
        self.files = files
        self.onClear = onClear
        self.onRemoveFile = onRemoveFile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ThemeColors.accent)
                    Text("Attachments")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("(\(files.count))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onClear()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Clear all")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear all attachments")
            }

            // File list with previews
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(files, id: \.self) { file in
                        DroppedFileCard(
                            file: file,
                            onRemove: onRemoveFile != nil ? { onRemoveFile?(file) } : nil
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ThemeColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ThemeColors.darkBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Attached files: \(files.count)")
    }
}

/// Individual file card with thumbnail preview
struct DroppedFileCard: View {
    let file: URL
    let onRemove: (() -> Void)?

    @State private var thumbnail: NSImage?
    @State private var isHovered = false

    private var fileInfo: FileInfo {
        FileInfo(url: file)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Thumbnail or icon
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fileInfo.backgroundColor)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: fileInfo.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(fileInfo.iconColor)
                        )
                }

                // Remove button overlay
                if isHovered, let onRemove = onRemove {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                onRemove()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.6))
                                            .frame(width: 18, height: 18)
                                    )
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: -4)
                            .accessibilityLabel("Remove \(file.lastPathComponent)")
                        }
                        Spacer()
                    }
                }
            }
            .frame(width: 60, height: 60)

            // File info
            VStack(spacing: 2) {
                Text(file.lastPathComponent)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 70)

                Text(fileInfo.sizeString)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? ThemeColors.hoverBackground : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.lastPathComponent), \(fileInfo.sizeString)")
    }

    private func loadThumbnail() {
        // Only load thumbnails for images
        guard fileInfo.isImage else { return }

        Task {
            if let image = NSImage(contentsOf: file) {
                // Resize for thumbnail
                let targetSize = NSSize(width: 120, height: 120)
                let resizedImage = NSImage(size: targetSize)
                resizedImage.lockFocus()
                image.draw(
                    in: NSRect(origin: .zero, size: targetSize),
                    from: NSRect(origin: .zero, size: image.size),
                    operation: .copy,
                    fraction: 1.0
                )
                resizedImage.unlockFocus()

                await MainActor.run {
                    thumbnail = resizedImage
                }
            }
        }
    }
}

/// File information helper
struct FileInfo {
    let url: URL

    var isImage: Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }

    var icon: String {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "pdf":
            return "doc.fill"
        case "txt", "md", "markdown":
            return "doc.text.fill"
        case "json":
            return "curlybraces"
        case "csv":
            return "tablecells.fill"
        case "jpg", "jpeg", "png", "gif", "heic", "webp":
            return "photo.fill"
        case "mp4", "mov", "avi":
            return "video.fill"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "zip", "tar", "gz":
            return "doc.zipper"
        case "swift", "py", "js", "ts", "html", "css":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }

    var iconColor: Color {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "pdf":
            return .red
        case "txt", "md":
            return ThemeColors.textSecondary
        case "json":
            return .orange
        case "csv":
            return .green
        case "jpg", "jpeg", "png", "gif", "heic", "webp":
            return .blue
        case "swift":
            return .orange
        case "py":
            return .yellow
        case "js", "ts":
            return .yellow
        default:
            return ThemeColors.accent
        }
    }

    var backgroundColor: Color {
        iconColor.opacity(0.15)
    }

    var sizeString: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return "Unknown size"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: size)
    }
}
