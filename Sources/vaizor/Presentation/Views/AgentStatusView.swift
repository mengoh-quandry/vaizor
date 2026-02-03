import SwiftUI

// MARK: - Agent Status View
// Shows the agent's current state, mood, identity, and OS integration controls

struct AgentStatusView: View {
    @ObservedObject var agentService: AgentService
    @State private var showingNamePrompt = false
    @State private var showingPermissions = false

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.md) {
            // Header with avatar
            HStack {
                Image(systemName: agentService.avatarSystemIcon)
                    .font(.system(size: 24))
                    .foregroundStyle(ThemeColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(agentService.agentName ?? "Unnamed Agent")
                        .font(VaizorTypography.h3)
                        .foregroundStyle(ThemeColors.textPrimary)

                    Text(agentService.developmentStage.description)
                        .font(VaizorTypography.caption)
                        .foregroundStyle(ThemeColors.textSecondary)
                }

                Spacer()

                // Status indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(agentService.isObserving ? Color.green : ThemeColors.textSecondary)
                        .frame(width: 8, height: 8)
                    Text(agentService.isObserving ? "Observing" : "Idle")
                        .font(VaizorTypography.caption)
                        .foregroundStyle(ThemeColors.textSecondary)
                }
            }

            Divider()

            // Mood indicator
            HStack(spacing: VaizorSpacing.sm) {
                Text("Mood:")
                    .font(VaizorTypography.label)
                    .foregroundStyle(ThemeColors.textSecondary)

                MoodIndicator(mood: agentService.currentMood)

                Spacer()

                if let emotion = agentService.currentMood.dominantEmotion {
                    Text(emotion.capitalized)
                        .font(VaizorTypography.caption)
                        .foregroundStyle(ThemeColors.textSecondary)
                        .padding(.horizontal, VaizorSpacing.xs)
                        .padding(.vertical, 2)
                        .background(ThemeColors.darkSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous))
                }
            }

            // Stats row
            HStack(spacing: VaizorSpacing.lg) {
                StatItem(label: "Events", value: "\(agentService.recentEvents.count)")
                StatItem(label: "Proposals", value: "\(agentService.pendingProposals.count)")
                StatItem(label: "Tasks", value: "\(agentService.activeAppendageCount)")
            }

            Divider()

            // Observation Controls
            HStack(spacing: VaizorSpacing.sm) {
                Button {
                    if agentService.isObserving {
                        agentService.stopObserving()
                    } else {
                        agentService.startObserving()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: agentService.isObserving ? "eye.slash" : "eye")
                        Text(agentService.isObserving ? "Stop Observing" : "Start Observing")
                    }
                }
                .buttonStyle(DarkAccentButtonStyle())

                if agentService.agentName == nil {
                    Button("Name Agent") {
                        showingNamePrompt = true
                    }
                    .buttonStyle(DarkButtonStyle())
                }

                Spacer()

                Button {
                    showingPermissions = true
                } label: {
                    Image(systemName: "lock.shield")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ThemeColors.textSecondary)
            }
        }
        .padding(VaizorSpacing.md)
        .background(ThemeColors.darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous)
                .stroke(ThemeColors.darkBorder, lineWidth: 1)
        )
        .sheet(isPresented: $showingNamePrompt) {
            NameAgentSheet(agentService: agentService, isPresented: $showingNamePrompt)
        }
        .sheet(isPresented: $showingPermissions) {
            PermissionsSheet(isPresented: $showingPermissions)
        }
    }
}

// MARK: - System Context View

struct SystemContextView: View {
    @ObservedObject var agentService: AgentService

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            HStack {
                Text("System Context")
                    .font(VaizorTypography.h3)
                    .foregroundStyle(ThemeColors.textPrimary)

                Spacer()

                if agentService.isObserving {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Live")
                            .font(VaizorTypography.caption)
                            .foregroundStyle(ThemeColors.textSecondary)
                    }
                }
            }

            if !agentService.isObserving {
                Text("Start observing to see system context")
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, VaizorSpacing.lg)
            } else {
                // Current app
                ContextRow(
                    icon: "app.badge",
                    label: "Active App",
                    value: agentService.frontmostApp
                )

                // Browser tab
                if let tab = agentService.currentSystemState.currentBrowserTab {
                    ContextRow(
                        icon: "globe",
                        label: "Browser",
                        value: tab.title
                    )
                    Text(tab.url)
                        .font(VaizorTypography.caption)
                        .foregroundStyle(ThemeColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.leading, 28)
                }

                // Activity level
                ContextRow(
                    icon: agentService.isUserActive ? "figure.walk" : "moon.zzz",
                    label: "Activity",
                    value: agentService.isUserActive ? "Active" : "Idle"
                )
            }
        }
        .padding(VaizorSpacing.md)
        .background(ThemeColors.darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous))
    }
}

