import SwiftUI

struct SlashCommand: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let action: () -> Void
}

struct SlashCommandView: View {
    let searchText: String
    let onSelect: (SlashCommand) -> Void

    private var commands: [SlashCommand] {
        [
            SlashCommand(
                name: "whiteboard",
                description: "Open whiteboard canvas for visualizations",
                icon: "rectangle.on.rectangle.angled",
                action: { }
            ),
            SlashCommand(
                name: "image",
                description: "Generate an image",
                icon: "photo",
                action: { }
            ),
            SlashCommand(
                name: "web",
                description: "Search the web",
                icon: "globe",
                action: { }
            ),
            SlashCommand(
                name: "code",
                description: "Write code in a specific language",
                icon: "chevron.left.forwardslash.chevron.right",
                action: { }
            ),
            SlashCommand(
                name: "summarize",
                description: "Summarize the conversation",
                icon: "text.alignleft",
                action: { }
            ),
            SlashCommand(
                name: "clear",
                description: "Clear the conversation",
                icon: "trash",
                action: { }
            )
        ]
    }

    private var filteredCommands: [SlashCommand] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { $0.name.lowercased().hasPrefix(searchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !filteredCommands.isEmpty {
                VStack(spacing: 2) {
                    ForEach(filteredCommands) { command in
                        Button {
                            onSelect(command)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: command.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("/\(command.name)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(command.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.clear)
                                .hoverEffect(.highlight)
                        )
                    }
                }
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            }
        }
    }
}
