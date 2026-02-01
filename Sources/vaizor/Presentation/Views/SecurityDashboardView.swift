import SwiftUI
import UniformTypeIdentifiers

// MARK: - Security Dashboard View

struct SecurityDashboardView: View {
    @ObservedObject private var edrService = AiEDRService.shared
    @State private var selectedTab: SecurityTab = .overview
    @State private var isPerformingHostCheck = false
    @State private var showExportSheet = false
    @State private var exportDocument: AuditLogDocument?

    private let darkBase = Color(hex: "1c1d1f")
    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    enum SecurityTab: String, CaseIterable {
        case overview = "Overview"
        case alerts = "Alerts"
        case auditLog = "Audit Log"
        case hostSecurity = "Host Security"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .overview: return "shield.checkered"
            case .alerts: return "exclamationmark.triangle"
            case .auditLog: return "list.bullet.clipboard"
            case .hostSecurity: return "desktopcomputer"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Rectangle().fill(darkBorder).frame(height: 1)

            // Tab bar
            tabBar

            Rectangle().fill(darkBorder).frame(height: 1)

            // Content
            ScrollView {
                content
                    .padding(20)
            }
        }
        .background(darkBase)
        .frame(minWidth: 700, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            // Threat level indicator
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(edrService.threatLevel.color.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: edrService.threatLevel.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(edrService.threatLevel.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Threat Level")
                        .font(.system(size: 11))
                        .foregroundStyle(textSecondary)

                    Text(edrService.threatLevel.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(edrService.threatLevel.color)
                }
            }

            Spacer()

            // Stats
            HStack(spacing: 24) {
                StatBadge(
                    title: "Detected",
                    value: "\(edrService.totalDetectedThreats)",
                    color: .orange
                )

                StatBadge(
                    title: "Blocked",
                    value: "\(edrService.totalBlockedThreats)",
                    color: .red
                )

                StatBadge(
                    title: "Active Alerts",
                    value: "\(edrService.activeAlerts.count)",
                    color: edrService.activeAlerts.isEmpty ? accent : .yellow
                )
            }

            Spacer()

            // Quick actions
            HStack(spacing: 10) {
                Toggle("EDR Enabled", isOn: $edrService.isEnabled)
                    .toggleStyle(.switch)
                    .tint(accent)

                Button {
                    // Create document lazily only when export is requested
                    exportDocument = AuditLogDocument(data: edrService.exportAuditLog() ?? Data())
                    showExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                }
                .buttonStyle(SecurityButtonStyle())
                .help("Export Audit Log")
            }
        }
        .padding(20)
        .background(darkSurface)
        .fileExporter(
            isPresented: $showExportSheet,
            document: exportDocument ?? AuditLogDocument(data: Data()),
            contentType: .json,
            defaultFilename: "vaizor_audit_log.json"
        ) { _ in
            exportDocument = nil
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SecurityTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))

                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))

                        if tab == .alerts && !edrService.activeAlerts.isEmpty {
                            Text("\(edrService.activeAlerts.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? accent : textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedTab == tab ? accent.opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(darkBase)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .overview:
            OverviewContent(edrService: edrService)
        case .alerts:
            AlertsContent(edrService: edrService)
        case .auditLog:
            AuditLogContent(edrService: edrService)
        case .hostSecurity:
            HostSecurityContent(edrService: edrService, isPerformingCheck: $isPerformingHostCheck)
        case .settings:
            EDRSettingsContent(edrService: edrService)
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "808080"))
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Overview Content

private struct OverviewContent: View {
    @ObservedObject var edrService: AiEDRService

    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        VStack(spacing: 20) {
            // Security Status Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatusCard(
                    title: "Prompt Analysis",
                    icon: "text.magnifyingglass",
                    status: edrService.isEnabled ? "Active" : "Disabled",
                    statusColor: edrService.isEnabled ? accent : .red,
                    description: "Scans incoming prompts for injection attempts"
                )

                StatusCard(
                    title: "Response Analysis",
                    icon: "doc.text.magnifyingglass",
                    status: edrService.isEnabled ? "Active" : "Disabled",
                    statusColor: edrService.isEnabled ? accent : .red,
                    description: "Monitors model outputs for malicious content"
                )

