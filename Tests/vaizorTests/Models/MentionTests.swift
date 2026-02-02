import XCTest
@testable import vaizor

// MARK: - Mention Tests

final class MentionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let mention = Mention(
            type: .file,
            value: "/path/to/file.txt"
        )

        XCTAssertNotNil(mention.id)
        XCTAssertEqual(mention.type, .file)
        XCTAssertEqual(mention.value, "/path/to/file.txt")
        XCTAssertEqual(mention.displayName, "file.txt") // Extracted from path
        XCTAssertNil(mention.resolvedContent)
        XCTAssertNil(mention.tokenCount)
        XCTAssertNil(mention.range)
    }

    func testCustomInitialization() {
        let id = UUID()
        let range = "test".startIndex..<"test".endIndex

        let mention = Mention(
            id: id,
            type: .url,
            value: "https://example.com",
            displayName: "example.com",
            resolvedContent: "Example content",
            tokenCount: 42,
            range: range
        )

        XCTAssertEqual(mention.id, id)
        XCTAssertEqual(mention.type, .url)
        XCTAssertEqual(mention.value, "https://example.com")
        XCTAssertEqual(mention.displayName, "example.com")
        XCTAssertEqual(mention.resolvedContent, "Example content")
        XCTAssertEqual(mention.tokenCount, 42)
        XCTAssertNotNil(mention.range)
    }

    // MARK: - Display Name Extraction Tests

    func testFileDisplayNameExtraction() {
        let mention1 = Mention(type: .file, value: "/Users/test/Documents/file.txt")
        XCTAssertEqual(mention1.displayName, "file.txt")

        let mention2 = Mention(type: .file, value: "file.txt")
        XCTAssertEqual(mention2.displayName, "file.txt")

        let mention3 = Mention(type: .file, value: "/path/to/my-file.swift")
        XCTAssertEqual(mention3.displayName, "my-file.swift")
    }

    func testFolderDisplayNameExtraction() {
        let mention1 = Mention(type: .folder, value: "/Users/test/Documents")
        XCTAssertEqual(mention1.displayName, "Documents")

        let mention2 = Mention(type: .folder, value: "/path/to/my folder/")
        // Last path component might be empty for trailing slash
        let displayName = mention2.displayName
        XCTAssertTrue(displayName == "my folder" || displayName == "/path/to/my folder/")
    }

    func testURLDisplayNameExtraction() {
        let mention1 = Mention(type: .url, value: "https://example.com/path")
        XCTAssertEqual(mention1.displayName, "example.com")

        let mention2 = Mention(type: .url, value: "http://test.org/page")
        XCTAssertEqual(mention2.displayName, "test.org")

        let mention3 = Mention(type: .url, value: "invalid-url")
        XCTAssertEqual(mention3.displayName, "invalid-url")
    }

    func testProjectDisplayNameExtraction() {
        let mention = Mention(type: .project, value: "MyAwesomeProject")
        XCTAssertEqual(mention.displayName, "MyAwesomeProject")
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = Mention(
            type: .file,
            value: "/test/path.swift",
            displayName: "path.swift",
            resolvedContent: "Swift code content",
            tokenCount: 100
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Mention.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.value, original.value)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.resolvedContent, original.resolvedContent)
        XCTAssertEqual(decoded.tokenCount, original.tokenCount)
        XCTAssertNil(decoded.range) // Range is always nil after decoding
    }

    func testEncodeDecodeWithNilOptionals() throws {
        let original = Mention(
            type: .url,
            value: "https://example.com",
            resolvedContent: nil,
            tokenCount: nil
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Mention.self, from: data)

        XCTAssertNil(decoded.resolvedContent)
        XCTAssertNil(decoded.tokenCount)
    }

    func testEncodeDecodeAllTypes() throws {
        let types: [MentionType] = [.file, .folder, .url, .project]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in types {
            let mention = Mention(type: type, value: "test-value")
            let data = try encoder.encode(mention)
            let decoded = try decoder.decode(Mention.self, from: data)
            XCTAssertEqual(decoded.type, type)
        }
    }

    // MARK: - Full Mention String Tests

    func testFullMentionString() {
        let fileMention = Mention(type: .file, value: "/path/to/file.txt")
        XCTAssertEqual(fileMention.fullMentionString, "@file:/path/to/file.txt")

        let folderMention = Mention(type: .folder, value: "/Users/docs")
        XCTAssertEqual(folderMention.fullMentionString, "@folder:/Users/docs")

        let urlMention = Mention(type: .url, value: "https://example.com")
        XCTAssertEqual(urlMention.fullMentionString, "@url:https://example.com")

        let projectMention = Mention(type: .project, value: "MyProject")
        XCTAssertEqual(projectMention.fullMentionString, "@project:MyProject")
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let id = UUID()
        let mention1 = Mention(id: id, type: .file, value: "path")
        let mention2 = Mention(id: id, type: .file, value: "path")

        XCTAssertEqual(mention1, mention2)
    }

    func testInequalityDifferentId() {
        let mention1 = Mention(type: .file, value: "path")
        let mention2 = Mention(type: .file, value: "path")

        XCTAssertNotEqual(mention1, mention2) // Different UUIDs
    }

    func testInequalitySameIdDifferentValues() {
        let id = UUID()
        let mention1 = Mention(id: id, type: .file, value: "path1")
        let mention2 = Mention(id: id, type: .file, value: "path2")

        // Equality is only based on ID
        XCTAssertEqual(mention1, mention2)
    }

    // MARK: - Edge Cases

    func testEmptyValue() {
        let mention = Mention(type: .file, value: "")
        XCTAssertEqual(mention.value, "")
        // URL(fileURLWithPath: "").lastPathComponent returns current directory name
        // which is expected behavior for an empty path
        XCTAssertFalse(mention.displayName.isEmpty)
    }

    func testVeryLongValue() {
        let longValue = String(repeating: "/path", count: 1000)
        let mention = Mention(type: .folder, value: longValue)
        XCTAssertEqual(mention.value.count, longValue.count)
    }

    func testUnicodeInValue() throws {
        let unicodePath = "/Users/test/  /"
        let mention = Mention(type: .file, value: unicodePath)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(mention)
        let decoded = try decoder.decode(Mention.self, from: data)

        XCTAssertEqual(decoded.value, unicodePath)
    }

    func testCustomDisplayName() {
        let mention = Mention(
            type: .file,
            value: "/very/long/path/to/the/file.txt",
            displayName: "Short Name"
        )

        XCTAssertEqual(mention.displayName, "Short Name")
    }

    func testZeroTokenCount() {
        let mention = Mention(
            type: .file,
            value: "path",
            tokenCount: 0
        )

        XCTAssertEqual(mention.tokenCount, 0)
    }

    func testLargeTokenCount() {
        let mention = Mention(
            type: .file,
            value: "path",
            tokenCount: 1000000
        )

        XCTAssertEqual(mention.tokenCount, 1000000)
    }
}

