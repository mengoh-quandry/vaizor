import SwiftUI

/// Displays active MCP tool progress indicators
struct ToolProgressView: View {
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        let activeProgress = container.mcpManager.activeProgress.values.sorted { $0.progressToken < $1.progressToken }

        if !activeProgress.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(activeProgress, id: \.progressToken) { progress in
                    ToolProgressCard(progress: progress) {
                        // Cancel this progress (if we had the request ID)
                        // For now, we can't cancel individual progress items without tracking request IDs
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ThemeColors.darkSurface.opacity(0.95))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Individual tool progress card
struct ToolProgressCard: View {
    let progress: MCPProgress
    let onCancel: () -> Void

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Animated icon
            Image(systemName: "gearshape.2")
                .font(.system(size: 16))
                .foregroundStyle(ThemeColors.accent)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    .linear(duration: 2).repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .onAppear { isAnimating = true }

            VStack(alignment: .leading, spacing: 4) {
                // Tool name
                Text("Running tool...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)

                // Progress bar or indeterminate indicator
                if let total = progress.total {
                    ProgressView(value: progress.progress, total: total)
                        .progressViewStyle(.linear)
                        .tint(ThemeColors.accent)
                        .frame(maxWidth: 200)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(ThemeColors.accent)
                        .frame(maxWidth: 200)
                }
            }

            Spacer()

            // Cancel button (if enabled)
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ThemeColors.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Cancel operation")
        }
        .padding(12)
        .background(ThemeColors.darkBase)
        .cornerRadius(8)
    }
}

/// Compact inline tool progress indicator for message bubbles
struct InlineToolProgress: View {
    let toolName: String
    let isRunning: Bool
    let progress: Double?

    @State private var dots = ""
    @State private var isRotating = false
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 8) {
            if isRunning {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeColors.accent)
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isRotating)
                    .onAppear { isRotating = true }
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeColors.accent)
            }

            Text(isRunning ? "Running \(toolName)\(dots)" : "Completed \(toolName)")
                .font(.system(size: 11))
                .foregroundStyle(ThemeColors.textSecondary)

            if isRunning, let progress = progress {
                Text("(\(Int(progress * 100))%)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ThemeColors.textSecondary.opacity(0.7))
            }
        }
        .onAppear {
            if isRunning {
                startDotsAnimation()
            }
        }
        .onDisappear {
            stopDotsAnimation()
        }
        .onChange(of: isRunning) { _, running in
            if running {
                startDotsAnimation()
                isRotating = true
            } else {
                stopDotsAnimation()
                dots = ""
                isRotating = false
            }
        }
    }

    private func startDotsAnimation() {
        stopDotsAnimation()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                if !Task.isCancelled {
                    dots = dots.count >= 3 ? "" : dots + "."
                }
            }
        }
    }

    private func stopDotsAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }
}

/// Tool execution status banner shown at the top of chat
struct ToolExecutionBanner: View {
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var activeToolCount: Int {
        container.mcpManager.activeProgress.count
    }

    var body: some View {
        if activeToolCount > 0 {
            HStack(spacing: 10) {
                if !reduceMotion {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(ThemeColors.accent)
                } else {
                    Image(systemName: "gearshape.2")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColors.accent)
                }

                Text("\(activeToolCount) tool\(activeToolCount == 1 ? "" : "s") running")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)

                Spacer()

                Button {
                    Task {
                        await container.mcpManager.cancelAllRequests()
                    }
                } label: {
                    Text("Cancel All")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ThemeColors.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(ThemeColors.accent.opacity(0.1))
            .overlay(
                Rectangle()
                    .fill(ThemeColors.accent)
                    .frame(height: 2),
                alignment: .bottom
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#Preview {
    VStack {
        ToolExecutionBanner()
        Spacer()
        ToolProgressView()
    }
    .frame(width: 400, height: 300)
    .background(ThemeColors.darkBase)
}