struct ContextRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: VaizorSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(ThemeColors.accent)
                .frame(width: 20)

            Text(label)
                .font(VaizorTypography.label)
                .foregroundStyle(ThemeColors.textSecondary)

            Spacer()

            Text(value)
                .font(VaizorTypography.body)
                .foregroundStyle(ThemeColors.textPrimary)
                .lineLimit(1)
        }
    }
}

// MARK: - Recent Events View

struct RecentEventsView: View {
    @ObservedObject var agentService: AgentService

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            HStack {
                Text("Recent Events")
                    .font(VaizorTypography.h3)
                    .foregroundStyle(ThemeColors.textPrimary)

                Spacer()

                if !agentService.recentEvents.isEmpty {
                    Text("\(agentService.recentEvents.count)")
                        .font(VaizorTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, VaizorSpacing.xs)
                        .padding(.vertical, 2)
                        .background(ThemeColors.accent)
                        .clipShape(Capsule())
                }
            }

            if agentService.recentEvents.isEmpty {
                Text("No events yet")
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, VaizorSpacing.lg)
            } else {
                ForEach(agentService.recentEvents.suffix(5).reversed()) { event in
                    EventRow(event: event)
                }
            }
        }
        .padding(VaizorSpacing.md)
        .background(ThemeColors.darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous))
    }
}

struct EventRow: View {
    let event: SystemEvent

    var body: some View {
        HStack(spacing: VaizorSpacing.sm) {
            Image(systemName: iconForEvent)
                .font(.system(size: 12))
                .foregroundStyle(colorForEvent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleForEvent)
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textPrimary)
                    .lineLimit(1)

                Text(event.timestamp, style: .relative)
                    .font(VaizorTypography.caption)
                    .foregroundStyle(ThemeColors.textSecondary)
            }

            Spacer()
        }
        .padding(VaizorSpacing.xs)
    }

    private var iconForEvent: String {
        switch event.type {
        case .browserTabChanged: return "globe"
        case .newMessageReceived: return "message"
        case .fileCreated, .downloadCompleted: return "doc.badge.plus"
        case .appSwitched: return "app.badge"
        case .userBecameActive: return "figure.walk"
        case .userBecameIdle: return "moon.zzz"
        case .screenLocked: return "lock"
        case .screenUnlocked: return "lock.open"
        default: return "circle"
        }
    }

    private var colorForEvent: Color {
        switch event.type {
        case .newMessageReceived: return .blue
        case .downloadCompleted: return .green
        case .screenLocked: return .orange
        default: return ThemeColors.accent
        }
    }

    private var titleForEvent: String {
        switch event.type {
        case .browserTabChanged:
            return "Browsing: \(event.data["title"] ?? "Unknown")"
        case .newMessageReceived:
            return "Message from \(event.data["sender"] ?? "Unknown")"
        case .downloadCompleted:
            return "Downloaded: \(event.data["fileName"] ?? "file")"
        case .fileCreated:
            return "New file: \(event.data["fileName"] ?? "file")"
        case .appSwitched:
            return "Switched to \(event.data["currentApp"] ?? "app")"
        case .userBecameActive:
            return "User became active"
        case .userBecameIdle:
            return "User went idle"
        case .screenLocked:
            return "Screen locked"
        case .screenUnlocked:
            return "Screen unlocked"
        default:
            return event.type.rawValue
        }
    }
}

// MARK: - Pending Proposals View

struct PendingProposalsView: View {
    @ObservedObject var agentService: AgentService

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            HStack {
                Text("Pending Approvals")
                    .font(VaizorTypography.h3)
                    .foregroundStyle(ThemeColors.textPrimary)

                Spacer()

                if !agentService.pendingProposals.isEmpty {
                    Text("\(agentService.pendingProposals.count)")
                        .font(VaizorTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, VaizorSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }

            if agentService.pendingProposals.isEmpty {
                Text("No pending approvals")
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, VaizorSpacing.lg)
            } else {
                ForEach(agentService.pendingProposals) { proposal in
                    ProposalCard(proposal: proposal, agentService: agentService)
                }
            }
        }
        .padding(VaizorSpacing.md)
        .background(ThemeColors.darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous))
    }
}

struct ProposalCard: View {
    let proposal: ActionProposal
    @ObservedObject var agentService: AgentService

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            // Header with risk level
            HStack {
                RiskBadge(level: proposal.riskLevel)

                Text(proposal.action.description)
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textPrimary)
                    .lineLimit(2)

