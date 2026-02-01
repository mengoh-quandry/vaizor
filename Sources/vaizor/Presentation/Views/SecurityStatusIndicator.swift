import SwiftUI

// MARK: - Security Status Indicator

/// Compact security status indicator for the chat interface
struct SecurityStatusIndicator: View {
    @ObservedObject private var edrService = AiEDRService.shared
    @State private var showSecurityDashboard = false
    @State private var showAlertPopover = false
    @State private var isHovering = false

    private let accent = Color(hex: "00976d")

    var body: some View {
        Button {
            showSecurityDashboard = true
        } label: {
            HStack(spacing: 6) {
                // Status icon with pulse animation for alerts
                ZStack {
                    Circle()
                        .fill(edrService.threatLevel.color.opacity(0.2))
                        .frame(width: 24, height: 24)

                    Image(systemName: edrService.threatLevel.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(edrService.threatLevel.color)

                    // Pulse animation for elevated threats
                    if edrService.threatLevel != .normal {
                        Circle()
                            .stroke(edrService.threatLevel.color, lineWidth: 1)
                            .frame(width: 24, height: 24)
                            .scaleEffect(isHovering ? 1.3 : 1.0)
                            .opacity(isHovering ? 0 : 0.5)
                            .animation(
                                Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                value: isHovering
                            )
                    }
                }

                if isHovering || edrService.threatLevel != .normal {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(edrService.isEnabled ? edrService.threatLevel.rawValue : "Disabled")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(edrService.isEnabled ? edrService.threatLevel.color : .gray)

                        if !edrService.activeAlerts.isEmpty {
                            Text("\(edrService.activeAlerts.count) alert(s)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color(hex: "808080"))
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "232426"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        edrService.threatLevel != .normal ? edrService.threatLevel.color.opacity(0.3) : Color(hex: "2d2e30"),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help("Security Status: \(edrService.threatLevel.rawValue) - Click to open Security Dashboard")
        .sheet(isPresented: $showSecurityDashboard) {
            SecurityDashboardView()
                .frame(minWidth: 700, minHeight: 500)
        }
    }
}

// MARK: - Security Alert Banner

/// Non-intrusive alert banner shown at the top of chat
struct SecurityAlertBanner: View {
    let alert: SecurityAlert
    let onDismiss: () -> Void
    let onViewDetails: () -> Void

    @State private var isVisible = false

    private let darkSurface = Color(hex: "232426")

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: alert.type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(alert.severity.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.type.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(alert.message)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "a0a0a0"))
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onViewDetails()
                } label: {
                    Text("View")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "00976d"))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "808080"))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(darkSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(alert.severity.color.opacity(0.3), lineWidth: 1)
                    )
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    init(alert: SecurityAlert, onDismiss: @escaping () -> Void, onViewDetails: @escaping () -> Void) {
        self.alert = alert
        self.onDismiss = onDismiss
        self.onViewDetails = onViewDetails
        _isVisible = State(initialValue: true)
    }
}

// MARK: - Security Warning Dialog

/// Dialog shown when a message requires user confirmation
struct SecurityWarningDialog: View {
    let analysis: ThreatAnalysis
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let darkBase = Color(hex: "1c1d1f")
    private let darkSurface = Color(hex: "232426")
    private let darkBorder = Color(hex: "2d2e30")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "808080")
    private let accent = Color(hex: "00976d")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(analysis.threatLevel.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: analysis.threatLevel.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(analysis.threatLevel.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Security Warning")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(textPrimary)

                    Text("Threat Level: \(analysis.threatLevel.rawValue)")
                        .font(.system(size: 12))
                        .foregroundStyle(analysis.threatLevel.color)
                }

                Spacer()

                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Rectangle().fill(darkBorder).frame(height: 1)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Detected Threats
                    if !analysis.alerts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Detected Issues")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(textPrimary)

                            ForEach(analysis.alerts) { alert in
                                HStack(spacing: 10) {
                                    Image(systemName: alert.type.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(alert.severity.color)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(alert.type.rawValue)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(textPrimary)

                                        Text(alert.message)
                                            .font(.system(size: 11))
                                            .foregroundStyle(textSecondary)
                                    }

                                    Spacer()

                                    Text(String(format: "%.0f%%", analysis.confidence * 100))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(textSecondary)
                                }
                                .padding(10)
                                .background(darkBorder.opacity(0.5))
                                .cornerRadius(6)
                            }
                        }
                    }

                    // Recommendations
                    if !analysis.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recommendations")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(textPrimary)

                            ForEach(analysis.recommendations, id: \.self) { recommendation in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.yellow)

                                    Text(recommendation)
                                        .font(.system(size: 12))
                                        .foregroundStyle(textSecondary)
                                }
                            }
                        }
                    }

                    // Warning message
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)

                        Text("Proceeding may expose you to security risks. Are you sure you want to continue?")
                            .font(.system(size: 12))
                            .foregroundStyle(textPrimary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(20)
            }
            .frame(maxHeight: 300)

            Rectangle().fill(darkBorder).frame(height: 1)

            // Actions
            HStack(spacing: 12) {
                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    onConfirm()
                    dismiss()
                } label: {
                    Text("Send Anyway")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding(20)
        }
        .frame(width: 450)
        .background(darkBase)
    }
}