// MARK: - MentionType Tests

final class MentionTypeTests: XCTestCase {

    func testAllCases() {
        let allTypes = MentionType.allCases
        XCTAssertEqual(allTypes.count, 4)
        XCTAssertTrue(allTypes.contains(.file))
        XCTAssertTrue(allTypes.contains(.folder))
        XCTAssertTrue(allTypes.contains(.url))
        XCTAssertTrue(allTypes.contains(.project))
    }

    func testPrefixes() {
        XCTAssertEqual(MentionType.file.prefix, "@file:")
        XCTAssertEqual(MentionType.folder.prefix, "@folder:")
        XCTAssertEqual(MentionType.url.prefix, "@url:")
        XCTAssertEqual(MentionType.project.prefix, "@project:")
    }

    func testIcons() {
        XCTAssertEqual(MentionType.file.icon, "doc.fill")
        XCTAssertEqual(MentionType.folder.icon, "folder.fill")
        XCTAssertEqual(MentionType.url.icon, "link")
        XCTAssertEqual(MentionType.project.icon, "folder.badge.gearshape")
    }

    func testDisplayNames() {
        XCTAssertEqual(MentionType.file.displayName, "File")
        XCTAssertEqual(MentionType.folder.displayName, "Folder")
        XCTAssertEqual(MentionType.url.displayName, "URL")
        XCTAssertEqual(MentionType.project.displayName, "Project")
    }

