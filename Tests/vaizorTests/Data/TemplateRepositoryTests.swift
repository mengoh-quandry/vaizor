import XCTest
import GRDB
@testable import vaizor

// MARK: - TemplateRepository Tests

@MainActor
final class TemplateRepositoryTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var repository: TemplateRepository!

    override func setUp() {
        super.setUp()
        dbQueue = try! DatabaseQueue()
        try! makeMigrator().migrate(dbQueue)

        repository = TemplateRepository(dbQueue: dbQueue)
    }

    override func tearDown() {
        repository = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - Save Template Tests

    func testSaveTemplate() async {
        let template = ConversationTemplate(
            name: "Test Template",
            prompt: "This is a test prompt",
            systemPrompt: "You are a test assistant"
        )

        let saved = await repository.saveTemplate(template)
        XCTAssertTrue(saved)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "Test Template")
        XCTAssertEqual(templates.first?.prompt, "This is a test prompt")
        XCTAssertEqual(templates.first?.systemPrompt, "You are a test assistant")
    }

    func testSaveTemplateWithoutSystemPrompt() async {
        let template = ConversationTemplate(
            name: "No System Prompt",
            prompt: "Simple prompt",
            systemPrompt: nil
        )

        let saved = await repository.saveTemplate(template)
        XCTAssertTrue(saved)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.first?.systemPrompt, nil)
    }

    func testSaveMultipleTemplates() async {
        let templates = [
            ConversationTemplate(name: "Template 1", prompt: "Prompt 1"),
            ConversationTemplate(name: "Template 2", prompt: "Prompt 2"),
            ConversationTemplate(name: "Template 3", prompt: "Prompt 3")
        ]

        for template in templates {
            let saved = await repository.saveTemplate(template)
            XCTAssertTrue(saved)
        }

        let loaded = await repository.loadTemplates()
        XCTAssertEqual(loaded.count, 3)
    }

    // MARK: - Load Templates Tests

    func testLoadTemplatesEmpty() async {
        let templates = await repository.loadTemplates()
        XCTAssertTrue(templates.isEmpty)
    }

    func testLoadTemplatesOrdered() async {
        let templateA = ConversationTemplate(name: "Zebra Template", prompt: "Z")
        let templateB = ConversationTemplate(name: "Apple Template", prompt: "A")
        let templateC = ConversationTemplate(name: "Mango Template", prompt: "M")

        await repository.saveTemplate(templateA)
        await repository.saveTemplate(templateB)
        await repository.saveTemplate(templateC)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.count, 3)
        // Should be ordered alphabetically by name
        XCTAssertEqual(templates[0].name, "Apple Template")
        XCTAssertEqual(templates[1].name, "Mango Template")
        XCTAssertEqual(templates[2].name, "Zebra Template")
    }

    // MARK: - Update Template Tests

    func testUpdateTemplate() async {
        let template = ConversationTemplate(
            name: "Original",
            prompt: "Original prompt",
            systemPrompt: "Original system"
        )

        await repository.saveTemplate(template)

        var updated = template
        updated.name = "Updated"
        updated.prompt = "Updated prompt"
        updated.systemPrompt = "Updated system"

        await repository.updateTemplate(updated)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.count, 1)
        XCTAssertEqual(templates.first?.name, "Updated")
        XCTAssertEqual(templates.first?.prompt, "Updated prompt")
        XCTAssertEqual(templates.first?.systemPrompt, "Updated system")
    }

    func testUpdateNonExistentTemplate() async {
        let template = ConversationTemplate(
            id: UUID(),
            name: "Non-existent",
            prompt: "Test"
        )

        // Should not throw (upsert behavior)
        await repository.updateTemplate(template)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.count, 1)
    }

    // MARK: - Delete Template Tests

    func testDeleteTemplate() async {
        let template = ConversationTemplate(name: "To Delete", prompt: "Delete me")
        await repository.saveTemplate(template)

        var templates = await repository.loadTemplates()
        XCTAssertEqual(templates.count, 1)

        let deleted = await repository.deleteTemplate(template.id)
        XCTAssertTrue(deleted)

        templates = await repository.loadTemplates()
        XCTAssertTrue(templates.isEmpty)
    }

    func testDeleteNonExistentTemplate() async {
        let fakeId = UUID()
        let deleted = await repository.deleteTemplate(fakeId)
        XCTAssertTrue(deleted) // Returns true even if nothing was deleted
    }

    // MARK: - Edge Cases

    func testSaveTemplateWithEmptyName() async {
        let template = ConversationTemplate(name: "", prompt: "Has prompt")
        let saved = await repository.saveTemplate(template)
        XCTAssertTrue(saved)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.first?.name, "")
    }

    func testSaveTemplateWithEmptyPrompt() async {
        let template = ConversationTemplate(name: "No Prompt", prompt: "")
        let saved = await repository.saveTemplate(template)
        XCTAssertTrue(saved)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.first?.prompt, "")
    }

    func testSaveTemplateWithVeryLongContent() async {
        let longPrompt = String(repeating: "Lorem ipsum ", count: 1000)
        let longSystemPrompt = String(repeating: "System ", count: 500)

        let template = ConversationTemplate(
            name: "Long Content",
            prompt: longPrompt,
            systemPrompt: longSystemPrompt
        )

        let saved = await repository.saveTemplate(template)
        XCTAssertTrue(saved)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.first?.prompt.count, longPrompt.count)
        XCTAssertEqual(templates.first?.systemPrompt?.count, longSystemPrompt.count)
    }

    func testSaveTemplateWithUnicode() async {
        let template = ConversationTemplate(
            name: "  ",
            prompt: "Hello  World",
            systemPrompt: "Assistant  Mode"
        )

        let saved = await repository.saveTemplate(template)
        XCTAssertTrue(saved)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.first?.name, "  ")
        XCTAssertEqual(templates.first?.prompt, "Hello  World")
    }

    func testSaveTemplateWithSpecialCharacters() async {
        let template = ConversationTemplate(
            name: "Template with \"quotes\"",
            prompt: "Prompt with 'apostrophes' and \\backslashes\\",
            systemPrompt: "System with\nnewlines\tand\ttabs"
        )

        let saved = await repository.saveTemplate(template)
        XCTAssertTrue(saved)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.first?.name, "Template with \"quotes\"")
        XCTAssertEqual(templates.first?.prompt, "Prompt with 'apostrophes' and \\backslashes\\")
    }

    func testTemplateTimestamps() async {
        let specificDate = Date(timeIntervalSince1970: 1234567890)
        let template = ConversationTemplate(
            id: UUID(),
            name: "Timestamp Test",
            prompt: "Test",
            systemPrompt: nil,
            createdAt: specificDate
        )

        await repository.saveTemplate(template)

        let templates = await repository.loadTemplates()
        let loadedDate = templates.first?.createdAt
        XCTAssertEqual(loadedDate?.timeIntervalSince1970 ?? 0, specificDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testDuplicateTemplateNames() async {
        // Templates can have duplicate names
        let template1 = ConversationTemplate(name: "Duplicate", prompt: "First")
        let template2 = ConversationTemplate(name: "Duplicate", prompt: "Second")

        await repository.saveTemplate(template1)
        await repository.saveTemplate(template2)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.count, 2)
        XCTAssertEqual(templates.filter { $0.name == "Duplicate" }.count, 2)
    }

    func testTemplateIdPreservation() async {
        let specificId = UUID()
        let template = ConversationTemplate(
            id: specificId,
            name: "ID Test",
            prompt: "Test"
        )

        await repository.saveTemplate(template)

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.first?.id, specificId)
    }

    func testLoadManyTemplates() async {
        let count = 100
        for i in 0..<count {
            let template = ConversationTemplate(
                name: "Template \(i)",
                prompt: "Prompt \(i)"
            )
            await repository.saveTemplate(template)
        }

        let templates = await repository.loadTemplates()
        XCTAssertEqual(templates.count, count)
    }
}