                StatusCard(
                    title: "Host Monitoring",
                    icon: "desktopcomputer.and.arrow.down",
                    status: edrService.backgroundMonitoring ? "Active" : "Disabled",
                    statusColor: edrService.backgroundMonitoring ? accent : .yellow,
                    description: "Periodic security assessment of your system"
                )

                StatusCard(
                    title: "Audit Logging",
                    icon: "list.bullet.clipboard",
                    status: "\(edrService.auditLog.count) entries",
                    statusColor: accent,
                    description: "Complete history of security events"
                )
            }

            // Recent Alerts Preview
            if !edrService.activeAlerts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Alerts")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(textPrimary)

                        Spacer()

                        Text("\(edrService.activeAlerts.count) total")
                            .font(.system(size: 12))
                            .foregroundStyle(textSecondary)
                    }

                    ForEach(edrService.activeAlerts.prefix(3)) { alert in
                        CompactAlertRow(alert: alert)
                    }
                }
                .padding(16)
                .background(darkSurface)
                .cornerRadius(10)
            }

            // Quick Stats
            HStack(spacing: 16) {
                QuickStatCard(
                    title: "Protection Status",
                    items: [
                        ("Auto-block Critical", edrService.autoBlockCritical),
                        ("Prompt on High", edrService.promptOnHigh),
                        ("Threats Only", edrService.logThreatsOnly)
                    ]
                )

                if let report = edrService.lastHostSecurityReport {
                    QuickStatCard(
                        title: "Host Security",
                        items: [
                            ("Firewall", report.firewallEnabled),
                            ("FileVault", report.diskEncrypted),
                            ("Gatekeeper", report.gatekeeperEnabled),
                            ("SIP", report.systemIntegrityProtection)
                        ]
                    )
                }
            }
        }
    }
}

// MARK: - Status Card

private struct StatusCard: View {
    let title: String
    let icon: String
    let status: String
    let statusColor: Color
    let description: String

    private let darkSurface = Color(hex: "232426")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(statusColor)

                Spacer()

                Text(status)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textPrimary)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(darkSurface)
        .cornerRadius(10)
    }
}

// MARK: - Quick Stat Card

private struct QuickStatCard: View {
    let title: String
    let items: [(String, Bool)]

    private let darkSurface = Color(hex: "232426")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(textSecondary)

            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.system(size: 12))
                            .foregroundStyle(textPrimary)

                        Spacer()

                        Image(systemName: item.1 ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(item.1 ? accent : .red)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(darkSurface)
        .cornerRadius(10)
    }
}

// MARK: - Compact Alert Row