    func testColors() {
        XCTAssertEqual(MentionType.file.color, "5a9bd5")
        XCTAssertEqual(MentionType.folder.color, "d4a017")
        XCTAssertEqual(MentionType.url.color, "9c7bea")
        XCTAssertEqual(MentionType.project.color, "00976d")
    }

    func testRawValues() {
        XCTAssertEqual(MentionType.file.rawValue, "file")
        XCTAssertEqual(MentionType.folder.rawValue, "folder")
        XCTAssertEqual(MentionType.url.rawValue, "url")
        XCTAssertEqual(MentionType.project.rawValue, "project")
    }

    func testCodable() throws {
        for type in MentionType.allCases {
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()

            let data = try encoder.encode(type)
            let decoded = try decoder.decode(MentionType.self, from: data)

            XCTAssertEqual(decoded, type)
        }
    }

    func testInitFromRawValue() {
        XCTAssertEqual(MentionType(rawValue: "file"), .file)
        XCTAssertEqual(MentionType(rawValue: "folder"), .folder)
        XCTAssertEqual(MentionType(rawValue: "url"), .url)
        XCTAssertEqual(MentionType(rawValue: "project"), .project)
        XCTAssertNil(MentionType(rawValue: "invalid"))
    }
}

// MARK: - MentionableItem Tests

final class MentionableItemTests: XCTestCase {

