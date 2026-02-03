import SwiftUI

struct ProjectSidebarView: View {
    @ObservedObject var projectManager: ProjectManager
    @ObservedObject var conversationManager: ConversationManager
    @State private var showCreateProject = false
    @State private var showProjectIngestion = false
    @State private var searchText = ""
    @State private var selectedProjectId: UUID?
    @Binding var showProjectSettings: Bool
    @Binding var projectForSettings: Project?

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient background
            HStack {
                Text("Projects")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showProjectIngestion = true
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.accent)
                }
                .buttonStyle(.plain)
                .help("Ingest local project")

                Button {
                    showCreateProject = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ThemeColors.accent)
                        .shadow(color: ThemeColors.accentGlow, radius: 4, y: 0)
                }
                .buttonStyle(.plain)
                .help("Create new project")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ThemeColors.headerGradient)

            // Gradient divider
            Rectangle()
                .fill(ThemeColors.gradientDivider())
                .frame(height: 1)

            // Search with sunken input style
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ThemeColors.sunkenInput)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(ThemeColors.dividerSubtle, lineWidth: 0.5)
            )

            // Project List
            ScrollView {
                LazyVStack(spacing: 2) {
                    // "All Conversations" option
                    ProjectRowItem(
                        name: "All Conversations",
                        iconName: "bubble.left.and.bubble.right",
                        color: nil,
                        isSelected: projectManager.currentProject == nil,
                        conversationCount: conversationManager.conversations.count
                    ) {
                        projectManager.selectProject(nil)
                    }

                    Divider()
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)

                    // Projects
                    ForEach(filteredProjects) { project in
                        ProjectRowItem(
                            name: project.name,
                            iconName: project.iconName ?? "folder.fill",
                            color: project.color,
                            isSelected: projectManager.currentProject?.id == project.id,
                            conversationCount: project.conversations.count
                        ) {
                            projectManager.selectProject(project)
                        }
                        .contextMenu {
                            projectContextMenu(for: project)
                        }
                    }

                    if filteredProjects.isEmpty && !searchText.isEmpty {
                        ProjectSearchEmptyView(
                            query: searchText,
                            onClear: { searchText = "" }
                        )
                    }

                    if projectManager.projects.isEmpty {
                        emptyStateView
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .sheet(isPresented: $showCreateProject) {
            CreateProjectView(
                isPresented: $showCreateProject,
                projectManager: projectManager
            )
        }
        .sheet(isPresented: $showProjectIngestion) {
            ProjectIngestionView(isPresented: $showProjectIngestion)
                .frame(minWidth: 700, minHeight: 550)
        }
    }

    private var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projectManager.projects
        }
        return projectManager.searchProjects(query: searchText)
    }

    @ViewBuilder
    private func projectContextMenu(for project: Project) -> some View {
        Button {
            projectForSettings = project
            showProjectSettings = true
        } label: {
            Label("Settings", systemImage: "gearshape")
        }

        Divider()

        Button {
            // Create new conversation in this project
            let conversation = conversationManager.createConversation()
            projectManager.addConversationToProject(
                conversationId: conversation.id,
                projectId: project.id
            )
            conversationManager.updateProjectId(conversation.id, projectId: project.id)
        } label: {
            Label("New Conversation", systemImage: "plus.bubble")
        }

        Divider()

        Button(role: .destructive) {
            projectManager.archiveProject(project.id, isArchived: true)
        } label: {
            Label("Archive", systemImage: "archivebox")
        }

        Button(role: .destructive) {
            projectManager.deleteProject(project.id)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 20)

            // Animated illustration
            ProjectEmptyStateIllustration()

            VStack(spacing: 8) {
                Text("Organize your work")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Projects help you group related\nconversations with shared context")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Features list
            VStack(alignment: .leading, spacing: 8) {
                ProjectFeatureRow(icon: "brain", text: "Shared memory across chats")
                ProjectFeatureRow(icon: "doc.text", text: "Project-specific context")
                ProjectFeatureRow(icon: "folder.badge.gearshape", text: "Custom settings per project")
            }
            .padding(.vertical, 8)

            Button {
                showCreateProject = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Create your first project")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeColors.accent)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Project Empty State Illustration

struct ProjectEmptyStateIllustration: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background glow
            Circle()
                .fill(ThemeColors.accent.opacity(0.08))
                .frame(width: 80, height: 80)
                .blur(radius: 15)

            // Floating folder icons
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "folder.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(ThemeColors.accent.opacity(0.3))
                    .offset(
                        x: cos(Double(index) * 2.1 + (isAnimating ? 1 : 0)) * 25,
                        y: sin(Double(index) * 2.1 + (isAnimating ? 1 : 0)) * 25
                    )
            }

            // Main icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                ThemeColors.accent.opacity(0.15),
                                ThemeColors.accent.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 24))
                    .foregroundStyle(ThemeColors.accent)
            }
            .scaleEffect(isAnimating ? 1.02 : 1.0)
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Project Feature Row

