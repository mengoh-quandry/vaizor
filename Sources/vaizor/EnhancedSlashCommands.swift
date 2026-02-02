import SwiftUI

// Enhanced slash commands with proper action handling
struct EnhancedSlashCommand: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let category: CommandCategory
    let requiresArgument: Bool
    
    enum CommandCategory {
        case content
        case tools
        case conversation
        case system
    }
}

extension EnhancedSlashCommand {
    static let allCommands: [EnhancedSlashCommand] = [
        // Content Generation
        EnhancedSlashCommand(
            name: "image",
            description: "Generate or analyze an image",
            icon: "photo.fill",
            category: .content,
            requiresArgument: true
        ),
        EnhancedSlashCommand(
            name: "code",
            description: "Write code in a specific language",
            icon: "chevron.left.forwardslash.chevron.right",
            category: .content,
            requiresArgument: true
        ),
        EnhancedSlashCommand(
            name: "diagram",
            description: "Create a diagram or visualization",
            icon: "chart.bar.fill",
            category: .content,
            requiresArgument: true
        ),
        EnhancedSlashCommand(
            name: "html",
            description: "Generate HTML content for whiteboard",
            icon: "globe",
            category: .content,
            requiresArgument: true
        ),
        
        // Tools
        EnhancedSlashCommand(
            name: "whiteboard",
            description: "Open whiteboard canvas",
            icon: "rectangle.on.rectangle.angled",
            category: .tools,
            requiresArgument: false
        ),
        EnhancedSlashCommand(
            name: "browser",
            description: "Open browser automation panel",
            icon: "safari",
            category: .tools,
            requiresArgument: false
        ),
        EnhancedSlashCommand(
            name: "web",
            description: "Search the web for information",
            icon: "magnifyingglass",
            category: .tools,
            requiresArgument: true
        ),
        
        // Conversation
        EnhancedSlashCommand(
            name: "summarize",
            description: "Summarize the conversation",
            icon: "text.alignleft",
            category: .conversation,
            requiresArgument: false
        ),
        EnhancedSlashCommand(
            name: "clear",
            description: "Clear the current conversation",
            icon: "trash.fill",
            category: .conversation,
            requiresArgument: false
        ),
        EnhancedSlashCommand(
            name: "export",
            description: "Export conversation to file",
            icon: "square.and.arrow.up",
            category: .conversation,
            requiresArgument: false
        ),
        
        // System
        EnhancedSlashCommand(
            name: "help",
            description: "Show available commands",
            icon: "questionmark.circle",
            category: .system,
            requiresArgument: false
        ),
        EnhancedSlashCommand(
            name: "settings",
            description: "Open settings panel",
            icon: "gearshape.fill",
            category: .system,
            requiresArgument: false
        )
    ]
}

struct EnhancedSlashCommandView: View {
    let searchText: String
    let onSelect: (EnhancedSlashCommand, String) -> Void
    let onDismiss: () -> Void
    
    private var filteredCommands: [EnhancedSlashCommand] {
        let search = searchText.lowercased()
        if search.isEmpty {
            return EnhancedSlashCommand.allCommands
        }
        return EnhancedSlashCommand.allCommands.filter {
            $0.name.lowercased().hasPrefix(search) ||
            $0.description.lowercased().contains(search)
        }
    }
    
    private var commandsByCategory: [(category: EnhancedSlashCommand.CommandCategory, commands: [EnhancedSlashCommand])] {
        let categories: [EnhancedSlashCommand.CommandCategory] = [.content, .tools, .conversation, .system]
        return categories.compactMap { category in
            let cmds = filteredCommands.filter { $0.category == category }
            return cmds.isEmpty ? nil : (category, cmds)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !filteredCommands.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(commandsByCategory, id: \.category) { section in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(categoryName(section.category))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.top, section.category == .content ? 4 : 8)
                                
                                ForEach(section.commands) { command in
                                    CommandRow(command: command) {
                                        onSelect(command, searchText)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
                .background(Material.thick)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
            }
        }
    }
    
    private func categoryName(_ category: EnhancedSlashCommand.CommandCategory) -> String {
        switch category {
        case .content: return "Content Generation"
        case .tools: return "Tools & Features"
        case .conversation: return "Conversation"
        case .system: return "System"
        }
    }
}

struct CommandRow: View {
    let command: EnhancedSlashCommand
    let onTap: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: command.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isHovered ? .blue : .secondary)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("/\(command.name)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if command.requiresArgument {
                            Text("requires argument")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(command.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
