import SwiftUI
import KeychainAccess

// MARK: - PostgreSQL Settings View

struct PostgreSQLSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = PostgreSQLSettingsViewModel()

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VaizorSpacing.lg) {
                // Header
                headerSection

                // Connection Status
                connectionStatusSection

                // Connection Settings
                connectionSettingsSection

                // Migration Section
                if viewModel.isConnected {
                    migrationSection
                }

                Spacer(minLength: VaizorSpacing.xl)
            }
            .padding(VaizorSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.background)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.xs) {
            HStack(spacing: VaizorSpacing.sm) {
                Image(systemName: "cylinder.split.1x2")
                    .font(.system(size: 24))
                    .foregroundColor(colors.accent)

                Text("PostgreSQL Storage")
                    .font(VaizorTypography.h1)
                    .foregroundColor(colors.textPrimary)
            }

            Text("Configure PostgreSQL as the primary data store for conversations, messages, and agent identity.")
                .font(VaizorTypography.body)
                .foregroundColor(colors.textSecondary)
        }
    }

    // MARK: - Connection Status Section

    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            Text("CONNECTION STATUS")
                .font(VaizorTypography.caption)
                .foregroundColor(colors.textMuted)

            HStack(spacing: VaizorSpacing.md) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)

                Text(viewModel.isConnected ? "Connected" : "Not Connected")
                    .font(VaizorTypography.body)
                    .foregroundColor(colors.textPrimary)

                Spacer()

                if viewModel.isTestingConnection {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button(action: {
                    Task {
                        await viewModel.testConnection()
                    }
                }) {
                    Text("Test Connection")
                        .font(VaizorTypography.bodySmall)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isTestingConnection)
            }
            .padding(VaizorSpacing.md)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))

            if let error = viewModel.connectionError {
                Text(error)
                    .font(VaizorTypography.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, VaizorSpacing.sm)
            }
        }
    }

    // MARK: - Connection Settings Section

    private var connectionSettingsSection: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            Text("CONNECTION SETTINGS")
                .font(VaizorTypography.caption)
                .foregroundColor(colors.textMuted)

            VStack(spacing: VaizorSpacing.md) {
                // Host and Port
                HStack(spacing: VaizorSpacing.md) {
                    VStack(alignment: .leading, spacing: VaizorSpacing.xxs) {
                        Text("Host")
                            .font(VaizorTypography.bodySmall)
                            .foregroundColor(colors.textSecondary)
                        TextField("localhost", text: $viewModel.host)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: VaizorSpacing.xxs) {
                        Text("Port")
                            .font(VaizorTypography.bodySmall)
                            .foregroundColor(colors.textSecondary)
                        TextField("5432", text: $viewModel.port)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }

                // Database name
                VStack(alignment: .leading, spacing: VaizorSpacing.xxs) {
                    Text("Database")
                        .font(VaizorTypography.bodySmall)
                        .foregroundColor(colors.textSecondary)
                    TextField("vaizor", text: $viewModel.database)
                        .textFieldStyle(.roundedBorder)
                }

                // Username and Password
                HStack(spacing: VaizorSpacing.md) {
                    VStack(alignment: .leading, spacing: VaizorSpacing.xxs) {
                        Text("Username")
                            .font(VaizorTypography.bodySmall)
                            .foregroundColor(colors.textSecondary)
                        TextField("vaizor", text: $viewModel.username)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: VaizorSpacing.xxs) {
                        Text("Password")
                            .font(VaizorTypography.bodySmall)
                            .foregroundColor(colors.textSecondary)
                        SecureField("", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                // TLS toggle
                Toggle(isOn: $viewModel.useTLS) {
                    HStack {
                        Text("Use TLS")
                            .font(VaizorTypography.body)
                            .foregroundColor(colors.textPrimary)
                        Spacer()
                    }
                }
                .toggleStyle(.switch)

                // Save button
                HStack {
                    Spacer()

                    Button(action: {
                        Task {
                            await viewModel.saveAndConnect()
                        }
                    }) {
                        HStack(spacing: VaizorSpacing.xs) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.isSaving ? "Connecting..." : "Save & Connect")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving)
                }
            }
            .padding(VaizorSpacing.md)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
        }
    }

    // MARK: - Migration Section

    private var migrationSection: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            Text("DATA MIGRATION")
                .font(VaizorTypography.caption)
                .foregroundColor(colors.textMuted)

            VStack(alignment: .leading, spacing: VaizorSpacing.md) {
                Text("Migrate existing data from SQLite to PostgreSQL")
                    .font(VaizorTypography.body)
                    .foregroundColor(colors.textPrimary)

                Text("This will copy all conversations, messages, attachments, and agent data to PostgreSQL. Your existing SQLite data will be preserved as a backup.")
                    .font(VaizorTypography.bodySmall)
                    .foregroundColor(colors.textSecondary)

                if viewModel.isMigrating {
                    VStack(alignment: .leading, spacing: VaizorSpacing.xs) {
                        ProgressView(value: viewModel.migrationProgress, total: 1.0)
                            .progressViewStyle(.linear)

                        Text(viewModel.migrationStatus)
                            .font(VaizorTypography.caption)
                            .foregroundColor(colors.textSecondary)
                    }
                }

                if let result = viewModel.migrationResult {
                    VStack(alignment: .leading, spacing: VaizorSpacing.xs) {
                        Text(result.isValid ? "Migration Complete" : "Migration Incomplete")
                            .font(VaizorTypography.body)
                            .foregroundColor(result.isValid ? .green : .orange)

                        Text(result.summary)
                            .font(VaizorTypography.code)
                            .foregroundColor(colors.textSecondary)
                            .padding(VaizorSpacing.sm)
                            .background(colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous))
                    }
                }

                HStack {
                    Spacer()

                    Button(action: {
                        Task {
                            await viewModel.startMigration()
                        }
                    }) {
                        HStack(spacing: VaizorSpacing.xs) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Start Migration")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isMigrating)
                }
            }
            .padding(VaizorSpacing.md)
            .background(colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
        }
    }
}