private struct CompactAlertRow: View {
    let alert: SecurityAlert

    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.type.icon)
                .font(.system(size: 14))
                .foregroundStyle(alert.severity.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.message)
                    .font(.system(size: 12))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)

                Text(alert.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            Text(alert.severity.rawValue)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(alert.severity.color)
        }
        .padding(10)
        .background(darkBorder.opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - Alerts Content

private struct AlertsContent: View {
    @ObservedObject var edrService: AiEDRService
    @State private var filterSeverity: ThreatLevel?
    @State private var filterType: AlertType?

    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    private var filteredAlerts: [SecurityAlert] {
        edrService.activeAlerts.filter { alert in
            (filterSeverity == nil || alert.severity == filterSeverity) &&
            (filterType == nil || alert.type == filterType)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Filters
            HStack(spacing: 12) {
                Menu {
                    Button("All Severities") { filterSeverity = nil }
                    Divider()
                    ForEach(ThreatLevel.allCases, id: \.self) { level in
                        Button {
                            filterSeverity = level
                        } label: {
                            HStack {
                                Text(level.rawValue)
                                if filterSeverity == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filterSeverity?.rawValue ?? "All Severities")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(darkSurface)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Menu {
                    Button("All Types") { filterType = nil }
                    Divider()
                    ForEach(AlertType.allCases, id: \.self) { type in
                        Button {
                            filterType = type
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                if filterType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filterType?.rawValue ?? "All Types")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(darkSurface)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                if edrService.activeAlerts.contains(where: { $0.isAcknowledged }) {
                    Button("Clear Acknowledged") {
                        edrService.clearAcknowledgedAlerts()
                    }
                    .font(.system(size: 12))
                    .buttonStyle(SecurityButtonStyle())
                }
            }

            // Alerts list
            if filteredAlerts.isEmpty {
                EmptyStateView(
                    icon: "checkmark.shield",
                    title: "No Active Alerts",
                    message: "Your system is currently secure"
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredAlerts) { alert in
                        AlertRow(alert: alert, onAcknowledge: {
                            edrService.acknowledgeAlert(alert.id)
                        }, onDismiss: {
                            edrService.clearAlert(alert.id)
                        })
                    }
                }
            }
        }
    }
}

// MARK: - Alert Row

private struct AlertRow: View {
    let alert: SecurityAlert
    let onAcknowledge: () -> Void
    let onDismiss: () -> Void

    @State private var isExpanded = false

    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Image(systemName: alert.type.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(alert.severity.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(alert.type.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textPrimary)

                        if alert.isAcknowledged {
                            Text("Acknowledged")
                                .font(.system(size: 9))
                                .foregroundStyle(textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(darkBorder))
                        }
                    }

                    Text(alert.message)
                        .font(.system(size: 12))
                        .foregroundStyle(textSecondary)
                        .lineLimit(isExpanded ? nil : 1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(alert.severity.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(alert.severity.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(alert.severity.color.opacity(0.2))
                        .cornerRadius(4)

                    Text(alert.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(textSecondary)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    if !alert.matchedPatterns.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Matched Patterns")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(textSecondary)

                            Text(alert.matchedPatterns.joined(separator: ", "))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(textPrimary)
                        }
                    }

                    if !alert.affectedContent.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Affected Content")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(textSecondary)

                            Text(alert.affectedContent)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(textPrimary)
                                .padding(8)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 10) {
                        if !alert.isAcknowledged {
                            Button("Acknowledge") {
                                onAcknowledge()
                            }
                            .buttonStyle(SecurityButtonStyle())
                        }

                        Button("Dismiss") {
                            onDismiss()
                        }
                        .buttonStyle(SecurityButtonStyle(isDestructive: true))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(darkSurface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(alert.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Audit Log Content

private struct AuditLogContent: View {
    @ObservedObject var edrService: AiEDRService
    @State private var filterEventType: AuditEventType?
    @State private var searchText = ""

    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    private var filteredEntries: [AuditEntry] {
        edrService.auditLog.filter { entry in
            let matchesType = filterEventType == nil || entry.eventType == filterEventType
            let matchesSearch = searchText.isEmpty ||
                entry.description.localizedCaseInsensitiveContains(searchText) ||
                entry.eventType.rawValue.localizedCaseInsensitiveContains(searchText)
            return matchesType && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Search and filters
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(textSecondary)

                    TextField("Search audit log...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(darkSurface)
                .cornerRadius(6)

                Menu {
                    Button("All Events") { filterEventType = nil }
                    Divider()
                    ForEach(AuditEventType.allCases, id: \.self) { type in
                        Button {
                            filterEventType = type
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                if filterEventType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filterEventType?.rawValue ?? "All Events")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(darkSurface)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(filteredEntries.count) entries")
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)

                Button("Clear Log") {
                    edrService.clearAuditLog()
                }
                .font(.system(size: 12))
                .buttonStyle(SecurityButtonStyle(isDestructive: true))
            }

            // Log entries
            if filteredEntries.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.clipboard",
                    title: "No Audit Entries",
                    message: "Security events will be logged here"
                )
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(filteredEntries) { entry in
                        AuditEntryRow(entry: entry)
                    }
                }
            }
        }
    }
}

// MARK: - Audit Entry Row

private struct AuditEntryRow: View {
    let entry: AuditEntry

    private let darkSurface = Color(hex: "232426")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(textSecondary)
                .frame(width: 70, alignment: .leading)

            Circle()
                .fill(entry.severity.color)
                .frame(width: 8, height: 8)

            Text(entry.eventType.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textPrimary)
                .frame(width: 140, alignment: .leading)

            Text(entry.description)
                .font(.system(size: 11))
                .foregroundStyle(textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(darkSurface.opacity(0.5))
        .cornerRadius(4)
    }
}

// MARK: - Host Security Content

private struct HostSecurityContent: View {
    @ObservedObject var edrService: AiEDRService
    @Binding var isPerformingCheck: Bool

    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        VStack(spacing: 20) {
            // Header with scan button
            HStack {
                if let report = edrService.lastHostSecurityReport {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Scan")
                            .font(.system(size: 11))
                            .foregroundStyle(textSecondary)

                        Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 13))
                            .foregroundStyle(textPrimary)
                    }
                }

                Spacer()

                Button {
                    Task {
                        isPerformingCheck = true
                        _ = await edrService.performHostSecurityCheck()
                        isPerformingCheck = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isPerformingCheck {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Run Security Check")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(SecurityAccentButtonStyle())
                .disabled(isPerformingCheck)
            }

            if let report = edrService.lastHostSecurityReport {
                // Security Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("SECURITY STATUS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(textSecondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        SecurityCheckItem(title: "Firewall", isEnabled: report.firewallEnabled)
                        SecurityCheckItem(title: "FileVault Encryption", isEnabled: report.diskEncrypted)
                        SecurityCheckItem(title: "Gatekeeper", isEnabled: report.gatekeeperEnabled)
                        SecurityCheckItem(title: "System Integrity Protection", isEnabled: report.systemIntegrityProtection)
                    }
                }
                .padding(16)
                .background(darkSurface)
                .cornerRadius(10)

                // Suspicious Processes
                if !report.suspiciousProcesses.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("SUSPICIOUS PROCESSES")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(textSecondary)

                            Spacer()

                            Text("\(report.suspiciousProcesses.count) found")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                        }

                        ForEach(report.suspiciousProcesses) { process in
                            ProcessRow(process: process)
                        }
                    }
                    .padding(16)
                    .background(darkSurface)
                    .cornerRadius(10)
                }

                // Open Ports
                if !report.openPorts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("OPEN NETWORK PORTS")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(textSecondary)

                            Spacer()

                            Text("\(report.openPorts.count) ports")
                                .font(.system(size: 11))
                                .foregroundStyle(textSecondary)
                        }

                        LazyVStack(spacing: 4) {
                            ForEach(report.openPorts.prefix(20)) { port in
                                PortRow(port: port)
                            }
                        }
                    }
                    .padding(16)
                    .background(darkSurface)
                    .cornerRadius(10)
                }

                // Recommendations
                if !report.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RECOMMENDATIONS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(textSecondary)

                        ForEach(report.recommendations, id: \.self) { recommendation in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "lightbulb")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.yellow)

                                Text(recommendation)
                                    .font(.system(size: 12))
                                    .foregroundStyle(textPrimary)
                            }
                            .padding(10)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding(16)
                    .background(darkSurface)
                    .cornerRadius(10)
                }
            } else {
                EmptyStateView(
                    icon: "desktopcomputer",
                    title: "No Security Report",
                    message: "Run a security check to assess your system"
                )
            }
        }
    }
}

