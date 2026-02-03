import SwiftUI

/// Collapsible view for displaying tool calls with input/output
/// Supports both live (streaming) and persisted (ToolRun) tool calls
struct CollapsibleToolCallView: View {
    let name: String
    let input: String
    let output: String?
    let status: ToolCallStatus
    let isError: Bool

    // Retry support
    let toolCallId: UUID?
    let isRetryable: Bool
    let onRetry: ((UUID, String, String) -> Void)?

    @State private var isExpanded: Bool
    @State private var isHovered = false
    @State private var isRetrying = false
    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    /// Initialize from a LiveToolCall (streaming)
    init(toolCall: LiveToolCall, onRetry: ((UUID, String, String) -> Void)? = nil) {
        self.name = toolCall.name
        self.input = toolCall.input
        self.output = toolCall.output
        self.status = toolCall.status
        self.isError = toolCall.status == .error
        self.toolCallId = toolCall.id
        self.isRetryable = toolCall.status == .error
        self.onRetry = onRetry
        // Auto-expand errors
        self._isExpanded = State(initialValue: toolCall.status == .error)
    }

    /// Initialize from a ToolRun (persisted)
    init(toolRun: ToolRun, onRetry: ((UUID, String, String) -> Void)? = nil) {
        self.name = toolRun.toolName
        // Parse input from JSON if available
        if let inputJson = toolRun.inputJson,
           let data = inputJson.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Format common tool inputs nicely
            if let code = json["code"] as? String {
                self.input = code
            } else if let query = json["query"] as? String {
                self.input = query
            } else if let command = json["command"] as? String {
                self.input = command
            } else {
                // Fallback to pretty-printed JSON
                if let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    self.input = prettyString
                } else {
                    self.input = inputJson
                }
            }
        } else {
            self.input = toolRun.inputJson ?? ""
        }
        self.output = toolRun.outputJson
        self.status = toolRun.isError ? .error : .success
        self.isError = toolRun.isError
        self.toolCallId = toolRun.id
        self.isRetryable = toolRun.isError
        self.onRetry = onRetry
        // Auto-expand errors
        self._isExpanded = State(initialValue: toolRun.isError)
    }

    /// Direct initialization
    init(
        name: String,
        input: String,
        output: String?,
        status: ToolCallStatus,
        toolCallId: UUID? = nil,
        isRetryable: Bool = false,
        onRetry: ((UUID, String, String) -> Void)? = nil
    ) {
        self.name = name
        self.input = input
        self.output = output
        self.status = status
        self.isError = status == .error
        self.toolCallId = toolCallId
        self.isRetryable = isRetryable && status == .error
        self.onRetry = onRetry
        self._isExpanded = State(initialValue: status == .error)
    }

    private var statusColor: Color {
        status.color
    }

    private var truncatedInput: String {
        let cleaned = input.replacingOccurrences(of: "\n", with: " ")
        if cleaned.count > 50 {
            return String(cleaned.prefix(47)) + "..."
        }
        return cleaned
    }

    private var toolIcon: String {
        switch name.lowercased() {
        case "bash", "execute_shell":
            return "terminal"
        case "web_search":
            return "globe"
        case "execute_code":
            return "play.rectangle"
        case "create_artifact":
            return "wand.and.stars"
        case "browser_action":
            return "safari"
        case "get_current_time":
            return "clock"
        case "get_location":
            return "location"
        case "get_weather":
            return "cloud.sun"
        case "get_clipboard", "set_clipboard":
            return "doc.on.clipboard"
        case "get_system_info":
            return "desktopcomputer"
        default:
            return "wrench.and.screwdriver"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row (always visible) - Tahoe style
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Status indicator
                    statusIndicator

                    // Tool icon - hierarchical rendering
                    Image(systemName: toolIcon)
                        .font(.system(size: 13, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isError ? colors.error : colors.textSecondary)
                        .frame(width: 18)

                    // Tool name
                    Text(name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(colors.textPrimary)

                    // Truncated input (when collapsed)
                    if !isExpanded && !input.isEmpty {
                        Text(truncatedInput)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(colors.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Expand/collapse chevron with rotation
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colors.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isError ? colors.errorBackground : (isHovered ? colors.surfaceHover : colors.surface.opacity(0.6)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isError ? colors.error.opacity(0.35) : colors.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    // Input section
                    if !input.isEmpty {
                        codeSection(content: input, isOutput: false)
                    }

                    // Output section
                    if let output = output, !output.isEmpty {
                        Divider()
                            .padding(.horizontal, 12)

                        codeSection(content: output, isOutput: true)
                    }

                    // Retry button for failed tool calls
                    if isError && isRetryable && onRetry != nil {
                        Divider()
                            .padding(.horizontal, 12)

                        retryButton
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors.codeBlockBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isError ? colors.error.opacity(0.25) : colors.border.opacity(0.5), lineWidth: 1)
                )
                .padding(.top, 6)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if status == .running {
            // Pulsing indicator for running
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0.5)
                )
                .modifier(PulseAnimation())
        } else {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private func codeSection(content: String, isOutput: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Section label
            Text(isOutput ? "Output" : "Input")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(colors.textMuted)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // Code content
            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isOutput ? colors.textSecondary : colors.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
            .frame(maxHeight: isOutput ? 200 : 100)
        }
    }

    @ViewBuilder
    private var retryButton: some View {
        HStack {
            Spacer()

            Button {
                guard let id = toolCallId, let retry = onRetry else { return }
                isRetrying = true
                retry(id, name, input)
            } label: {
                HStack(spacing: 6) {
                    if isRetrying {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .medium))
                    }
                    Text(isRetrying ? "Retrying..." : "Retry")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(isRetrying ? colors.textMuted : colors.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(colors.accent.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .disabled(isRetrying)

            Spacer()
        }
        .padding(.vertical, 10)
    }
}

/// Pulse animation modifier for running status
private struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Running tool call
        CollapsibleToolCallView(
            name: "Bash",
            input: "git status && git log --oneline -5",
            output: nil,
            status: .running
        )

        // Successful tool call
        CollapsibleToolCallView(
            name: "web_search",
            input: "Swift concurrency best practices 2024",
            output: "Found 10 results:\n1. Apple Developer Documentation\n2. Swift Forums discussion\n3. WWDC 2024 session",
            status: .success
        )

        // Failed tool call with retry button
        CollapsibleToolCallView(
            name: "execute_code",
            input: "print(undefined_variable)",
            output: "NameError: name 'undefined_variable' is not defined",
            status: .error,
            toolCallId: UUID(),
            isRetryable: true,
            onRetry: { id, name, input in
                print("Retrying tool: \(name)")
            }
        )

        // Failed tool call without retry (non-retryable error)
        CollapsibleToolCallView(
            name: "unknown_tool",
            input: "{}",
            output: "Tool 'unknown_tool' not found",
            status: .error,
            toolCallId: UUID(),
            isRetryable: false
        )
    }
    .padding()
    .frame(width: 500)
}
