import XCTest
import GRDB
@testable import vaizor

// MARK: - ProjectRepository Tests

@MainActor
final class ProjectRepositoryTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var repository: ProjectRepository!

    override func setUp() {
        super.setUp()
        dbQueue = try! DatabaseQueue()
        try! makeMigrator().migrate(dbQueue)

        repository = ProjectRepository(dbQueue: dbQueue)
    }

    override func tearDown() {
        repository = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - Save Project Tests

    func testSaveProject() async {
        let project = Project(
            name: "Test Project",
            conversations: [],
            context: ProjectContext()
        )

        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "Test Project")
    }

    func testSaveProjectWithConversations() async {
        let conversationIds = [UUID(), UUID(), UUID()]
        let project = Project(
            name: "Project with Conversations",
            conversations: conversationIds,
            context: ProjectContext()
        )

        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.conversations.count, 3)
        XCTAssertEqual(loaded?.conversations, conversationIds)
    }

    func testSaveProjectWithContext() async {
        let context = ProjectContext(
            systemPrompt: "You are a coding assistant",
            files: [ProjectFile(name: "test.swift", content: "print('hello')")],
            instructions: ["Follow Swift style guide"],
            mcpServers: [UUID()],
            memory: [MemoryEntry(key: "user_name", value: "John")],
            preferredProvider: "anthropic",
            preferredModel: "claude-3-5-sonnet"
        )

        let project = Project(
            name: "Project with Context",
            conversations: [],
            context: context
        )

        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.context.systemPrompt, "You are a coding assistant")
        XCTAssertEqual(loaded?.context.instructions.count, 1)
        XCTAssertEqual(loaded?.context.memory.count, 1)
        XCTAssertEqual(loaded?.context.preferredProvider, "anthropic")
    }

    // MARK: - Load Projects Tests

    func testLoadProjectsEmpty() async {
        let projects = await repository.loadProjects()
        XCTAssertTrue(projects.isEmpty)
    }

    func testLoadProjects() async {
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")

        await repository.saveProject(project1)
        await repository.saveProject(project2)

        let projects = await repository.loadProjects()
        XCTAssertEqual(projects.count, 2)
    }

    func testLoadProjectsExcludesArchivedByDefault() async {
        let activeProject = Project(name: "Active", isArchived: false)
        let archivedProject = Project(name: "Archived", isArchived: true)

        await repository.saveProject(activeProject)
        await repository.saveProject(archivedProject)

        let projects = await repository.loadProjects(includeArchived: false)
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.name, "Active")
    }

    func testLoadProjectsIncludesArchived() async {
        let activeProject = Project(name: "Active", isArchived: false)
        let archivedProject = Project(name: "Archived", isArchived: true)

        await repository.saveProject(activeProject)
        await repository.saveProject(archivedProject)

        let projects = await repository.loadProjects(includeArchived: true)
        XCTAssertEqual(projects.count, 2)
    }

    func testLoadProjectsOrderedByUpdatedAt() async {
        let project1 = Project(name: "Old", updatedAt: Date(timeIntervalSince1970: 1000))
        let project2 = Project(name: "New", updatedAt: Date(timeIntervalSince1970: 2000))

        await repository.saveProject(project1)
        await repository.saveProject(project2)

        let projects = await repository.loadProjects()
        XCTAssertEqual(projects.count, 2)
        XCTAssertEqual(projects[0].name, "New") // Most recent first
        XCTAssertEqual(projects[1].name, "Old")
    }

    // MARK: - Load Project Tests

    func testLoadProjectById() async {
        let project = Project(name: "Specific Project")
        await repository.saveProject(project)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, project.id)
    }

    func testLoadNonExistentProject() async {
        let fakeId = UUID()
        let loaded = await repository.loadProject(id: fakeId)
        XCTAssertNil(loaded)
    }

    // MARK: - Update Project Tests

    func testUpdateProject() async {
        let project = Project(name: "Original Name")
        await repository.saveProject(project)

        var updated = project
        updated.name = "Updated Name"
        updated.context.systemPrompt = "Updated prompt"
        updated.color = "ff5733"

        let success = await repository.updateProject(updated)
        XCTAssertTrue(success)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.name, "Updated Name")
        XCTAssertEqual(loaded?.context.systemPrompt, "Updated prompt")
        XCTAssertEqual(loaded?.color, "ff5733")
    }

    func testUpdateProjectUpdatesTimestamp() async {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let project = Project(name: "Old", updatedAt: oldDate)
        await repository.saveProject(project)

        var updated = project
        updated.name = "Updated"
        updated.updatedAt = Date()

        await repository.updateProject(updated)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertGreaterThan(loaded!.updatedAt.timeIntervalSince1970, oldDate.timeIntervalSince1970)
    }

    // MARK: - Delete Project Tests

    func testDeleteProject() async {
        let project = Project(name: "To Delete")
        await repository.saveProject(project)

        var projects = await repository.loadProjects()
        XCTAssertEqual(projects.count, 1)

        let deleted = await repository.deleteProject(project.id)
        XCTAssertTrue(deleted)

        projects = await repository.loadProjects()
        XCTAssertTrue(projects.isEmpty)
    }

    func testDeleteProjectClearsConversationAssociations() async {
        let project = Project(name: "With Conversations")
        await repository.saveProject(project)

        // Create a conversation with project association
        let conversationId = UUID()
        try? await dbQueue.write { db in
            try db.execute(sql: """
                INSERT INTO conversations (id, title, summary, created_at, last_used_at, message_count, is_archived, is_favorite, project_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, arguments: [
                conversationId.uuidString,
                "Test Conversation",
                "",
                Date().timeIntervalSince1970,
                Date().timeIntervalSince1970,
                0,
                false,
                false,
                project.id.uuidString
            ])
        }

        // Verify association exists
        let hasAssociation: Bool? = try? await dbQueue.read { db in
            try Bool.fetchOne(db, sql: "SELECT project_id IS NOT NULL FROM conversations WHERE id = ?", arguments: [conversationId.uuidString])
        }
        XCTAssertEqual(hasAssociation, true)

        // Delete project
        await repository.deleteProject(project.id)

        // Verify association is cleared
        let projectIdAfter: String? = try? await dbQueue.read { db in
            try String.fetchOne(db, sql: "SELECT project_id FROM conversations WHERE id = ?", arguments: [conversationId.uuidString])
        }
        XCTAssertNil(projectIdAfter)
    }

    func testDeleteNonExistentProject() async {
        let fakeId = UUID()
        let deleted = await repository.deleteProject(fakeId)
        XCTAssertTrue(deleted)
    }

    // MARK: - Archive Project Tests

    func testArchiveProject() async {
        let project = Project(name: "To Archive", isArchived: false)
        await repository.saveProject(project)

        let archived = await repository.archiveProject(project.id, isArchived: true)
        XCTAssertTrue(archived)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.isArchived, true)
    }

    func testUnarchiveProject() async {
        let project = Project(name: "To Unarchive", isArchived: true)
        await repository.saveProject(project)

        let archived = await repository.archiveProject(project.id, isArchived: false)
        XCTAssertTrue(archived)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.isArchived, false)
    }

    func testArchiveNonExistentProject() async {
        let fakeId = UUID()
        let archived = await repository.archiveProject(fakeId, isArchived: true)
        XCTAssertTrue(archived)
    }

    // MARK: - Conversation Management Tests

    func testAddConversationToProject() async {
        let project = Project(name: "Test Project", conversations: [])
        await repository.saveProject(project)

        let conversationId = UUID()
        let added = await repository.addConversationToProject(conversationId: conversationId, projectId: project.id)
        XCTAssertTrue(added)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertTrue(loaded?.conversations.contains(conversationId) ?? false)
    }

    func testAddDuplicateConversation() async {
        let conversationId = UUID()
        let project = Project(name: "Test", conversations: [conversationId])
        await repository.saveProject(project)

        // Try to add again
        let added = await repository.addConversationToProject(conversationId: conversationId, projectId: project.id)
        XCTAssertTrue(added)

        // Should not duplicate
        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.conversations.filter { $0 == conversationId }.count, 1)
    }

    func testRemoveConversationFromProject() async {
        let conversationId = UUID()
        let project = Project(name: "Test", conversations: [conversationId])
        await repository.saveProject(project)

        let removed = await repository.removeConversationFromProject(conversationId: conversationId, projectId: project.id)
        XCTAssertTrue(removed)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertFalse(loaded?.conversations.contains(conversationId) ?? true)
    }

    func testGetConversationsForProject() async {
        let conversationIds = [UUID(), UUID()]
        let project = Project(name: "Test", conversations: conversationIds)
        await repository.saveProject(project)

        let retrieved = await repository.getConversationsForProject(project.id)
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved, conversationIds)
    }

    // MARK: - Memory Management Tests

    func testAddMemoryEntry() async {
        let project = Project(name: "Test")
        await repository.saveProject(project)

        let entry = MemoryEntry(key: "user_name", value: "John", source: .user)
        let added = await repository.addMemoryEntry(entry, to: project.id)
        XCTAssertTrue(added)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.context.memory.count, 1)
        XCTAssertEqual(loaded?.context.memory.first?.key, "user_name")
    }

    func testUpdateMemoryEntry() async {
        let entry = MemoryEntry(key: "user_name", value: "John", source: .user)
        let project = Project(name: "Test", context: ProjectContext(memory: [entry]))
        await repository.saveProject(project)

        var updatedEntry = entry
        updatedEntry.value = "Jane"

        let updated = await repository.updateMemoryEntry(updatedEntry, in: project.id)
        XCTAssertTrue(updated)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.context.memory.first?.value, "Jane")
    }

    func testRemoveMemoryEntry() async {
        let entry = MemoryEntry(key: "temp", value: "value", source: .auto)
        let project = Project(name: "Test", context: ProjectContext(memory: [entry]))
        await repository.saveProject(project)

        let removed = await repository.removeMemoryEntry(entry.id, from: project.id)
        XCTAssertTrue(removed)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertTrue(loaded?.context.memory.isEmpty ?? false)
    }

    func testGetActiveMemories() async {
        let activeEntry = MemoryEntry(key: "active", value: "yes", source: .user, isActive: true)
        let inactiveEntry = MemoryEntry(key: "inactive", value: "no", source: .auto, isActive: false)
        let project = Project(name: "Test", context: ProjectContext(memory: [activeEntry, inactiveEntry]))
        await repository.saveProject(project)

        let active = await repository.getActiveMemories(for: project.id)
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.key, "active")
    }

    // MARK: - File Management Tests

    func testAddFile() async {
        let project = Project(name: "Test")
        await repository.saveProject(project)

        let file = ProjectFile(name: "test.swift", content: "print('hello')", type: .code)
        let added = await repository.addFile(file, to: project.id)
        XCTAssertTrue(added)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.context.files.count, 1)
        XCTAssertEqual(loaded?.context.files.first?.name, "test.swift")
    }

    func testRemoveFile() async {
        let file = ProjectFile(name: "temp.txt", content: "temp", type: .text)
        let project = Project(name: "Test", context: ProjectContext(files: [file]))
        await repository.saveProject(project)

        let removed = await repository.removeFile(file.id, from: project.id)
        XCTAssertTrue(removed)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertTrue(loaded?.context.files.isEmpty ?? false)
    }

    // MARK: - Context Management Tests

    func testUpdateProjectContext() async {
        let project = Project(name: "Test")
        await repository.saveProject(project)

        let newContext = ProjectContext(
            systemPrompt: "New prompt",
            files: [],
            instructions: ["New instruction"],
            preferredProvider: "openai",
            preferredModel: "gpt-4"
        )

        let updated = await repository.updateProjectContext(newContext, for: project.id)
        XCTAssertTrue(updated)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.context.systemPrompt, "New prompt")
        XCTAssertEqual(loaded?.context.preferredProvider, "openai")
    }

    func testGetProjectContext() async {
        let context = ProjectContext(
            systemPrompt: "Test prompt",
            instructions: ["Instruction 1"]
        )
        let project = Project(name: "Test", context: context)
        await repository.saveProject(project)

        let retrieved = await repository.getProjectContext(for: project.id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.systemPrompt, "Test prompt")
    }

    // MARK: - Search Tests

    func testSearchProjects() async {
        let project1 = Project(name: "Swift Development")
        let project2 = Project(name: "Python Scripts")
        let project3 = Project(name: "JavaScript Frontend")

        await repository.saveProject(project1)
        await repository.saveProject(project2)
        await repository.saveProject(project3)

        let results = await repository.searchProjects(query: "swift")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Swift Development")
    }

    func testSearchProjectsCaseInsensitive() async {
        let project = Project(name: "SWIFT PROJECT")
        await repository.saveProject(project)

        let results = await repository.searchProjects(query: "swift")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchProjectsPartialMatch() async {
        let project = Project(name: "My Swift Application")
        await repository.saveProject(project)

        let results = await repository.searchProjects(query: "swift")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchProjectsEmptyQuery() async {
        let project1 = Project(name: "Project 1")
        let project2 = Project(name: "Project 2")

        await repository.saveProject(project1)
        await repository.saveProject(project2)

        let results = await repository.searchProjects(query: "")
        XCTAssertEqual(results.count, 2)
    }

    func testSearchProjectsNoResults() async {
        let project = Project(name: "Swift Project")
        await repository.saveProject(project)

        let results = await repository.searchProjects(query: "python")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchExcludesArchived() async {
        let active = Project(name: "Active Project", isArchived: false)
        let archived = Project(name: "Archived Project", isArchived: true)

        await repository.saveProject(active)
        await repository.saveProject(archived)

        let results = await repository.searchProjects(query: "project")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.isArchived, false)
    }

    // MARK: - Edge Cases

    func testSaveProjectWithEmptyName() async {
        let project = Project(name: "")
        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.name, "")
    }

    func testSaveProjectWithVeryLongName() async {
        let longName = String(repeating: "A", count: 1000)
        let project = Project(name: longName)

        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.name.count, 1000)
    }

    func testSaveProjectWithUnicode() async {
        let project = Project(
            name: "  ",
            iconName: "folder.fill",
            color: "ff5733"
        )

        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.name, "  ")
    }

    func testSaveManyProjects() async {
        let count = 50
        for i in 0..<count {
            let project = Project(name: "Project \(i)")
            let saved = await repository.saveProject(project)
            XCTAssertTrue(saved)
        }

        let projects = await repository.loadProjects()
        XCTAssertEqual(projects.count, count)
    }

    func testProjectTimestamps() async {
        let specificDate = Date(timeIntervalSince1970: 1234567890)
        let project = Project(
            name: "Timestamp Test",
            createdAt: specificDate,
            updatedAt: specificDate
        )

        await repository.saveProject(project)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.createdAt.timeIntervalSince1970 ?? 0, specificDate.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(loaded?.updatedAt.timeIntervalSince1970 ?? 0, specificDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testDefaultProjectProperties() async {
        let project = Project(name: "Defaults Test")
        await repository.saveProject(project)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.iconName, "folder.fill") // Default value
        XCTAssertEqual(loaded?.color, "00976d") // Default value
        XCTAssertFalse(loaded?.isArchived ?? true)
    }

    func testProjectWithManyConversations() async {
        var conversationIds: [UUID] = []
        for _ in 0..<100 {
            conversationIds.append(UUID())
        }

        let project = Project(name: "Many Conversations", conversations: conversationIds)
        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.conversations.count, 100)
    }

    func testProjectWithManyFiles() async {
        var files: [ProjectFile] = []
        for i in 0..<50 {
            files.append(ProjectFile(name: "file\(i).swift", content: "code"))
        }

        let context = ProjectContext(files: files)
        let project = Project(name: "Many Files", context: context)
        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.context.files.count, 50)
    }

    func testProjectWithManyMemories() async {
        var memories: [MemoryEntry] = []
        for i in 0..<50 {
            memories.append(MemoryEntry(key: "key\(i)", value: "value\(i)"))
        }

        let context = ProjectContext(memory: memories)
        let project = Project(name: "Many Memories", context: context)
        let saved = await repository.saveProject(project)
        XCTAssertTrue(saved)

        let loaded = await repository.loadProject(id: project.id)
        XCTAssertEqual(loaded?.context.memory.count, 50)
    }
}