// MARK: - Security Check Item

private struct SecurityCheckItem: View {
    let title: String
    let isEnabled: Bool

    private let accent = Color(hex: "00976d")
    private let textPrimary = Color.white

    var body: some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(isEnabled ? accent : .red)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(textPrimary)

            Spacer()
        }
        .padding(12)
        .background(isEnabled ? accent.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Process Row

private struct ProcessRow: View {
    let process: ProcessInfo

    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary)

                Text("PID: \(process.pid) | User: \(process.user)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            if let reason = process.reason {
                Text(reason)
                    .font(.system(size: 10))
                    .foregroundStyle(textSecondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Port Row

private struct PortRow: View {
    let port: PortInfo

    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        HStack {
            Text("\(port.port)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(port.isSuspicious ? .orange : textPrimary)
                .frame(width: 50, alignment: .leading)

            Text(port.protocol)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(textSecondary)
                .frame(width: 40, alignment: .leading)

            Text(port.processName)
                .font(.system(size: 11))
                .foregroundStyle(textPrimary)

            Spacer()

            if port.isSuspicious {
                Text("Suspicious")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - EDR Settings Content

private struct EDRSettingsContent: View {
    @ObservedObject var edrService: AiEDRService

    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Detection Settings
            SettingsSectionCard(title: "Detection") {
                VStack(spacing: 0) {
                    SettingsToggleItem(
                        title: "Enable AiEDR",
                        subtitle: "Master switch for all security features",
                        isOn: $edrService.isEnabled
                    )

                    SettingsToggleItem(
                        title: "Auto-block Critical Threats",
                        subtitle: "Automatically block messages with critical threat level",
                        isOn: $edrService.autoBlockCritical
                    )

                    SettingsToggleItem(
                        title: "Prompt on High Threats",
                        subtitle: "Ask for confirmation before sending high-threat messages",
                        isOn: $edrService.promptOnHigh
                    )
                }
            }

            // Logging Settings
            SettingsSectionCard(title: "Audit Logging") {
                VStack(spacing: 0) {
                    SettingsToggleItem(
                        title: "Log Threats Only",
                        subtitle: "Only log security events when threats are detected",
                        isOn: $edrService.logThreatsOnly
                    )

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max Audit Entries")
                                .font(.system(size: 13))
                                .foregroundStyle(textPrimary)

                            Text("Older entries are automatically pruned")
                                .font(.system(size: 11))
                                .foregroundStyle(textSecondary)
                        }

                        Spacer()

                        Stepper("\(edrService.maxAuditEntries)", value: $edrService.maxAuditEntries, in: 1000...100000, step: 1000)
                            .labelsHidden()

                        Text("\(edrService.maxAuditEntries)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(accent)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                }
            }

            // Host Monitoring
            SettingsSectionCard(title: "Host Monitoring") {
                VStack(spacing: 0) {
                    SettingsToggleItem(
                        title: "Background Monitoring",
                        subtitle: "Periodically check host security status",
                        isOn: $edrService.backgroundMonitoring
                    )
                    .onChange(of: edrService.backgroundMonitoring) { _, newValue in
                        if newValue {
                            edrService.startBackgroundMonitoring()
                        } else {
                            edrService.stopBackgroundMonitoring()
                        }
                    }
                }
            }

            // Statistics Reset
            SettingsSectionCard(title: "Statistics") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reset threat counters and clear all alerts")
                            .font(.system(size: 12))
                            .foregroundStyle(textPrimary)

                        Text("This action cannot be undone")
                            .font(.system(size: 11))
                            .foregroundStyle(textSecondary)
                    }

                    Spacer()

                    Button("Reset All") {
                        edrService.totalDetectedThreats = 0
                        edrService.totalBlockedThreats = 0
                        edrService.activeAlerts.removeAll()
                    }
                    .font(.system(size: 12))
                    .buttonStyle(SecurityButtonStyle(isDestructive: true))
                }
            }
        }
    }
}

// MARK: - Settings Section Card

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    private let darkSurface = Color(hex: "232426")
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textSecondary)

            VStack(spacing: 0) {
                content
            }
            .padding(14)
            .background(darkSurface)
            .cornerRadius(10)
        }
    }
}

// MARK: - Settings Toggle Item

private struct SettingsToggleItem: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(textPrimary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(accent)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Empty State View

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(textSecondary.opacity(0.5))

            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Button Styles

private struct SecurityButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isDestructive ? .red : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color(hex: "2d2e30") : Color(hex: "232426"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isDestructive ? Color.red.opacity(0.3) : Color(hex: "2d2e30"), lineWidth: 1)
            )
    }
}

private struct SecurityAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color(hex: "00976d").opacity(0.8) : Color(hex: "00976d"))
            )
    }
}

// MARK: - Audit Log Document

struct AuditLogDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Audit Event Type Extension

extension AuditEventType: CaseIterable {
    nonisolated(unsafe) static var allCases: [AuditEventType] = [
        .conversationStart, .conversationEnd, .messageSent, .messageReceived,
        .threatDetected, .threatMitigated, .toolExecution, .securitySettingChanged,
        .hostSecurityCheck, .dataRedaction, .alertAcknowledged, .exportRequested
    ]
}

// MARK: - Preview

#if DEBUG
struct SecurityDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SecurityDashboardView()
            .frame(width: 800, height: 600)
    }
}
#endif
