import SwiftUI
import MarkdownUI

struct MessageBubbleView: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            // Avatar
            if message.role == .assistant || message.role == .system || message.role == .tool {
                avatarView
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 8) {
                    // Image attachments
                    if let attachments = message.attachments {
                        ForEach(attachments.filter { $0.isImage }) { attachment in
                            ImageAttachmentView(imageData: attachment.data)
                        }
                    }

                    // Markdown content
                    Markdown(message.content)
                        .markdownTextStyle(\.text) {
                            ForegroundColor(message.role == .user ? .white : Color(nsColor: .textColor))
                            FontSize(14)
                        }
                        .markdownTextStyle(\.code) {
                            FontFamilyVariant(.monospaced)
                            FontSize(13)
                            ForegroundColor(.purple)
                            BackgroundColor(Color.purple.opacity(0.1))
                        }
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            configuration.label
                                .padding(12)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(8)
                        }
                        .markdownBlockStyle(\.blockquote) { configuration in
                            configuration.label
                                .padding(.leading, 12)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.5))
                                        .frame(width: 4)
                                }
                        }
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .cornerRadius(16)
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            // Avatar for user
            if message.role == .user {
                avatarView
            }

            if message.role == .assistant || message.role == .system || message.role == .tool {
                Spacer(minLength: 60)
            }
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarBackgroundColor)
                .frame(width: 32, height: 32)

            Image(systemName: avatarIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(avatarForegroundColor)
        }
    }

    private var avatarIcon: String {
        switch message.role {
        case .user:
            return "person.fill"
        case .assistant:
            return "sparkles"
        case .tool:
            return "wrench.and.screwdriver.fill"
        case .system:
            return "gearshape.fill"
        }
    }

    private var avatarBackgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor.opacity(0.2)
        case .assistant:
            return Color.purple.opacity(0.2)
        case .tool:
            return Color.orange.opacity(0.2)
        case .system:
            return Color.gray.opacity(0.2)
        }
    }

    private var avatarForegroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor
        case .assistant:
            return Color.purple
        case .tool:
            return Color.orange
        case .system:
            return Color.gray
        }
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user:
            return Color.accentColor
        case .assistant:
            return Color(nsColor: .controlBackgroundColor)
        case .system:
            return Color.gray.opacity(0.2)
        case .tool:
            return Color.orange.opacity(0.2)
        }
    }
}
