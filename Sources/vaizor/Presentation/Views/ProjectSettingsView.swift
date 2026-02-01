import SwiftUI
import UniformTypeIdentifiers

struct ProjectSettingsView: View {
    @Binding var project: Project?
    @Binding var isPresented: Bool
    @ObservedObject var projectManager: ProjectManager
    @State private var selectedTab: SettingsTab = .general
    @State private var editedName: String = ""
    @State private var editedSystemPrompt: String = ""
    @State private var newInstruction: String = ""
    @State private var newMemoryKey: String = ""
    @State private var newMemoryValue: String = ""
    @State private var showFileImporter = false

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case context = "Context"
        case files = "Files"
        case memory = "Memory"
        case instructions = "Instructions"
    }

    var body: some View {
        if let project = project {
            HSplitView {
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack {
                                Image(systemName: iconForTab(tab))
                                    .frame(width: 20)
                                Text(tab.rawValue)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == tab ? ThemeColors.accent.opacity(0.12) : Color.clear)
                            )
                            .foregroundStyle(selectedTab == tab ? ThemeColors.accent : .primary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(12)
                .frame(width: 180)
                .background(Color(nsColor: .controlBackgroundColor))

                // Content
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text(selectedTab.rawValue)
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
                    .padding()

                    Divider()

                    // Tab content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            switch selectedTab {
                            case .general:
                                generalSettingsContent(project: project)
                            case .context:
                                contextSettingsContent(project: project)
                            case .files:
                                filesSettingsContent(project: project)
                            case .memory:
                                memorySettingsContent(project: project)
                            case .instructions:
                                instructionsSettingsContent(project: project)
                            }
                        }
                        .padding()
                    }
                }
            }
            .frame(width: 700, height: 550)
            .onAppear {
                editedName = project.name
                editedSystemPrompt = project.context.systemPrompt ?? ""
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.text, .plainText, .json, .pdf, .image],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result, projectId: project.id)
            }
        }
    }

    private func iconForTab(_ tab: SettingsTab) -> String {
        switch tab {
        case .general: return "gearshape"
        case .context: return "text.quote"
        case .files: return "doc.on.doc"
        case .memory: return "brain"
        case .instructions: return "list.bullet.rectangle"
        }
    }

    // MARK: - General Settings

    @ViewBuilder
    private func generalSettingsContent(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Project name
            VStack(alignment: .leading, spacing: 8) {
                Text("Project Name")
                    .font(.headline)

                HStack {
                    TextField("Project name", text: $editedName)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        projectManager.updateProjectName(project.id, name: editedName)
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Divider()

            // Icon and color
            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.headline)

                HStack(spacing: 20) {
                    // Current icon preview
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: project.color ?? "00976d").opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: project.iconName ?? "folder.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hex: project.color ?? "00976d"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.headline)
                        Text("\(project.conversations.count) conversations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Conversations", value: "\(project.conversations.count)")
                    StatCard(title: "Memory Entries", value: "\(project.context.memory.count)")
                    StatCard(title: "Attached Files", value: "\(project.context.files.count)")
                    StatCard(title: "Instructions", value: "\(project.context.instructions.count)")
                }
            }

            Divider()

            // Danger zone
            VStack(alignment: .leading, spacing: 8) {
                Text("Danger Zone")
                    .font(.headline)
                    .foregroundStyle(.red)

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        projectManager.archiveProject(project.id, isArchived: true)
                        isPresented = false
                    } label: {
                        Label("Archive Project", systemImage: "archivebox")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        projectManager.deleteProject(project.id)
                        isPresented = false
                    } label: {
                        Label("Delete Project", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    // MARK: - Context Settings

    @ViewBuilder
    private func contextSettingsContent(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("System Prompt")
                    .font(.headline)

                Text("This prompt will be prepended to all conversations in this project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $editedSystemPrompt)
                    .font(.system(size: 13, design: .monospaced))
                    .frame(height: 200)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )

                HStack {
                    Spacer()

                    Text("\(editedSystemPrompt.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Save Changes") {
                        projectManager.updateProjectSystemPrompt(project.id, systemPrompt: editedSystemPrompt)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Divider()

            // Preferred model settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Preferred Model")
                    .font(.headline)

                Text("Conversations in this project will default to this model.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Provider: \(project.context.preferredProvider ?? "Default")")
                        .font(.subheadline)

                    Spacer()

                    Text("Model: \(project.context.preferredModel ?? "Default")")
                        .font(.subheadline)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            }
        }
    }

    // MARK: - Files Settings

    @ViewBuilder
    private func filesSettingsContent(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Reference Files")
                    .font(.headline)

                Spacer()

                Button {
                    showFileImporter = true
                } label: {
                    Label("Add Files", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text("Attached files provide context to the AI for all conversations in this project.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if project.context.files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No files attached")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Add reference files like documentation, code samples, or specifications.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(project.context.files) { file in
                        FileRowView(
                            file: file,
                            onDelete: {
                                projectManager.removeFile(file.id, from: project.id)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Memory Settings

    @ViewBuilder
    private func memorySettingsContent(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Project Memory")
                .font(.headline)

            Text("Memory entries are facts the AI will remember across all conversations in this project.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Add new memory
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Memory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("Key (e.g., 'Tech Stack')", text: $newMemoryKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)

                    TextField("Value (e.g., 'React + TypeScript')", text: $newMemoryValue)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        projectManager.addMemoryEntry(
                            to: project.id,
                            key: newMemoryKey,
                            value: newMemoryValue
                        )
                        newMemoryKey = ""
                        newMemoryValue = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newMemoryKey.isEmpty || newMemoryValue.isEmpty)
                }
            }

            Divider()

            // Memory list
            if project.context.memory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "brain")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No memories yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Add key facts about your project that the AI should remember.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(project.context.memory) { entry in
                        MemoryEntryRowView(
                            entry: entry,
                            projectId: project.id,
                            projectManager: projectManager
                        )
                    }
                }
            }
        }
    }

    // MARK: - Instructions Settings

    @ViewBuilder
    private func instructionsSettingsContent(project: Project) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom Instructions")
                .font(.headline)

            Text("Specific instructions that guide the AI's behavior in this project.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Add new instruction
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Instruction")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    TextField("Enter instruction...", text: $newInstruction)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        projectManager.addInstruction(project.id, instruction: newInstruction)
                        newInstruction = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Divider()

            // Instructions list
            if project.context.instructions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No instructions yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Add specific instructions for the AI to follow in this project.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(project.context.instructions.enumerated()), id: \.offset) { index, instruction in
                        InstructionRowView(
                            instruction: instruction,
                            index: index,
                            projectId: project.id,
                            projectManager: projectManager
                        )
                    }
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>, projectId: UUID) {
        switch result {
        case .success(let urls):
            for url in urls {
                projectManager.addFileFromURL(to: projectId, url: url)
            }
        case .failure(let error):
            AppLogger.shared.logError(error, context: "Failed to import files to project")
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(ThemeColors.accent)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
        )
    }
}