struct ProjectFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(ThemeColors.accent)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Project Search Empty View

struct ProjectSearchEmptyView: View {
    let query: String
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ThemeColors.darkSurface)
                    .frame(width: 44, height: 44)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(ThemeColors.textMuted)
            }

            VStack(spacing: 4) {
                Text("No matches")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                Text("No projects match \"\(query)\"")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            Button(action: onClear) {
                Text("Clear search")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ThemeColors.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
    }
}

// MARK: - Project Row Item

struct ProjectRowItem: View {
    let name: String
    let iconName: String
    let color: String?
    let isSelected: Bool
    let conversationCount: Int
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon with gradient background
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [iconColor.opacity(0.2), iconColor.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                        .shadow(color: iconColor.opacity(isSelected ? 0.3 : 0), radius: 4, y: 0)

                    Image(systemName: iconName)
                        .font(.system(size: 13))
                        .foregroundStyle(iconColor)
                }

                // Name and count
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text("\(conversationCount) conversation\(conversationCount == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Selection indicator with glow
                if isSelected {
                    Circle()
                        .fill(ThemeColors.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: ThemeColors.accentGlow, radius: 4, y: 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
            // Top highlight for selected state
            .overlay(
                isSelected ?
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ThemeColors.borderHighlight, lineWidth: 0.5)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                : nil
            )
            // Selection border glow
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? ThemeColors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .shadow(color: isSelected ? ThemeColors.selectedGlow : (isHovered ? ThemeColors.shadowLight : .clear), radius: isHovered ? 4 : 0, y: isHovered ? 2 : 0)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .offset(y: isHovered && !isSelected ? -1 : 0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var iconColor: Color {
        if let colorHex = color {
            return Color(hex: colorHex)
        }
        return .secondary
    }

    private var backgroundColor: Color {
        if isSelected {
            return ThemeColors.accent.opacity(0.15)
        } else if isHovered {
            return ThemeColors.hoverBackground.opacity(0.7)
        }
        return .clear
    }
}

// MARK: - Create Project View

struct CreateProjectView: View {
    @Binding var isPresented: Bool
    @ObservedObject var projectManager: ProjectManager
    @State private var projectName = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "00976d"

    let icons = [
        "folder.fill", "doc.text.fill", "chevron.left.forwardslash.chevron.right",
        "cube.fill", "puzzlepiece.fill", "gearshape.fill", "star.fill",
        "bolt.fill", "flame.fill", "leaf.fill", "globe", "building.2.fill"
    ]

    let colors = [
        "00976d", "007AFF", "FF3B30", "FF9500", "FFCC00",
        "34C759", "5856D6", "AF52DE", "FF2D55", "00C7BE"
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("New Project")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Preview
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: selectedColor).opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: selectedIcon)
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: selectedColor))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(projectName.isEmpty ? "Project Name" : projectName)
                        .font(.headline)
                        .foregroundStyle(projectName.isEmpty ? .secondary : .primary)

                    Text("0 conversations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .textBackgroundColor))
            )

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("Enter project name", text: $projectName)
                    .textFieldStyle(.roundedBorder)
            }

            // Icon selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color(hex: selectedColor).opacity(0.2) : Color.clear)
                                    .frame(width: 40, height: 40)

                                Image(systemName: icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColor) : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Color selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { color in
                        Button {
                            selectedColor = color
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 32, height: 32)

                                if selectedColor == color {
                                    Circle()
                                        .stroke(Color.primary.opacity(0.3), lineWidth: 3)
                                        .frame(width: 36, height: 36)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Create Project") {
                    projectManager.createProject(
                        name: projectName,
                        iconName: selectedIcon,
                        color: selectedColor
                    )
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420, height: 520)
    }
}