    func testDefaultInitialization() {
        let item = MentionableItem(
            type: .file,
            value: "/path/to/file.swift"
        )

        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.type, .file)
        XCTAssertEqual(item.value, "/path/to/file.swift")
        XCTAssertEqual(item.displayName, "file.swift")
        XCTAssertNil(item.subtitle)
        XCTAssertNotNil(item.icon)
        XCTAssertFalse(item.isRecent)
        XCTAssertNil(item.lastAccessed)
        XCTAssertNil(item.fileSize)
    }

    func testFullInitialization() {
        let id = UUID()
        let date = Date()

        let item = MentionableItem(
            id: id,
            type: .url,
            value: "https://example.com",
            displayName: "Example",
            subtitle: "A great website",
            icon: "globe",
            isRecent: true,
            lastAccessed: date,
            fileSize: 1024
        )

        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.type, .url)
        XCTAssertEqual(item.value, "https://example.com")
        XCTAssertEqual(item.displayName, "Example")
        XCTAssertEqual(item.subtitle, "A great website")
        XCTAssertEqual(item.icon, "globe")
        XCTAssertTrue(item.isRecent)
        XCTAssertEqual(item.lastAccessed, date)
        XCTAssertEqual(item.fileSize, 1024)
    }

    func testFileIconForPath() {
        let testCases: [(path: String, expected: String)] = [
            ("/path/file.swift", "swift"),
            ("/path/script.py", "circle.hexagonpath.fill"),
            ("/path/app.js", "curlybraces"),
            ("/path/app.ts", "curlybraces"),
            ("/path/page.html", "chevron.left.forwardslash.chevron.right"),
            ("/path/styles.css", "paintbrush.fill"),
            ("/path/data.json", "curlybraces.square.fill"),
            ("/path/readme.md", "doc.richtext.fill"),
            ("/path/notes.txt", "doc.text.fill"),
            ("/path/doc.pdf", "doc.fill"),
            ("/path/image.png", "photo.fill"),
            ("/path/config.yaml", "list.bullet.rectangle"),
            ("/path/script.sh", "terminal.fill"),
            ("/path/main.rs", "gearshape.2.fill"),
            ("/path/server.go", "forward.fill"),
            ("/path/App.java", "cup.and.saucer.fill"),
            ("/path/script.rb", "diamond.fill"),
            ("/path/api.php", "p.circle.fill"),
            ("/path/header.h", "c.circle.fill"),
            ("/path/main.cpp", "plus.circle.fill"),
            ("/path/app.cs", "number.circle.fill"),
        ]

        for testCase in testCases {
            let item = MentionableItem(type: .file, value: testCase.path)
            XCTAssertEqual(item.icon, testCase.expected, "Failed for \(testCase.path)")
        }
    }

    func testNonFileTypeUsesDefaultIcon() {
        let folderItem = MentionableItem(type: .folder, value: "/path")
        XCTAssertEqual(folderItem.icon, "folder.fill")

        let urlItem = MentionableItem(type: .url, value: "https://example.com")
        XCTAssertEqual(urlItem.icon, "link")

        let projectItem = MentionableItem(type: .project, value: "MyProject")
        XCTAssertEqual(projectItem.icon, "folder.badge.gearshape")
    }

    func testColorForPath() {
        let testCases: [(path: String, expected: String)] = [
            ("/path/file.swift", "f05138"),
            ("/path/file.py", "3776ab"),
            ("/path/file.js", "f7df1e"),
            ("/path/file.ts", "3178c6"),
            ("/path/file.html", "e34f26"),
            ("/path/file.css", "264de4"),
            ("/path/file.json", "d4a017"),
            ("/path/file.md", "5a9bd5"),
            ("/path/file.rs", "dea584"),
            ("/path/file.go", "00add8"),
        ]

        for testCase in testCases {
            let color = MentionableItem.colorForPath(testCase.path, type: .file)
            XCTAssertEqual(color, testCase.expected, "Failed for \(testCase.path)")
        }
    }

    func testNonFileTypeUsesDefaultColor() {
        let folderColor = MentionableItem.colorForPath("/path", type: .folder)
        XCTAssertEqual(folderColor, MentionType.folder.color)

        let urlColor = MentionableItem.colorForPath("https://example.com", type: .url)
        XCTAssertEqual(urlColor, MentionType.url.color)
    }

    func testCustomIcon() {
        let item = MentionableItem(
            type: .file,
            value: "/path/to/file.xyz",
            icon: "custom.icon"
        )

        XCTAssertEqual(item.icon, "custom.icon")
    }

    func testDisplayNameExtraction() {
        let item1 = MentionableItem(type: .file, value: "/path/to/file.txt")
        XCTAssertEqual(item1.displayName, "file.txt")

        let item2 = MentionableItem(
            type: .url,
            value: "https://example.com",
            displayName: "Custom Name"
        )
        XCTAssertEqual(item2.displayName, "Custom Name")
    }
}

// MARK: - MentionContext Tests

final class MentionContextTests: XCTestCase {

    func testEmptyContext() {
        let context = MentionContext(
            mentions: [],
            totalTokens: 0,
            warnings: []
        )

        let result = context.generateContextString()
        XCTAssertEqual(result, "")
    }

    func testSingleFileMention() {
        let mention = Mention(
            type: .file,
            value: "/path/to/file.txt",
            displayName: "file.txt",
            resolvedContent: "File contents here"
        )

        let context = MentionContext(
            mentions: [mention],
            totalTokens: 10,
            warnings: []
        )

        let result = context.generateContextString()
        XCTAssertTrue(result.contains("[Referenced Context]"))
        XCTAssertTrue(result.contains("--- File: /path/to/file.txt ---"))
        XCTAssertTrue(result.contains("File contents here"))
        XCTAssertTrue(result.contains("[End of Context]"))
    }