struct FileRowView: View {
    let file: ProjectFile
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.type.iconName)
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(file.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let size = file.sizeBytes {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isHovered {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color(nsColor: .textBackgroundColor))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct MemoryEntryRowView: View {
    let entry: MemoryEntry
    let projectId: UUID
    @ObservedObject var projectManager: ProjectManager
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedKey: String = ""
    @State private var editedValue: String = ""

    var body: some View {
        HStack(spacing: 12) {
            // Source indicator
            Image(systemName: entry.source.iconName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if isEditing {
                // Edit mode
                HStack {
                    TextField("Key", text: $editedKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)

                    TextField("Value", text: $editedValue)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        projectManager.updateMemoryEntry(
                            entry.id,
                            in: projectId,
                            key: editedKey,
                            value: editedValue,
                            isActive: nil
                        )
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                }
            } else {
                // View mode
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.key)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(entry.value)
                        .font(.system(size: 13))
                        .lineLimit(2)
                }

                Spacer()

                if isHovered {
                    HStack(spacing: 8) {
                        // Toggle active
                        Button {
                            projectManager.updateMemoryEntry(
                                entry.id,
                                in: projectId,
                                key: nil,
                                value: nil,
                                isActive: !entry.isActive
                            )
                        } label: {
                            Image(systemName: entry.isActive ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(entry.isActive ? ThemeColors.accent : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(entry.isActive ? "Disable memory" : "Enable memory")

                        // Edit
                        Button {
                            editedKey = entry.key
                            editedValue = entry.value
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        // Delete
                        Button {
                            projectManager.removeMemoryEntry(entry.id, from: projectId)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 12))
                }

                // Confidence indicator
                if let confidence = entry.confidence {
                    ConfidenceBadge(confidence: confidence)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(entry.isActive ? Color(nsColor: .textBackgroundColor) : Color.secondary.opacity(0.1))
        )
        .opacity(entry.isActive ? 1.0 : 0.6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(confidenceColor)
            )
    }

    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return ThemeColors.success
        } else if confidence >= 0.6 {
            return ThemeColors.warning
        } else {
            return ThemeColors.error
        }
    }
}

struct InstructionRowView: View {
    let instruction: String
    let index: Int
    let projectId: UUID
    @ObservedObject var projectManager: ProjectManager
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedInstruction: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1).")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            if isEditing {
                HStack {
                    TextField("Instruction", text: $editedInstruction)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        projectManager.updateInstruction(projectId, at: index, instruction: editedInstruction)
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                }
            } else {
                Text(instruction)
                    .font(.system(size: 13))
                    .lineLimit(2)

                Spacer()

                if isHovered {
                    HStack(spacing: 8) {
                        Button {
                            editedInstruction = instruction
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Button {
                            projectManager.removeInstruction(projectId, at: index)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color(nsColor: .textBackgroundColor))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