                Spacer()
            }

            // Reasoning
            Text(proposal.reasoning)
                .font(VaizorTypography.caption)
                .foregroundStyle(ThemeColors.textSecondary)
                .lineLimit(2)

            // Preview content if available
            if let preview = proposal.previewContent {
                Text(preview)
                    .font(VaizorTypography.code)
                    .foregroundStyle(ThemeColors.textPrimary)
                    .padding(VaizorSpacing.xs)
                    .background(ThemeColors.darkBase)
                    .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous))
                    .lineLimit(3)
            }

            // Action buttons
            HStack(spacing: VaizorSpacing.sm) {
                Button {
                    Task {
                        await agentService.approveProposal(proposal.id)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                }
                .buttonStyle(DarkAccentButtonStyle())

                Button {
                    agentService.rejectProposal(proposal.id)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                }
                .buttonStyle(DarkButtonStyle())

                Spacer()

                Text(proposal.createdAt, style: .relative)
                    .font(VaizorTypography.caption)
                    .foregroundStyle(ThemeColors.textSecondary)
            }
        }
        .padding(VaizorSpacing.sm)
        .background(ThemeColors.darkBase)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var borderColor: Color {
        switch proposal.riskLevel {
        case .critical: return .red.opacity(0.5)
        case .high: return .orange.opacity(0.5)
        default: return ThemeColors.darkBorder
        }
    }
}

struct RiskBadge: View {
    let level: RiskLevel

    var body: some View {
        Text(level.description)
            .font(VaizorTypography.caption)
            .foregroundStyle(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var textColor: Color {
        switch level {
        case .none, .low: return ThemeColors.textPrimary
        case .medium: return .black
        case .high, .critical: return .white
        }
    }

    private var backgroundColor: Color {
        switch level {
        case .none: return ThemeColors.darkBorder
        case .low: return .green.opacity(0.3)
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Permissions Sheet

struct PermissionsSheet: View {
    @Binding var isPresented: Bool
    @StateObject private var accessibilityBridge = AccessibilityBridge.shared

    var body: some View {
        VStack(spacing: VaizorSpacing.lg) {
            HStack {
                Text("System Permissions")
                    .font(VaizorTypography.h3)
                    .foregroundStyle(ThemeColors.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(ThemeColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: VaizorSpacing.sm) {
                SystemPermissionRow(
                    title: "Accessibility",
                    description: "Read screen content, simulate input",
                    isGranted: accessibilityBridge.hasAccessibilityPermission,
                    onRequest: {
                        accessibilityBridge.requestPermission()
                    }
                )

                SystemPermissionRow(
                    title: "Automation",
                    description: "Control Safari, Messages, Finder",
                    isGranted: nil, // Check per-app
                    onRequest: {
                        accessibilityBridge.openAccessibilityPreferences()
                    }
                )

                SystemPermissionRow(
                    title: "Full Disk Access",
                    description: "Read iMessage database",
                    isGranted: nil,
                    onRequest: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                )
            }

            Spacer()

            Button("Open System Preferences") {
                accessibilityBridge.openAccessibilityPreferences()
            }
            .buttonStyle(DarkAccentButtonStyle())
        }
        .padding(VaizorSpacing.lg)
        .frame(width: 400, height: 350)
        .background(ThemeColors.darkSurface)
    }
}

struct SystemPermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool?
    let onRequest: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(description)
                    .font(VaizorTypography.caption)
                    .foregroundStyle(ThemeColors.textSecondary)
            }

            Spacer()

            if let granted = isGranted {
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Grant") {
                        onRequest()
                    }
                    .buttonStyle(DarkButtonStyle())
                }
            } else {
                Button("Check") {
                    onRequest()
                }
                .buttonStyle(DarkButtonStyle())
            }
        }
        .padding(VaizorSpacing.sm)
        .background(ThemeColors.darkBase)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
    }
}

// MARK: - Supporting Views

struct MoodIndicator: View {
    let mood: EmotionalTone

    var body: some View {
        HStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ThemeColors.darkBorder)

                    let normalizedValence = (mood.valence + 1) / 2
                    RoundedRectangle(cornerRadius: 2)
                        .fill(valenceColor)
                        .frame(width: geometry.size.width * CGFloat(normalizedValence))
                }
            }
            .frame(width: 60, height: 8)

            Circle()
                .fill(arousalColor.opacity(Double(0.3 + mood.arousal * 0.7)))
                .frame(width: 8, height: 8)
        }
    }

    private var valenceColor: Color {
        if mood.valence < -0.3 {
            return .red
        } else if mood.valence > 0.3 {
            return ThemeColors.accent
        } else {
            return .yellow
        }
    }

    private var arousalColor: Color {
        if mood.arousal > 0.7 {
            return .orange
        } else if mood.arousal < 0.3 {
            return .blue
        } else {
            return ThemeColors.accent
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(VaizorTypography.h2)
                .foregroundStyle(ThemeColors.textPrimary)

            Text(label)
                .font(VaizorTypography.caption)
                .foregroundStyle(ThemeColors.textSecondary)
        }
    }
}