    func testMultipleMentions() {
        let mentions = [
            Mention(
                type: .file,
                value: "/path/file1.txt",
                resolvedContent: "Content 1"
            ),
            Mention(
                type: .file,
                value: "/path/file2.txt",
                resolvedContent: "Content 2"
            )
        ]

        let context = MentionContext(
            mentions: mentions,
            totalTokens: 20,
            warnings: []
        )

        let result = context.generateContextString()
        XCTAssertTrue(result.contains("--- File: /path/file1.txt ---"))
        XCTAssertTrue(result.contains("--- File: /path/file2.txt ---"))
        XCTAssertTrue(result.contains("Content 1"))
        XCTAssertTrue(result.contains("Content 2"))
    }

    func testMentionsWithoutResolvedContent() {
        let mention = Mention(
            type: .file,
            value: "/path/to/file.txt",
            resolvedContent: nil
        )

        let context = MentionContext(
            mentions: [mention],
            totalTokens: 0,
            warnings: []
        )

        let result = context.generateContextString()
        // Mentions without resolved content should be skipped
        XCTAssertFalse(result.contains("--- File: /path/to/file.txt ---"))
    }

    func testFolderMentionFormatting() {
        let mention = Mention(
            type: .folder,
            value: "/path/to/folder",
            resolvedContent: "Folder contents list"
        )

        let context = MentionContext(
            mentions: [mention],
            totalTokens: 5,
            warnings: []
        )

        let result = context.generateContextString()
        XCTAssertTrue(result.contains("--- Folder Contents: /path/to/folder ---"))
    }

    func testURLMentionFormatting() {
        let mention = Mention(
            type: .url,
            value: "https://example.com",
            resolvedContent: "URL content"
        )

        let context = MentionContext(
            mentions: [mention],
            totalTokens: 15,
            warnings: []
        )

        let result = context.generateContextString()
        XCTAssertTrue(result.contains("--- URL Content: https://example.com ---"))
    }

    func testProjectMentionFormatting() {
        let mention = Mention(
            type: .project,
            value: "MyProject",
            resolvedContent: "Project context"
        )

        let context = MentionContext(
            mentions: [mention],
            totalTokens: 25,
            warnings: []
        )

        let result = context.generateContextString()
        XCTAssertTrue(result.contains("--- Project Context: MyProject ---"))
    }

    func testWithWarnings() {
        let mention = Mention(
            type: .file,
            value: "/path/to/file.txt",
            resolvedContent: "Content"
        )

        let context = MentionContext(
            mentions: [mention],
            totalTokens: 100,
            warnings: ["Large file", "Binary content detected"]
        )

        // The context string doesn't include warnings, but they're stored
        XCTAssertEqual(context.warnings.count, 2)
        XCTAssertEqual(context.totalTokens, 100)
    }
}

// MARK: - ResolvedMention Tests

final class ResolvedMentionTests: XCTestCase {

    func testSuccessfulResolution() {
        let mention = Mention(type: .file, value: "/path/to/file.txt")
        let resolved = ResolvedMention(
            mention: mention,
            content: "File content",
            tokenCount: 10,
            error: nil
        )

        XCTAssertTrue(resolved.isSuccess)
        XCTAssertEqual(resolved.content, "File content")
        XCTAssertEqual(resolved.tokenCount, 10)
        XCTAssertEqual(resolved.mention.id, mention.id)
    }

    func testFailedResolution() {
        let mention = Mention(type: .file, value: "/nonexistent/file.txt")
        let resolved = ResolvedMention(
            mention: mention,
            content: "",
            tokenCount: 0,
            error: "File not found"
        )

        XCTAssertFalse(resolved.isSuccess)
        XCTAssertEqual(resolved.error, "File not found")
    }
}
