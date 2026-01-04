import SwiftUI
import AppKit

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

// Extension to handle image URLs in markdown
extension MessageAttachment {
    var isImage: Bool {
        guard let mimeType = mimeType else { return false }
        return mimeType.hasPrefix("image/")
    }

    var nsImage: NSImage? {
        NSImage(data: data)
    }
}
