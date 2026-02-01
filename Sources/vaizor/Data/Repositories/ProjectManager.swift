import Foundation
import SwiftUI
import GRDB

@MainActor
class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var currentProject: Project?

    private let projectRepository = ProjectRepository()
    private let dbQueue = DatabaseManager.shared.dbQueue

    init() {
        Task {
            await loadProjects()
        }
    }

    // MARK: - Project Loading

    func loadProjects(includeArchived: Bool = false) async {
        let loaded = await projectRepository.loadProjects(includeArchived: includeArchived)
        projects = loaded
    }

    func reloadProjects(includeArchived: Bool = false) async {
        await loadProjects(includeArchived: includeArchived)
    }

    // MARK: - Project CRUD

    @discardableResult
    func createProject(name: String, iconName: String? = "folder.fill", color: String? = "00976d") -> Project {
        let project = Project(
            name: name,
            iconName: iconName,
            color: color
        )

        Task {
            let success = await projectRepository.saveProject(project)
            if success {
                projects.insert(project, at: 0)
            }
        }

        return project
    }

    func deleteProject(_ projectId: UUID) {
        Task {
            let success = await projectRepository.deleteProject(projectId)
            if success {
                projects.removeAll { $0.id == projectId }
                if currentProject?.id == projectId {
                    currentProject = nil
                }
            }
        }
    }

    func archiveProject(_ projectId: UUID, isArchived: Bool) {
        Task {
            let success = await projectRepository.archiveProject(projectId, isArchived: isArchived)
            if success {
                if let index = projects.firstIndex(where: { $0.id == projectId }) {
                    projects[index].isArchived = isArchived
                }
                await reloadProjects()
            }
        }
    }

    func updateProject(_ project: Project) {
        Task {
            var updatedProject = project
            updatedProject.updatedAt = Date()
            let success = await projectRepository.updateProject(updatedProject)
            if success {
                if let index = projects.firstIndex(where: { $0.id == project.id }) {
                    projects[index] = updatedProject
                }
                if currentProject?.id == project.id {
                    currentProject = updatedProject
                }
            }
        }
    }

    func selectProject(_ project: Project?) {
        currentProject = project
    }

    func getProject(by id: UUID) -> Project? {
        return projects.first { $0.id == id }
    }

    // MARK: - Project Name/Settings Updates

    func updateProjectName(_ projectId: UUID, name: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].name = name
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    func updateProjectIcon(_ projectId: UUID, iconName: String?, color: String?) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].iconName = iconName
        projects[index].color = color
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    // MARK: - Context Management

    func updateProjectSystemPrompt(_ projectId: UUID, systemPrompt: String?) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].context.systemPrompt = systemPrompt
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    func addInstruction(_ projectId: UUID, instruction: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].context.instructions.append(instruction)
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    func removeInstruction(_ projectId: UUID, at instructionIndex: Int) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }),
              instructionIndex < projects[index].context.instructions.count else { return }
        projects[index].context.instructions.remove(at: instructionIndex)
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    func updateInstruction(_ projectId: UUID, at instructionIndex: Int, instruction: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }),
              instructionIndex < projects[index].context.instructions.count else { return }
        projects[index].context.instructions[instructionIndex] = instruction
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    // MARK: - Conversation Management

    func addConversationToProject(conversationId: UUID, projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }

        if !projects[index].conversations.contains(conversationId) {
            projects[index].conversations.append(conversationId)
            projects[index].updatedAt = Date()

            Task {
                _ = await projectRepository.addConversationToProject(
                    conversationId: conversationId,
                    projectId: projectId
                )
            }
        }
    }

    func removeConversationFromProject(conversationId: UUID, projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }

        projects[index].conversations.removeAll { $0 == conversationId }
        projects[index].updatedAt = Date()

        Task {
            _ = await projectRepository.removeConversationFromProject(
                conversationId: conversationId,
                projectId: projectId
            )
        }
    }

    func getProjectForConversation(_ conversationId: UUID) -> Project? {
        return projects.first { $0.conversations.contains(conversationId) }
    }

    // MARK: - Memory Management

    func addMemoryEntry(to projectId: UUID, key: String, value: String, source: MemorySource = .user) {
        let entry = MemoryEntry(key: key, value: value, source: source)

        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].context.memory.append(entry)
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    func updateMemoryEntry(_ entryId: UUID, in projectId: UUID, key: String?, value: String?, isActive: Bool?) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let memoryIndex = projects[projectIndex].context.memory.firstIndex(where: { $0.id == entryId }) else { return }

        if let key = key {
            projects[projectIndex].context.memory[memoryIndex].key = key
        }
        if let value = value {
            projects[projectIndex].context.memory[memoryIndex].value = value
        }
        if let isActive = isActive {
            projects[projectIndex].context.memory[memoryIndex].isActive = isActive
        }
        projects[projectIndex].updatedAt = Date()
        updateProject(projects[projectIndex])
    }

    func removeMemoryEntry(_ entryId: UUID, from projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].context.memory.removeAll { $0.id == entryId }
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    func getActiveMemories(for projectId: UUID) -> [MemoryEntry] {
        guard let project = projects.first(where: { $0.id == projectId }) else { return [] }
        return project.context.memory.filter { $0.isActive }
    }

    // MARK: - File Management

    func addFile(to projectId: UUID, file: ProjectFile) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].context.files.append(file)
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    func addFileFromURL(to projectId: UUID, url: URL) {
        guard let data = try? String(contentsOf: url, encoding: .utf8) else {
            AppLogger.shared.log("Failed to read file content from \(url)", level: .error)
            return
        }

        let file = ProjectFile(
            name: url.lastPathComponent,
            path: url.path,
            content: data,
            type: ProjectFile.FileType.from(filename: url.lastPathComponent),
            sizeBytes: data.utf8.count
        )

        addFile(to: projectId, file: file)
    }

    func removeFile(_ fileId: UUID, from projectId: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == projectId }) else { return }
        projects[index].context.files.removeAll { $0.id == fileId }
        projects[index].updatedAt = Date()
        updateProject(projects[index])
    }

    // MARK: - Context Building for LLM

    /// Build the system prompt with project context for the LLM
    func buildSystemPromptWithContext(for projectId: UUID, basePrompt: String?) -> String {
        guard let project = projects.first(where: { $0.id == projectId }) else {
            return basePrompt ?? ""
        }

        var components: [String] = []

        // Add base system prompt if provided
        if let base = basePrompt, !base.isEmpty {
            components.append(base)
        }

        // Add project system prompt
        if let projectPrompt = project.context.systemPrompt, !projectPrompt.isEmpty {
            components.append("\n## Project Context\n\(projectPrompt)")
        }

        // Add custom instructions
        if !project.context.instructions.isEmpty {
            let instructionsList = project.context.instructions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            components.append("\n## Custom Instructions\n\(instructionsList)")
        }

        // Add active memory entries
        let activeMemories = project.context.memory.filter { $0.isActive }
        if !activeMemories.isEmpty {
            let memoryList = activeMemories
                .map { "- \($0.key): \($0.value)" }
                .joined(separator: "\n")
            components.append("\n## Project Memory\nRemember the following about this project:\n\(memoryList)")
        }

        // Add file references
        if !project.context.files.isEmpty {
            let filesList = project.context.files
                .map { "- \($0.name) (\($0.type.rawValue))" }
                .joined(separator: "\n")
            components.append("\n## Reference Files\nThe following files are attached to this project:\n\(filesList)")
        }

        return components.joined(separator: "\n")
    }

    /// Get file contents for injection into conversation
    func getFileContentsForContext(_ projectId: UUID) -> String {
        guard let project = projects.first(where: { $0.id == projectId }) else { return "" }

        var contents: [String] = []
        for file in project.context.files {
            if let content = file.content, !content.isEmpty {
                contents.append("### File: \(file.name)\n```\n\(content)\n```")
            }
        }

        return contents.joined(separator: "\n\n")
    }

    // MARK: - Search

    func searchProjects(query: String) -> [Project] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return projects
        }

        let lowercased = query.lowercased()
        return projects.filter { project in
            project.name.lowercased().contains(lowercased) ||
            project.context.systemPrompt?.lowercased().contains(lowercased) == true ||
            project.context.instructions.contains { $0.lowercased().contains(lowercased) } ||
            project.context.memory.contains { $0.key.lowercased().contains(lowercased) || $0.value.lowercased().contains(lowercased) }
        }
    }
}
