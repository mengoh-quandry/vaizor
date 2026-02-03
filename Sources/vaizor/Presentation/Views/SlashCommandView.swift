import SwiftUI

struct SlashCommand: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let category: CommandCategory
    let action: () -> Void
    let value: String? // Optional value for commands like template names
    
    init(name: String, description: String, icon: String, category: CommandCategory, action: @escaping () -> Void, value: String? = nil) {
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.action = action
        self.value = value
    }
}

enum CommandCategory {
    case native
    case mcp
}

struct SlashCommandGroup {
    let title: String
    let commands: [SlashCommand]
}

struct SlashCommandView: View {
    let searchText: String
    let onSelect: (SlashCommand) -> Void
    @EnvironmentObject var container: DependencyContainer
    @ObservedObject var conversationManager: ConversationManager

    private var nativeCommands: [SlashCommand] {
        [
            SlashCommand(
                name: "whiteboard",
                description: "Open whiteboard canvas for visualizations",
                icon: "rectangle.on.rectangle.angled",
                category: .native,
                action: { }
            ),
            SlashCommand(
                name: "image",
                description: "Generate an image",
                icon: "photo",
                category: .native,
                action: { }
            ),
            SlashCommand(
                name: "web",
                description: "Search the web",
                icon: "globe",
                category: .native,
                action: { }
            ),
            SlashCommand(
                name: "code",
                description: "Write code in a specific language",
                icon: "chevron.left.forwardslash.chevron.right",
                category: .native,
                action: { }
            ),
            SlashCommand(
                name: "summarize",
                description: "Summarize the conversation",
                icon: "text.alignleft",
                category: .native,
                action: { }
            ),
            SlashCommand(
                name: "clear",
                description: "Clear the conversation",
                icon: "trash",
                category: .native,
                action: { }
            )
        ]
    }

    private var mcpCommands: [SlashCommand] {
        var commands: [SlashCommand] = []

        // Add tools
        for tool in container.mcpManager.availableTools {
            commands.append(SlashCommand(
                name: tool.name,
                description: tool.description,
                icon: "wrench.and.screwdriver",
                category: .mcp,
                action: { }
            ))
        }

        // Add resources
        for resource in container.mcpManager.availableResources {
            commands.append(SlashCommand(
                name: "resource:\(resource.name)",
                description: resource.description ?? "Read resource: \(resource.uri)",
                icon: "doc.text.fill",
                category: .mcp,
                action: { },
                value: resource.uri
            ))
        }

        // Add prompts
        for prompt in container.mcpManager.availablePrompts {
            commands.append(SlashCommand(
                name: "prompt:\(prompt.name)",
                description: prompt.description ?? "Use prompt template",
                icon: "text.bubble.fill",
                category: .mcp,
                action: { }
            ))
        }

        return commands
    }

    private var templateCommands: [SlashCommand] {
        conversationManager.templates.map { template in
            SlashCommand(
                name: "template",
                description: "Load template: \(template.name)",
                icon: "doc.text",
                category: .native,
                action: { },
                value: template.name
            )
        }
    }
    
    private var commandGroups: [SlashCommandGroup] {
        var groups: [SlashCommandGroup] = []

        let filteredNative = filterCommands(nativeCommands)
        if !filteredNative.isEmpty {
            groups.append(SlashCommandGroup(title: "Native Tools", commands: filteredNative))
        }
        
        let filteredTemplates = filterCommands(templateCommands)
        if !filteredTemplates.isEmpty {
            groups.append(SlashCommandGroup(title: "Templates", commands: filteredTemplates))
        }

        let filteredMCP = filterCommands(mcpCommands)
        if !filteredMCP.isEmpty {
            groups.append(SlashCommandGroup(title: "MCP (Tools, Resources, Prompts)", commands: filteredMCP))
        }

        return groups
    }

    private func filterCommands(_ commands: [SlashCommand]) -> [SlashCommand] {
        if searchText.isEmpty {
            return commands
        }
        return commands.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !commandGroups.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(commandGroups.enumerated()), id: \.offset) { index, group in
                            VStack(spacing: 0) {
                                // Section header
                                HStack {
                                    Text(group.title)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.03))

                                // Commands in group
                                VStack(spacing: 0) {
                                    ForEach(group.commands.prefix(8)) { command in
                                        CommandRow(command: command, onSelect: onSelect)
                                    }
                                }

                                // Divider between groups (except last)
                                if index < commandGroups.count - 1 {
                                    Divider()
                                        .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 320)
                .background(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            }
        }
        .frame(width: 280)
    }
}

struct CommandRow: View {
    let command: SlashCommand
    let onSelect: (SlashCommand) -> Void
    @State private var isHovered = false

    private var iconColor: Color {
        command.category == .native ? .blue : ThemeColors.accent
    }

    var body: some View {
        Button {
            onSelect(command)
        } label: {
            HStack(spacing: 8) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 20, height: 20)

                    Image(systemName: command.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .symbolRenderingMode(.hierarchical)
                }

                // Text content
                VStack(alignment: .leading, spacing: 1) {
                    Text("/\(command.name)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(command.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Category badge for MCP tools
                if command.category == .mcp {
                    Text("MCP")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(ThemeColors.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(ThemeColors.accent.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isHovered ? iconColor.opacity(0.08) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