// MARK: - View Model

@MainActor
class PostgreSQLSettingsViewModel: ObservableObject {
    @Published var host: String = "localhost"
    @Published var port: String = "5432"
    @Published var database: String = "vaizor"
    @Published var username: String = "vaizor"
    @Published var password: String = ""
    @Published var useTLS: Bool = false

    @Published var isConnected: Bool = false
    @Published var isTestingConnection: Bool = false
    @Published var isSaving: Bool = false
    @Published var connectionError: String?

    @Published var isMigrating: Bool = false
    @Published var migrationProgress: Double = 0.0
    @Published var migrationStatus: String = ""
    @Published var migrationResult: MigrationVerificationResult?

    private let postgres = PostgresManager.shared
    private let keychain = Keychain(service: "com.quandrylabs.vaizor")
    private var migrationService: MigrationService?

    init() {
        loadSavedSettings()
        Task {
            await checkExistingConnection()
        }
    }

    private func loadSavedSettings() {
        let defaults = UserDefaults.standard
        host = defaults.string(forKey: "postgres.host") ?? "localhost"
        port = defaults.string(forKey: "postgres.port") ?? "5432"
        database = defaults.string(forKey: "postgres.database") ?? "vaizor"
        username = defaults.string(forKey: "postgres.username") ?? "vaizor"
        useTLS = defaults.bool(forKey: "postgres.tls")

        // Password is stored in Keychain
        if let pwd = try? keychain.get("postgres.password") {
            password = pwd
        }
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(host, forKey: "postgres.host")
        defaults.set(port, forKey: "postgres.port")
        defaults.set(database, forKey: "postgres.database")
        defaults.set(username, forKey: "postgres.username")
        defaults.set(useTLS, forKey: "postgres.tls")

        // Store password in Keychain
        try? keychain.set(password, key: "postgres.password")
    }

    private func checkExistingConnection() async {
        isConnected = await postgres.healthCheck()
    }

    func testConnection() async {
        isTestingConnection = true
        connectionError = nil

        do {
            let config = PostgresManager.PostgresConfig(
                host: host,
                port: Int(port) ?? 5432,
                username: username,
                password: password,
                database: database,
                tls: useTLS
            )

            try await postgres.configure(with: config)
            isConnected = await postgres.healthCheck()

            if !isConnected {
                connectionError = "Connection test failed. Check your settings."
            }
        } catch {
            connectionError = error.localizedDescription
            isConnected = false
        }

        isTestingConnection = false
    }

    func saveAndConnect() async {
        isSaving = true
        connectionError = nil

        saveSettings()
        await testConnection()

        if isConnected {
            // Run schema migrations
            do {
                try await postgres.runMigrations()
                AppLogger.shared.log("PostgreSQL schema migrations completed", level: .info)
            } catch {
                connectionError = "Connected but schema migration failed: \(error.localizedDescription)"
            }
        }

        isSaving = false
    }

    func startMigration() async {
        guard isConnected else {
            connectionError = "Must be connected to PostgreSQL before migrating"
            return
        }

        isMigrating = true
        migrationProgress = 0.0
        migrationStatus = "Starting migration..."
        migrationResult = nil

        do {
            migrationService = MigrationService(postgres: postgres)

            try await migrationService?.migrateAll { [weak self] status, progress in
                Task { @MainActor in
                    self?.migrationStatus = status
                    self?.migrationProgress = progress
                }
            }

            // Verify migration
            migrationStatus = "Verifying migration..."
            migrationResult = try await migrationService?.verifyMigration()

            if migrationResult?.isValid == true {
                migrationStatus = "Migration completed successfully!"
                AppLogger.shared.log("PostgreSQL migration completed and verified", level: .info)
            } else {
                migrationStatus = "Migration completed with some issues"
                AppLogger.shared.log("PostgreSQL migration completed but verification found issues", level: .warning)
            }
        } catch {
            migrationStatus = "Migration failed: \(error.localizedDescription)"
            AppLogger.shared.log("PostgreSQL migration failed: \(error)", level: .error)
        }

        isMigrating = false
    }
}

#Preview {
    PostgreSQLSettingsView()
}
