import XCTest
@testable import vaizor

// MARK: - Folder Tests

final class FolderTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let folder = Folder(name: "Test Folder")

        XCTAssertNotNil(folder.id)
        XCTAssertEqual(folder.name, "Test Folder")
        XCTAssertNil(folder.color)
        XCTAssertNil(folder.parentId)
        XCTAssertNotNil(folder.createdAt)
    }

    func testCustomInitialization() {
        let id = UUID()
        let parentId = UUID()
        let createdAt = Date(timeIntervalSince1970: 1000000)

        let folder = Folder(
            id: id,
            name: "Custom Folder",
            color: "FF5733",
            parentId: parentId,
            createdAt: createdAt
        )

        XCTAssertEqual(folder.id, id)
        XCTAssertEqual(folder.name, "Custom Folder")
        XCTAssertEqual(folder.color, "FF5733")
        XCTAssertEqual(folder.parentId, parentId)
        XCTAssertEqual(folder.createdAt, createdAt)
    }

    func testNestedFolderInitialization() {
        let parentId = UUID()
        let childFolder = Folder(
            name: "Child Folder",
            color: "00976d",
            parentId: parentId
        )

        XCTAssertEqual(childFolder.parentId, parentId)
        XCTAssertEqual(childFolder.color, "00976d")
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = Folder(
            name: "Documents",
            color: "5a9bd5",
            parentId: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Folder.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.color, original.color)
        XCTAssertEqual(decoded.parentId, original.parentId)
        XCTAssertEqual(decoded.createdAt, original.createdAt)
    }

    func testEncodeDecodeWithNilOptionals() throws {
        let original = Folder(
            name: "Simple Folder",
            color: nil,
            parentId: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Folder.self, from: data)

        XCTAssertNil(decoded.color)
        XCTAssertNil(decoded.parentId)
    }

    func testEncodeDecodeWithParent() throws {
        let parentId = UUID()
        let original = Folder(
            name: "Nested Folder",
            color: "d4a017",
            parentId: parentId
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Folder.self, from: data)

        XCTAssertEqual(decoded.parentId, parentId)
    }

    func testEncodeDecodePreservesUUID() throws {
        let specificId = UUID(uuidString: "87654321-4321-4321-4321-210987654321")!
        let original = Folder(
            id: specificId,
            name: "UUID Test Folder",
            color: "9c7bea"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Folder.self, from: data)

        XCTAssertEqual(decoded.id, specificId)
    }

    // MARK: - Edge Cases

    func testEmptyName() {
        let folder = Folder(name: "")
        XCTAssertEqual(folder.name, "")
    }

    func testVeryLongName() {
        let longName = String(repeating: "A", count: 1000)
        let folder = Folder(name: longName)
        XCTAssertEqual(folder.name.count, 1000)
    }

    func testUnicodeName() throws {
        let unicodeName = "Folder Projets Test"
        let folder = Folder(name: unicodeName)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(folder)
        let decoded = try decoder.decode(Folder.self, from: data)

        XCTAssertEqual(decoded.name, unicodeName)
    }

    func testSpecialCharactersInName() throws {
        let specialNames = [
            "Folder with \"quotes\"",
            "Folder with 'apostrophes'",
            "Folder with /slashes/",
            "Folder with \\backslashes\\",
            "Folder with \nnewlines",
            "Folder with \ttabs"
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for name in specialNames {
            let folder = Folder(name: name)
            let data = try encoder.encode(folder)
            let decoded = try decoder.decode(Folder.self, from: data)
            XCTAssertEqual(decoded.name, name)
        }
    }

    func testVariousColorFormats() throws {
        let colors = [
            "FF5733",      // Standard hex
            "ff5733",      // Lowercase
            "F53",         // Short form (3 char)
            "00976d",      // Vaizor green
            "5a9bd5",      // Blue
            "d4a017",      // Gold
            "9c7bea",      // Purple
        ]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for color in colors {
            let folder = Folder(name: "Test", color: color)
            let data = try encoder.encode(folder)
            let decoded = try decoder.decode(Folder.self, from: data)
            XCTAssertEqual(decoded.color, color)
        }
    }

    func testDeepNesting() throws {
        // Create a chain of nested folders
        let folder1 = Folder(name: "Level 1")
        let folder2 = Folder(name: "Level 2", parentId: folder1.id)
        let folder3 = Folder(name: "Level 3", parentId: folder2.id)
        let folder4 = Folder(name: "Level 4", parentId: folder3.id)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(folder4)
        let decoded = try decoder.decode(Folder.self, from: data)

        XCTAssertEqual(decoded.parentId, folder3.id)
        XCTAssertNotEqual(folder4.id, folder3.id)
        XCTAssertNotEqual(folder4.id, folder2.id)
        XCTAssertNotEqual(folder4.id, folder1.id)
    }

    func testDatePrecision() throws {
        let preciseDate = Date(timeIntervalSince1970: 1234567890.123456)
        let folder = Folder(
            name: "Precision Test",
            createdAt: preciseDate
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(folder)
        let decoded = try decoder.decode(Folder.self, from: data)

        // Dates should be equal within a small epsilon for JSON encoding
        XCTAssertEqual(
            decoded.createdAt.timeIntervalSince1970,
            preciseDate.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    // MARK: - Mutability Tests

    func testMutableProperties() {
        var folder = Folder(name: "Original Name")

        folder.name = "Updated Name"
        folder.color = "NEWCOLOR"

        XCTAssertEqual(folder.name, "Updated Name")
        XCTAssertEqual(folder.color, "NEWCOLOR")

        // id and createdAt should not be mutable
        // This is a compile-time check, if it compiles, the test passes
        // id is let, so it cannot be changed
        // createdAt is let, so it cannot be changed
    }

    // MARK: - Identifiable Conformance

    func testIdentifiableConformance() {
        let folder1 = Folder(name: "Folder 1")
        let folder2 = Folder(name: "Folder 2")

        XCTAssertNotEqual(folder1.id, folder2.id)
        XCTAssertEqual(folder1.id, folder1.id) // Same instance
    }
}
