import XCTest
import GRDB
@testable import vaizor

// MARK: - FolderRepository Tests

@MainActor
final class FolderRepositoryTests: XCTestCase {

    var dbQueue: DatabaseQueue!
    var repository: FolderRepository!

    override func setUp() {
        super.setUp()
        dbQueue = try! DatabaseQueue()
        try! makeMigrator().migrate(dbQueue)

        repository = FolderRepository(dbQueue: dbQueue)
    }

    override func tearDown() {
        repository = nil
        dbQueue = nil
        super.tearDown()
    }

    // MARK: - Save Folder Tests

    func testSaveFolder() async {
        let folder = Folder(
            name: "Test Folder",
            color: "5a9bd5"
        )

        let saved = await repository.saveFolder(folder)
        XCTAssertTrue(saved)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "Test Folder")
        XCTAssertEqual(folders.first?.color, "5a9bd5")
    }

    func testSaveFolderWithoutColor() async {
        let folder = Folder(
            name: "No Color Folder",
            color: nil
        )

        let saved = await repository.saveFolder(folder)
        XCTAssertTrue(saved)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.first?.color, nil)
    }

    func testSaveFolderWithParent() async {
        let parentFolder = Folder(name: "Parent")
        let saved = await repository.saveFolder(parentFolder)
        XCTAssertTrue(saved)

        let childFolder = Folder(
            name: "Child",
            color: "d4a017",
            parentId: parentFolder.id
        )

        let childSaved = await repository.saveFolder(childFolder)
        XCTAssertTrue(childSaved)

        let folders = await repository.loadFolders()
        let child = folders.first { $0.id == childFolder.id }
        XCTAssertEqual(child?.parentId, parentFolder.id)
    }

    // MARK: - Load Folders Tests

    func testLoadFoldersEmpty() async {
        let folders = await repository.loadFolders()
        XCTAssertTrue(folders.isEmpty)
    }

    func testLoadFoldersOrdered() async {
        let folderA = Folder(name: "Alpha Folder")
        let folderB = Folder(name: "Beta Folder")
        let folderC = Folder(name: "Charlie Folder")

        await repository.saveFolder(folderC)
        await repository.saveFolder(folderA)
        await repository.saveFolder(folderB)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.count, 3)
        // Should be ordered alphabetically by name
        XCTAssertEqual(folders[0].name, "Alpha Folder")
        XCTAssertEqual(folders[1].name, "Beta Folder")
        XCTAssertEqual(folders[2].name, "Charlie Folder")
    }

    func testLoadFoldersWithSpecialCharacters() async {
        let folders = [
            Folder(name: "Folder 1"),
            Folder(name: "Folder with Emoji "),
            Folder(name: "Folder with Spaces"),
            Folder(name: "UPPERCASE"),
            Folder(name: "lowercase")
        ]

        for folder in folders {
            await repository.saveFolder(folder)
        }

        let loaded = await repository.loadFolders()
        XCTAssertEqual(loaded.count, 5)
    }

    // MARK: - Update Folder Tests

    func testUpdateFolder() async {
        let folder = Folder(name: "Original Name")
        await repository.saveFolder(folder)

        var updated = folder
        updated.name = "Updated Name"
        updated.color = "ff5733"

        await repository.updateFolder(updated)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders.first?.name, "Updated Name")
        XCTAssertEqual(folders.first?.color, "ff5733")
    }

    func testUpdateNonExistentFolder() async {
        let folder = Folder(
            id: UUID(),
            name: "Non-existent",
            color: "000000"
        )

        // Should not throw
        await repository.updateFolder(folder)

        // Folder should now exist (upsert behavior)
        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.count, 1)
    }

    // MARK: - Delete Folder Tests

    func testDeleteFolder() async {
        let folder = Folder(name: "To Delete")
        await repository.saveFolder(folder)

        var folders = await repository.loadFolders()
        XCTAssertEqual(folders.count, 1)

        let deleted = await repository.deleteFolder(folder.id)
        XCTAssertTrue(deleted)

        folders = await repository.loadFolders()
        XCTAssertTrue(folders.isEmpty)
    }

    func testDeleteNonExistentFolder() async {
        let fakeId = UUID()
        let deleted = await repository.deleteFolder(fakeId)
        XCTAssertTrue(deleted) // Returns true even if nothing was deleted
    }

    // MARK: - Multiple Folder Tests

    func testSaveMultipleFolders() async {
        let count = 100
        for i in 0..<count {
            let folder = Folder(name: "Folder \(i)")
            let saved = await repository.saveFolder(folder)
            XCTAssertTrue(saved)
        }

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.count, count)
    }

    func testSaveAndDeleteMultiple() async {
        var savedFolders: [Folder] = []

        for i in 0..<10 {
            let folder = Folder(name: "Folder \(i)")
            await repository.saveFolder(folder)
            savedFolders.append(folder)
        }

        // Delete half
        for i in 0..<5 {
            await repository.deleteFolder(savedFolders[i].id)
        }

        let remaining = await repository.loadFolders()
        XCTAssertEqual(remaining.count, 5)
    }

    // MARK: - Edge Cases

    func testSaveFolderWithEmptyName() async {
        let folder = Folder(name: "")
        let saved = await repository.saveFolder(folder)
        XCTAssertTrue(saved)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.first?.name, "")
    }

    func testSaveFolderWithVeryLongName() async {
        let longName = String(repeating: "A", count: 1000)
        let folder = Folder(name: longName)

        let saved = await repository.saveFolder(folder)
        XCTAssertTrue(saved)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.first?.name.count, 1000)
    }

    func testSaveFolderWithUnicodeName() async {
        let folder = Folder(name: "  ")
        let saved = await repository.saveFolder(folder)
        XCTAssertTrue(saved)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.first?.name, "  ")
    }

    func testNestedFolders() async {
        // Create a hierarchy: Grandparent -> Parent -> Child
        let grandparent = Folder(name: "Grandparent")
        await repository.saveFolder(grandparent)

        let parent = Folder(name: "Parent", parentId: grandparent.id)
        await repository.saveFolder(parent)

        let child = Folder(name: "Child", parentId: parent.id)
        await repository.saveFolder(child)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.count, 3)

        let childFolder = folders.first { $0.name == "Child" }
        XCTAssertEqual(childFolder?.parentId, parent.id)
    }

    func testUpdateFolderPreservesId() async {
        let originalId = UUID()
        let folder = Folder(
            id: originalId,
            name: "Original",
            color: "000000"
        )

        await repository.saveFolder(folder)

        var updated = folder
        updated.name = "Updated"
        await repository.updateFolder(updated)

        let folders = await repository.loadFolders()
        XCTAssertEqual(folders.first?.id, originalId)
    }

    func testFolderTimestampsPreserved() async {
        let specificDate = Date(timeIntervalSince1970: 1234567890)
        let folder = Folder(
            name: "Timestamp Test",
            createdAt: specificDate
        )

        await repository.saveFolder(folder)

        let folders = await repository.loadFolders()
        // Compare timestamps with some tolerance for database precision
        let loadedDate = folders.first?.createdAt
        XCTAssertEqual(loadedDate?.timeIntervalSince1970 ?? 0, specificDate.timeIntervalSince1970, accuracy: 1.0)
    }

    func testDeleteFolderWithChildren() async {
        let parent = Folder(name: "Parent")
        await repository.saveFolder(parent)

        let child1 = Folder(name: "Child 1", parentId: parent.id)
        let child2 = Folder(name: "Child 2", parentId: parent.id)
        await repository.saveFolder(child1)
        await repository.saveFolder(child2)

        // Delete parent
        await repository.deleteFolder(parent.id)

        // Note: This test verifies the folder is deleted, but doesn't test cascading
        // In a real app, you might need to handle child folders specially
        let folders = await repository.loadFolders()
        XCTAssertFalse(folders.contains { $0.id == parent.id })
    }
}
