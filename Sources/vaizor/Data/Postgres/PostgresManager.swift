import Foundation
import PostgresNIO
import NIOCore
import NIOPosix
import Logging
import KeychainAccess

// MARK: - PostgreSQL Manager
// Manages connection pool and provides query execution for PostgreSQL

actor PostgresManager {
    static let shared = PostgresManager()

    private var connection: PostgresConnection?
    private let eventLoopGroup: EventLoopGroup
    private let logger: Logger
    private var config: PostgresConfig?
    private var encryptionKey: String?

    private init() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
        var logger = Logger(label: "vaizor.postgres")
        logger.logLevel = .warning
        self.logger = logger
    }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }

    // MARK: - Configuration

    struct PostgresConfig {
        let host: String
        let port: Int
        let username: String
        let password: String
        let database: String
        let tls: Bool

        static var local: PostgresConfig {
            PostgresConfig(
                host: "localhost",
                port: 5432,
                username: "vaizor",
                password: "vaizor_dev",
                database: "vaizor",
                tls: false
            )
        }

        static func fromEnvironment() -> PostgresConfig {
            let processInfo = Foundation.ProcessInfo.processInfo
            return PostgresConfig(
                host: processInfo.environment["VAIZOR_DB_HOST"] ?? "localhost",
                port: Int(processInfo.environment["VAIZOR_DB_PORT"] ?? "5432") ?? 5432,
                username: processInfo.environment["VAIZOR_DB_USER"] ?? "vaizor",
                password: processInfo.environment["VAIZOR_DB_PASSWORD"] ?? "vaizor_dev",
                database: processInfo.environment["VAIZOR_DB_NAME"] ?? "vaizor",
                tls: processInfo.environment["VAIZOR_DB_TLS"] == "true"
            )
        }
    }

    // MARK: - Connection Management

    func configure(with config: PostgresConfig) async throws {
        self.config = config

        // Load or generate encryption key from keychain
        self.encryptionKey = try loadOrCreateEncryptionKey()

        // Establish connection
        try await connect()
    }

    private func connect() async throws {
        guard let config = config else {
            throw PostgresError.notConfigured
        }

        let configuration = PostgresConnection.Configuration(
            host: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: config.tls ? .require(try .init(configuration: .clientDefault)) : .disable
        )

        connection = try await PostgresConnection.connect(
            on: eventLoopGroup.next(),
            configuration: configuration,
            id: 1,
            logger: logger
        )

        Task { @MainActor in
            AppLogger.shared.log("PostgreSQL connected to \(config.host):\(config.port)/\(config.database)", level: .info)
        }
    }

    func disconnect() async {
        try? await connection?.close()
        connection = nil
        Task { @MainActor in
            AppLogger.shared.log("PostgreSQL disconnected", level: .info)
        }
    }

    private func ensureConnected() async throws {
        if connection == nil {
            try await connect()
        }
    }

    // MARK: - Encryption Key Management

    private func loadOrCreateEncryptionKey() throws -> String {
        let keychain = Keychain(service: "com.quandrylabs.vaizor")

        if let existingKey = try keychain.get("database_encryption_key") {
            return existingKey
        }

        // Generate a new 256-bit key
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw PostgresError.keyGenerationFailed
        }

        let newKey = Data(bytes).base64EncodedString()
        try keychain.set(newKey, key: "database_encryption_key")

        Task { @MainActor in
            AppLogger.shared.log("Generated new database encryption key", level: .info)
        }
        return newKey
    }

    func getEncryptionKey() -> String? {
        return encryptionKey
    }

    // MARK: - Query Execution

    func query(_ sql: String, _ bindings: [PostgresData] = []) async throws -> PostgresQueryResult {
        try await ensureConnected()
        guard let conn = connection else {
            throw PostgresError.notConnected
        }

        let result = try await conn.query(PostgresQuery(stringLiteral: sql), logger: logger)
        return PostgresQueryResult(rows: result)
    }

    func execute(_ sql: String, _ bindings: [PostgresData] = []) async throws {
        try await ensureConnected()
        guard let conn = connection else {
            throw PostgresError.notConnected
        }

        _ = try await conn.query(PostgresQuery(stringLiteral: sql), logger: logger)
    }

    // MARK: - Transaction Support

    func transaction<T>(_ work: @escaping () async throws -> T) async throws -> T {
        try await execute("BEGIN")
        do {
            let result = try await work()
            try await execute("COMMIT")
            return result
        } catch {
            try await execute("ROLLBACK")
            throw error
        }
    }

    // MARK: - Schema Management

    func runMigrations() async throws {
        guard let schemaURL = Bundle.main.url(forResource: "database-schema", withExtension: "sql") else {
            // Try loading from Docs directory during development
            let docsPath = URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Docs/database-schema.sql")

            if FileManager.default.fileExists(atPath: docsPath.path) {
                let schema = try String(contentsOf: docsPath, encoding: .utf8)
                try await executeSchema(schema)
                return
            }

            throw PostgresError.schemaNotFound
        }

        let schema = try String(contentsOf: schemaURL, encoding: .utf8)
        try await executeSchema(schema)
    }

    private func executeSchema(_ schema: String) async throws {
        // Split by semicolons and execute each statement
        let statements = schema
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("--") }

        for statement in statements {
            do {
                try await execute(statement + ";")
            } catch {
                // Log but continue - some statements may already exist
                Task { @MainActor in
                    AppLogger.shared.log("Migration statement failed (may be expected): \(error.localizedDescription)", level: .debug)
                }
            }
        }

        Task { @MainActor in
            AppLogger.shared.log("Database migrations completed", level: .info)
        }
    }

    // MARK: - Health Check

    func healthCheck() async -> Bool {
        do {
            let result = try await query("SELECT 1 as ok")
            let rows = try await result.collect()
            return !rows.isEmpty
        } catch {
            return false
        }
    }
}

// MARK: - Query Result Wrapper

struct PostgresQueryResult {
    let rows: PostgresRowSequence

    func collect() async throws -> [PostgresRow] {
        var collected: [PostgresRow] = []
        for try await row in rows {
            collected.append(row)
        }
        return collected
    }
}

// MARK: - Errors

enum PostgresError: LocalizedError {
    case notConfigured
    case notConnected
    case keyGenerationFailed
    case schemaNotFound
    case queryFailed(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "PostgreSQL not configured. Call configure() first."
        case .notConnected:
            return "Not connected to PostgreSQL"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .schemaNotFound:
            return "Database schema file not found"
        case .queryFailed(let msg):
            return "Query failed: \(msg)"
        case .decodingFailed(let msg):
            return "Failed to decode result: \(msg)"
        }
    }
}

// MARK: - PostgresData Helpers

extension UUID {
    var postgresData: PostgresData {
        PostgresData(uuid: self)
    }
}

extension String {
    var postgresData: PostgresData {
        PostgresData(string: self)
    }
}

extension Int {
    var postgresData: PostgresData {
        PostgresData(int: self)
    }
}

extension Bool {
    var postgresData: PostgresData {
        PostgresData(bool: self)
    }
}

extension Double {
    var postgresData: PostgresData {
        PostgresData(double: self)
    }
}

extension Float {
    var postgresData: PostgresData {
        PostgresData(float: self)
    }
}

extension Date {
    var postgresData: PostgresData {
        PostgresData(date: self)
    }
}

extension Data {
    var postgresData: PostgresData {
        PostgresData(bytes: [UInt8](self))
    }
}

