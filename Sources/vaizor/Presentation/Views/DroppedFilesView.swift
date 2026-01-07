import SwiftUI

struct DroppedFilesView: View {
    let files: [URL]
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Attachments (\(files.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear") {
                    onClear()
                }
                .buttonStyle(.plain)
                .font(.caption)
            }

            ForEach(files, id: \.self) { file in
                Text(file.lastPathComponent)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        )
    }
}
