import SwiftUI

struct MessageActionRow: View {
    let message: Message
    let isUser: Bool
    let isPromptEnhanced: Bool
    let onCopy: () -> Void
    let onEdit: (() -> Void)?
    let onDelete: () -> Void
    let onRegenerate: (() -> Void)?
    let onRegenerateDifferent: (() -> Void)?
    let onScrollToTop: (() -> Void)?

    var body: some View {
        Group {
            HStack(spacing: 8) {
                if isUser {
                    // User message actions
                    if let onEdit = onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Edit")
                        .accessibilityLabel("Edit message")
                    }

                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")
                    .accessibilityLabel("Copy message to clipboard")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Undo (Delete message and response)")
                    .accessibilityLabel("Delete message and response")

                    // Prompt enhancement indicator
                    if isPromptEnhanced {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "00976d"))
                            .help("Prompt enhanced")
                            .accessibilityLabel("Prompt was enhanced")
                    }
                } else {
                    // Assistant message actions
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Copy")
                    .accessibilityLabel("Copy response to clipboard")

                    if let onScrollToTop = onScrollToTop {
                        Button {
                            onScrollToTop()
                        } label: {
                            Image(systemName: "arrow.up.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Go to Top of Response")
                        .accessibilityLabel("Scroll to top of response")
                    }

                    if let onRegenerate = onRegenerate {
                        Button {
                            onRegenerate()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Regenerate")
                        .accessibilityLabel("Regenerate response")
                    }

                    if let onRegenerateDifferent = onRegenerateDifferent {
                        Button {
                            onRegenerateDifferent()
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Regenerate with Different Model")
                        .accessibilityLabel("Regenerate with different model")
                    }

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Response")
                    .accessibilityLabel("Delete response")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .transition(.opacity.combined(with: .scale))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message actions")
    }
}
