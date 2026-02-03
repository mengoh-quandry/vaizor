import SwiftUI

// MARK: - Agent Status View
// Shows the agent's current state, mood, and identity for testing

struct AgentStatusView: View {
    @ObservedObject var agentService: AgentService
    @State private var showingNamePrompt = false
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: VaizorSpacing.md) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
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
                Circle()
                    .fill(agentService.isInitialized ? ThemeColors.accent : ThemeColors.textSecondary)
                    .frame(width: 8, height: 8)
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

            // Stats
            HStack(spacing: VaizorSpacing.lg) {
                StatItem(label: "Active Tasks", value: "\(agentService.activeAppendageCount)")
                StatItem(label: "Notifications", value: "\(agentService.notifications.count)")
            }

            // Actions
            HStack(spacing: VaizorSpacing.sm) {
                if agentService.agentName == nil {
                    Button("Name Agent") {
                        showingNamePrompt = true
                    }
                    .buttonStyle(DarkAccentButtonStyle())
                }

                Spacer()
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
    }
}

// MARK: - Supporting Views

struct MoodIndicator: View {
    let mood: EmotionalTone

    var body: some View {
        HStack(spacing: 4) {
            // Valence bar (negative to positive)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ThemeColors.darkBorder)

                    // Fill based on valence (-1 to 1, mapped to 0-1)
                    let normalizedValence = (mood.valence + 1) / 2
                    RoundedRectangle(cornerRadius: 2)
                        .fill(valenceColor)
                        .frame(width: geometry.size.width * CGFloat(normalizedValence))
                }
            }
            .frame(width: 60, height: 8)

            // Arousal indicator (small circle that gets more intense)
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
            // Header
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

            // Name input
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

            // Origin input (optional)
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

            // Actions
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
    VStack(spacing: 20) {
        AgentStatusView(agentService: AgentService())
        AgentNotificationsPanel(agentService: AgentService())
    }
    .padding()
    .background(ThemeColors.darkBase)
}
