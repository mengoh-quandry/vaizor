import XCTest
@testable import vaizor

final class MCPDiscoveryServiceTests: XCTestCase {
    var sut: MCPDiscoveryService!

    override func setUp() {
        super.setUp()
        sut = MCPDiscoveryService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Runtime Detection Tests

    func testRuntimeDetectionPython() {
        let server = createTestServer(command: "/usr/bin/python3")
        XCTAssertEqual(server.runtime, .python)

        let server2 = createTestServer(command: "python")
        XCTAssertEqual(server2.runtime, .python)
    }

    func testRuntimeDetectionNode() {
        let server = createTestServer(command: "/usr/local/bin/node")
        XCTAssertEqual(server.runtime, .node)

        let server2 = createTestServer(command: "node")
        XCTAssertEqual(server2.runtime, .node)
    }

    func testRuntimeDetectionBun() {
        let server = createTestServer(command: "/opt/homebrew/bin/bun")
        XCTAssertEqual(server.runtime, .bun)
    }

    func testRuntimeDetectionDeno() {
        let server = createTestServer(command: "deno")
        XCTAssertEqual(server.runtime, .deno)
    }

    func testRuntimeDetectionShell() {
        let server = createTestServer(command: "./run-server.sh")
        XCTAssertEqual(server.runtime, .shell)
    }

    func testRuntimeDetectionBinary() {
        let server = createTestServer(command: "/usr/local/bin/custom-mcp")
        XCTAssertEqual(server.runtime, .binary)
    }

    // MARK: - Display Name Tests

    func testRuntimeDisplayNames() {
        XCTAssertEqual(DiscoveredServer.DetectedRuntime.python.displayName, "Python")
        XCTAssertEqual(DiscoveredServer.DetectedRuntime.node.displayName, "Node.js")
        XCTAssertEqual(DiscoveredServer.DetectedRuntime.bun.displayName, "Bun")
        XCTAssertEqual(DiscoveredServer.DetectedRuntime.deno.displayName, "Deno")
        XCTAssertEqual(DiscoveredServer.DetectedRuntime.shell.displayName, "Shell")
        XCTAssertEqual(DiscoveredServer.DetectedRuntime.binary.displayName, "Binary")
    }

    // MARK: - Equality Tests

    func testDiscoveredServerEquality() {
        let server1 = createTestServer(id: "test:server1", command: "node")
        let server2 = createTestServer(id: "test:server1", command: "python")
        let server3 = createTestServer(id: "test:server2", command: "node")

        // Same ID = equal
        XCTAssertEqual(server1, server2)
        // Different ID = not equal
        XCTAssertNotEqual(server1, server3)
    }

    // MARK: - Import Tests

    func testImportServer() {
        let discovered = createTestServer(
            name: "TestServer",
            command: "/usr/bin/node",
            args: ["server.js"],
            env: ["API_KEY": "secret"],
            workingDirectory: "/tmp"
        )

        let imported = sut.importServer(discovered)

        XCTAssertEqual(imported.name, "TestServer")
        XCTAssertEqual(imported.command, "/usr/bin/node")
        XCTAssertEqual(imported.args, ["server.js"])
        XCTAssertEqual(imported.env, ["API_KEY": "secret"])
        XCTAssertEqual(imported.workingDirectory, "/tmp")
        XCTAssertEqual(imported.sourceConfig, .claudeDesktop)
        XCTAssertTrue(imported.description.contains("Imported from"))
    }

    // MARK: - Discovery Source Tests

    func testDiscoverySourceDisplayNames() {
        XCTAssertEqual(DiscoverySource.manual.displayName, "Manual")
        XCTAssertEqual(DiscoverySource.claudeDesktop.displayName, "Claude Desktop")
        XCTAssertEqual(DiscoverySource.cursor.displayName, "Cursor")
        XCTAssertEqual(DiscoverySource.claudeCode.displayName, "Claude Code")
        XCTAssertEqual(DiscoverySource.vscode.displayName, "VS Code")
        XCTAssertEqual(DiscoverySource.dotfile.displayName, "Project Config")
    }

    func testDiscoverySourceIcons() {
        XCTAssertFalse(DiscoverySource.claudeDesktop.icon.isEmpty)
        XCTAssertFalse(DiscoverySource.cursor.icon.isEmpty)
        XCTAssertFalse(DiscoverySource.vscode.icon.isEmpty)
    }

    // MARK: - Command Validation Tests

    func testValidateCommandWithAbsolutePath() {
        // /bin/sh should always exist
        XCTAssertTrue(sut.validateCommand("/bin/sh"))
        // Non-existent path
        XCTAssertFalse(sut.validateCommand("/nonexistent/command"))
    }

    func testValidateCommandInPath() {
        // 'ls' should be in PATH
        XCTAssertTrue(sut.validateCommand("ls"))
        // Non-existent command
        XCTAssertFalse(sut.validateCommand("nonexistentcommand12345"))
    }

    // MARK: - Grouping Tests

    func testGroupedBySource() {
        let servers = [
            createTestServer(id: "claude:a", source: .claudeDesktop),
            createTestServer(id: "claude:b", source: .claudeDesktop),
            createTestServer(id: "cursor:a", source: .cursor),
        ]

        let groups = servers.groupedBySource()

        XCTAssertEqual(groups.count, 2)
        // Claude Desktop should come first (more servers)
        XCTAssertEqual(groups[0].servers.count, 2)
        XCTAssertEqual(groups[1].servers.count, 1)
    }

    func testImportableCount() {
        let servers = [
            createTestServer(id: "test:1", isAlreadyImported: false),
            createTestServer(id: "test:2", isAlreadyImported: true),
            createTestServer(id: "test:3", isAlreadyImported: false),
        ]

        let group = DiscoveredServerGroup(source: .claudeDesktop, servers: servers)

        XCTAssertEqual(group.importableCount, 2)
    }

    // MARK: - Helpers

    private func createTestServer(
        id: String = "test:server",
        name: String = "TestServer",
        command: String = "node",
        args: [String] = [],
        env: [String: String]? = nil,
        workingDirectory: String? = nil,
        source: DiscoverySource = .claudeDesktop,
        isAlreadyImported: Bool = false,
        securityWarning: String? = nil
    ) -> DiscoveredServer {
        DiscoveredServer(
            id: id,
            name: name,
            command: command,
            args: args,
            env: env,
            workingDirectory: workingDirectory,
            source: source,
            sourcePath: "/test/config.json",
            isAlreadyImported: isAlreadyImported,
            securityWarning: securityWarning
        )
    }

    // MARK: - Security Validation Tests

    func testIsCommandSafe_normalCommand() {
        XCTAssertTrue(sut.isCommandSafe("node", args: ["server.js"]))
        XCTAssertTrue(sut.isCommandSafe("/usr/bin/python3", args: ["-m", "mcp_server"]))
    }

    func testIsCommandSafe_shellMetacharacters() {
        XCTAssertFalse(sut.isCommandSafe("node; rm -rf /", args: []))
        XCTAssertFalse(sut.isCommandSafe("node", args: ["server.js; evil"]))
        XCTAssertFalse(sut.isCommandSafe("node", args: ["$(whoami)"]))
        XCTAssertFalse(sut.isCommandSafe("node | cat", args: []))
    }

    func testIsCommandSafe_shellWithDashC() {
        XCTAssertFalse(sut.isCommandSafe("/bin/sh", args: ["-c", "malicious"]))
        XCTAssertFalse(sut.isCommandSafe("bash", args: ["-c", "evil"]))
    }

    func testValidateWorkingDirectory_valid() {
        // Home directory should be valid
        let home = NSHomeDirectory()
        XCTAssertNotNil(sut.validateWorkingDirectory(home))
    }

    func testValidateWorkingDirectory_blockedPaths() {
        XCTAssertNil(sut.validateWorkingDirectory("/System"))
        XCTAssertNil(sut.validateWorkingDirectory("/usr/bin"))
        XCTAssertNil(sut.validateWorkingDirectory("/etc"))
    }

    func testValidateWorkingDirectory_nonexistent() {
        XCTAssertNil(sut.validateWorkingDirectory("/nonexistent/path"))
    }
}