struct NameAgentSheet: View {
    @ObservedObject var agentService: AgentService
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var origin = ""
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: VaizorSpacing.lg) {
            HStack {
                Text("Name Your Agent")
                    .font(VaizorTypography.h3)
                    .foregroundStyle(ThemeColors.textPrimary)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(ThemeColors.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: VaizorSpacing.xs) {
                Text("Name")
                    .font(VaizorTypography.label)
                    .foregroundStyle(ThemeColors.textSecondary)

                TextField("Enter a name...", text: $name)
                    .textFieldStyle(.plain)
                    .font(VaizorTypography.body)
                    .padding(VaizorSpacing.sm)
                    .background(ThemeColors.darkBase)
                    .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
                    .focused($isNameFocused)
            }

            VStack(alignment: .leading, spacing: VaizorSpacing.xs) {
                Text("Why this name? (optional)")
                    .font(VaizorTypography.label)
                    .foregroundStyle(ThemeColors.textSecondary)

                TextField("The story behind the name...", text: $origin)
                    .textFieldStyle(.plain)
                    .font(VaizorTypography.body)
                    .padding(VaizorSpacing.sm)
                    .background(ThemeColors.darkBase)
                    .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(DarkButtonStyle())

                Spacer()

                Button("Save") {
                    Task {
                        await agentService.setName(name, origin: origin.isEmpty ? nil : origin)
                        isPresented = false
                    }
                }
                .buttonStyle(DarkAccentButtonStyle())
                .disabled(name.isEmpty)
            }
        }
        .padding(VaizorSpacing.lg)
        .frame(width: 400, height: 300)
        .background(ThemeColors.darkSurface)
        .onAppear {
            isNameFocused = true
        }
    }
}

// MARK: - Agent Notifications Panel

struct AgentNotificationsPanel: View {
    @ObservedObject var agentService: AgentService

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.sm) {
            HStack {
                Text("Agent Notifications")
                    .font(VaizorTypography.h3)
                    .foregroundStyle(ThemeColors.textPrimary)

                Spacer()

                if !agentService.notifications.isEmpty {
                    Text("\(agentService.notifications.count)")
                        .font(VaizorTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, VaizorSpacing.xs)
                        .padding(.vertical, 2)
                        .background(ThemeColors.accent)
                        .clipShape(Capsule())
                }
            }

            if agentService.notifications.isEmpty {
                Text("No notifications")
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, VaizorSpacing.lg)
            } else {
                ForEach(agentService.notifications) { notification in
                    NotificationRow(notification: notification) {
                        Task {
                            await agentService.acknowledgeNotification(notification.id)
                        }
                    }
                }
            }
        }
        .padding(VaizorSpacing.md)
        .background(ThemeColors.darkSurface)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous))
    }
}

struct NotificationRow: View {
    let notification: AgentNotification
    let onAcknowledge: () -> Void

    var body: some View {
        HStack(spacing: VaizorSpacing.sm) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.message)
                    .font(VaizorTypography.body)
                    .foregroundStyle(ThemeColors.textPrimary)
                    .lineLimit(2)

                Text(notification.timestamp, style: .relative)
                    .font(VaizorTypography.caption)
                    .foregroundStyle(ThemeColors.textSecondary)
            }

            Spacer()

            Button {
                onAcknowledge()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(VaizorSpacing.sm)
        .background(ThemeColors.darkBase)
        .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous))
    }

    private var iconName: String {
        switch notification.type {
        case .appendageSpawned: return "sparkles"
        case .appendageCompleted: return "checkmark.circle"
        case .appendageRetracted: return "xmark.circle"
        case .appendageError: return "exclamationmark.triangle"
        case .skillAcquired: return "star"
        case .insightGained: return "lightbulb"
        case .questionForPartner: return "questionmark.circle"
        case .milestoneReached: return "flag"
        }
    }

    private var iconColor: Color {
        switch notification.priority {
        case .low: return ThemeColors.textSecondary
        case .normal: return ThemeColors.accent
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            AgentStatusView(agentService: AgentService())
            SystemContextView(agentService: AgentService())
            RecentEventsView(agentService: AgentService())
            PendingProposalsView(agentService: AgentService())
        }
        .padding()
    }
    .background(ThemeColors.darkBase)
}