// MARK: - Inline Security Notice

/// Small inline notice for less severe warnings
struct InlineSecurityNotice: View {
    let message: String
    let severity: ThreatLevel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: severity.icon)
                .font(.system(size: 11))
                .foregroundStyle(severity.color)

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "a0a0a0"))
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(severity.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(severity.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Security Scan Animation

/// Loading animation for security scanning
struct SecurityScanAnimation: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(hex: "00976d").opacity(0.2), lineWidth: 2)
                    .frame(width: 20, height: 20)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color(hex: "00976d"), lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }

            Text("Scanning for threats...")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: "808080"))
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Threat Analysis Result Badge

/// Badge showing analysis result
struct ThreatAnalysisBadge: View {
    let analysis: ThreatAnalysis

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: analysis.isClean ? "checkmark.shield" : analysis.threatLevel.icon)
                .font(.system(size: 10))

            Text(analysis.isClean ? "Clean" : analysis.threatLevel.rawValue)
                .font(.system(size: 10, weight: .medium))

            if !analysis.isClean {
                Text("(\(analysis.alerts.count))")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(analysis.isClean ? Color(hex: "00976d") : analysis.threatLevel.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((analysis.isClean ? Color(hex: "00976d") : analysis.threatLevel.color).opacity(0.15))
        )
    }
}

// MARK: - Message Security Metadata

/// Shows security metadata for a message
struct MessageSecurityMetadata: View {
    let wasScanned: Bool
    let threatLevel: ThreatLevel?
    let timestamp: Date

    private var displayThreatLevel: ThreatLevel {
        threatLevel ?? .normal
    }

    private var isNormalOrNil: Bool {
        threatLevel == nil || threatLevel == .normal
    }

    var body: some View {
        HStack(spacing: 8) {
            if wasScanned {
                HStack(spacing: 4) {
                    Image(systemName: isNormalOrNil ? "checkmark.shield" : displayThreatLevel.icon)
                        .font(.system(size: 9))

                    Text(isNormalOrNil ? "Scanned" : displayThreatLevel.rawValue)
                        .font(.system(size: 9))
                }
                .foregroundStyle(isNormalOrNil ? Color(hex: "00976d") : displayThreatLevel.color)
            }

            Text(timestamp.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 9))
                .foregroundStyle(Color(hex: "606060"))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SecurityStatusIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SecurityStatusIndicator()

            SecurityAlertBanner(
                alert: SecurityAlert(
                    type: .jailbreakAttempt,
                    severity: .high,
                    message: "Jailbreak attempt detected in prompt",
                    source: .userPrompt
                ),
                onDismiss: {},
                onViewDetails: {}
            )

            InlineSecurityNotice(message: "This message contains suspicious patterns", severity: .elevated)

            SecurityScanAnimation()

            ThreatAnalysisBadge(analysis: ThreatAnalysis(
                isClean: false,
                threatLevel: .elevated,
                alerts: [],
                confidence: 0.85,
                sanitizedContent: nil,
                recommendations: []
            ))
        }
        .padding()
        .background(Color(hex: "1c1d1f"))
    }
}
#endif
