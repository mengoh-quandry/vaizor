import SwiftUI

/// View for executing code blocks
struct CodeExecutionView: View {
    let code: String
    let language: CodeLanguage
    let conversationId: UUID

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var broker = ExecutionBroker.shared
    @State private var isExecuting = false
    @State private var result: ExecutionResult?
    @State private var error: Error?
    @State private var showCapabilityRequest = false
    @State private var pendingCapabilities: [ExecutionCapability] = []
    @State private var selectedShell: ShellType = .bash
    @State private var showShellWarning = false
    @State private var shellPermissionGranted = false

    // Adaptive colors helper
    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    /// Check if the current language is a shell
    private var isShellExecution: Bool {
        language.isShell
    }

    /// Get shell type from language
    private var shellType: ShellType? {
        language.shellType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Shell warning banner (for shell execution only)
            if isShellExecution {
                ShellWarningBanner(
                    shellType: shellType ?? .bash,
                    isPermissionGranted: shellPermissionGranted
                )
            }

            // Code preview with language indicator
            CodePreview(code: code, language: language)

            // Shell selector (if executing shell code interactively)
            if isShellExecution {
                ShellSelectorView(
                    selectedShell: $selectedShell,
                    availableShells: ShellType.availableShells
                )
            }

            // Execution controls
            HStack {
                if isShellExecution && !shellPermissionGranted {
                    // Require explicit permission for shell execution
                    Button {
                        showShellWarning = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                            Text("Grant Shell Permission")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ThemeColors.warning)
                } else {
                    Button {
                        Task {
                            await executeCode()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isExecuting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: isShellExecution ? "terminal.fill" : "play.fill")
                            }
                            Text(isExecuting ? "Running..." : (isShellExecution ? "Run Shell" : "Run Code"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isShellExecution ? ThemeColors.warning : nil)
                    .disabled(isExecuting || (isShellExecution && !(shellType?.isAvailable ?? false)))
                }

                if isExecuting {
                    Button {
                        broker.cancelAllExecutions()
                        isExecuting = false
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(ThemeColors.error)
                }

                Spacer()

                if let result = result {
                    ExecutionResultBadge(result: result)
                }
            }

            // Shell availability warning
            if isShellExecution, let shell = shellType, !shell.isAvailable {
                ShellUnavailableView(shellType: shell)
            }

            // Results
            if let result = result {
                ExecutionResultView(result: result)
            }

            if let error = error {
                ErrorView(error: error)
            }
        }
        .padding()
        .background(colors.surface.opacity(0.5))
        .cornerRadius(8)
        .sheet(isPresented: $showCapabilityRequest) {
            CapabilityRequestSheet(
                capabilities: pendingCapabilities,
                onApprove: { granted in
                    broker.grantCapabilities(
                        conversationId: conversationId,
                        capabilities: Set(granted),
                        duration: .always
                    )
                    showCapabilityRequest = false
                    Task {
                        await executeCode()
                    }
                },
                onDeny: {
                    showCapabilityRequest = false
                }
            )
        }
        .sheet(isPresented: $showShellWarning) {
            ShellPermissionSheet(
                shellType: shellType ?? .bash,
                onApprove: {
                    shellPermissionGranted = true
                    showShellWarning = false
                    // Also grant shell execution capability
                    broker.grantCapabilities(
                        conversationId: conversationId,
                        capabilities: [.shellExecution],
                        duration: .always
                    )
                },
                onDeny: {
                    showShellWarning = false
                }
            )
        }
        .onAppear {
            // Set initial shell type from language
            if let shell = language.shellType {
                selectedShell = shell
            }
        }
    }
    
    private func executeCode() async {
        isExecuting = true
        error = nil
        result = nil
        
        do {
            // Detect required capabilities from code
            let requiredCapabilities = detectRequiredCapabilities(code: code, language: language)
            
            let executionResult = try await broker.requestExecution(
                conversationId: conversationId,
                language: language,
                code: code,
                requestedCapabilities: requiredCapabilities,
                timeout: 30.0
            )
            
            result = executionResult
        } catch let execError as ExecutionError {
            if case .capabilityDenied(let capability) = execError {
                // Request permission
                pendingCapabilities = [capability]
                showCapabilityRequest = true
            } else {
                error = execError
            }
        } catch let err {
            error = err
        }
        
        isExecuting = false
    }
    
    private func detectRequiredCapabilities(code: String, language: CodeLanguage) -> [ExecutionCapability] {
        var capabilities: [ExecutionCapability] = []

        // Shell execution always requires shell capability
        if language.isShell {
            capabilities.append(.shellExecution)
        }

        // Simple heuristic detection - in production, use AST parsing
        switch language {
        case .python:
            if code.contains("open(") || code.contains("read(") || code.contains("readfile") {
                capabilities.append(.filesystemRead)
            }
            if code.contains("write(") || code.contains("save(") || code.contains("open(") && code.contains("w") {
                capabilities.append(.filesystemWrite)
            }
            if code.contains("requests.") || code.contains("urllib") || code.contains("http") {
                capabilities.append(.network)
            }
            // Detect subprocess usage for process spawn capability
            let processPatterns = ["subprocess", "Popen"]
            for pattern in processPatterns {
                if code.contains(pattern) {
                    capabilities.append(.processSpawn)
                    break
                }
            }

        case .javascript:
            if code.contains("require('fs')") || code.contains("readFile") {
                capabilities.append(.filesystemRead)
            }
            if code.contains("writeFile") || code.contains("createWriteStream") {
                capabilities.append(.filesystemWrite)
            }
            if code.contains("fetch") || code.contains("http") || code.contains("axios") {
                capabilities.append(.network)
            }

        case .bash, .zsh:
            // Detect shell-specific capabilities
            if code.contains("cat ") || code.contains("less ") || code.contains("head ") || code.contains("tail ") {
                capabilities.append(.filesystemRead)
            }
            if code.contains(">") || code.contains("tee ") || code.contains("mv ") || code.contains("cp ") {
                capabilities.append(.filesystemWrite)
            }
            if code.contains("curl ") || code.contains("wget ") || code.contains("nc ") {
                capabilities.append(.network)
            }

        case .powershell:
            // PowerShell-specific capability detection
            if code.contains("Get-Content") || code.contains("Import-") || code.contains("Read-") {
                capabilities.append(.filesystemRead)
            }
            if code.contains("Set-Content") || code.contains("Out-File") || code.contains("Export-") {
                capabilities.append(.filesystemWrite)
            }
            if code.contains("Invoke-WebRequest") || code.contains("Invoke-RestMethod") || code.contains("Net.WebClient") {
                capabilities.append(.network)
            }

        case .swift:
            // Swift capabilities detection
            break

        case .html, .css, .react:
            // Web content - may need network for external resources
            if code.contains("http://") || code.contains("https://") {
                capabilities.append(.network)
            }
        }

        return capabilities
    }
}

// MARK: - Shell Warning Banner

struct ShellWarningBanner: View {
    let shellType: ShellType
    let isPermissionGranted: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isPermissionGranted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(isPermissionGranted ? colors.success : colors.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(isPermissionGranted ? "Shell Execution Enabled" : "Shell Execution Warning")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)

                Text(isPermissionGranted
                     ? "Running \(shellType.displayName) commands with restricted permissions"
                     : "Shell commands can modify your system. Dangerous commands are blocked.")
                    .font(.system(size: 11))
                    .foregroundStyle(colors.textSecondary)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPermissionGranted ? colors.successBackground : colors.warningBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isPermissionGranted ? colors.success.opacity(0.3) : colors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Shell Selector View

struct ShellSelectorView: View {
    @Binding var selectedShell: ShellType
    let availableShells: [ShellType]

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("Shell:")
                .font(.system(size: 12))
                .foregroundStyle(colors.textSecondary)

            ForEach(ShellType.allCases, id: \.self) { shell in
                Button {
                    if shell.isAvailable {
                        selectedShell = shell
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: shellIcon(for: shell))
                            .font(.system(size: 10))
                        Text(shell.displayName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selectedShell == shell ? colors.accent.opacity(0.2) : colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(selectedShell == shell ? colors.accent : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!shell.isAvailable)
                .opacity(shell.isAvailable ? 1.0 : 0.5)
                .help(shell.isAvailable ? "Use \(shell.displayName)" : shell.installationInstructions)
            }
        }
    }

    private func shellIcon(for shell: ShellType) -> String {
        switch shell {
        case .bash: return "terminal"
        case .zsh: return "terminal.fill"
        case .powershell: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Shell Unavailable View

struct ShellUnavailableView: View {
    let shellType: ShellType

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(colors.error)
                Text("\(shellType.displayName) Not Available")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)
            }

            Text(shellType.installationInstructions)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(colors.textSecondary)
                .padding(8)
                .background(colors.surface)
                .cornerRadius(4)
        }
        .padding(10)
        .background(colors.errorBackground)
        .cornerRadius(6)
    }
}

// MARK: - Shell Permission Sheet

struct ShellPermissionSheet: View {
    let shellType: ShellType
    let onApprove: () -> Void
    let onDeny: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(colors.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shell Execution Permission")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(colors.textPrimary)
                        Text("This action requires elevated permissions")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(colors.background)

            Rectangle().fill(colors.border).frame(height: 1)

            // Warning content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Risk warning
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(colors.error)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Security Warning")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(colors.textPrimary)

                            Text("Shell execution allows running system commands that could:")
                                .font(.system(size: 12))
                                .foregroundStyle(colors.textSecondary)

                            VStack(alignment: .leading, spacing: 4) {
                                riskItem("Modify or delete files on your system")
                                riskItem("Access sensitive data")
                                riskItem("Install software or make system changes")
                                riskItem("Potentially compromise system security")
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(colors.error.opacity(0.1))
                    .cornerRadius(8)

                    // Safety measures
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Built-in Safety Measures")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(colors.textPrimary)

                        safetyItem("Dangerous commands blocked (sudo, rm -rf, chmod 777, etc.)")
                        safetyItem("30-second execution timeout")
                        safetyItem("Sandboxed environment with limited PATH")
                        safetyItem("No access to shell history or profiles")
                        safetyItem("Output size limits enforced")
                    }
                    .padding(12)
                    .background(colors.accent.opacity(0.1))
                    .cornerRadius(8)

                    // Shell info
                    HStack(spacing: 8) {
                        Image(systemName: "terminal.fill")
                            .foregroundStyle(colors.textSecondary)
                        Text("Executing with: \(shellType.displayName)")
                            .font(.system(size: 12))
                            .foregroundStyle(colors.textSecondary)
                        Spacer()
                        if shellType.isAvailable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(colors.accent)
                        }
                    }
                    .padding(10)
                    .background(colors.surface)
                    .cornerRadius(6)
                }
                .padding(20)
            }
            .background(colors.background)

            Rectangle().fill(colors.border).frame(height: 1)

            // Footer
            HStack {
                Button("Deny") {
                    onDeny()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(colors.textSecondary)

                Spacer()

                Button {
                    onApprove()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield")
                        Text("Allow Shell Execution")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.warning)
            }
            .padding(20)
            .background(colors.background)
        }
        .frame(width: 500, height: 520)
        .background(colors.background)
    }

    @ViewBuilder
    private func riskItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundStyle(colors.error)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(colors.textSecondary)
        }
    }

    @ViewBuilder
    private func safetyItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(colors.accent)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(colors.textSecondary)
        }
    }
}

// MARK: - Supporting Views

struct CodePreview: View {
    let code: String
    let language: CodeLanguage

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language header
            HStack(spacing: 6) {
                Image(systemName: languageIcon)
                    .font(.system(size: 10))
                Text(language.displayName)
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                if language.isShell {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                        Text("Shell")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(colors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colors.warningBackground)
                    .cornerRadius(4)
                }
            }
            .foregroundStyle(colors.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(colors.codeBlockHeaderBackground)

            // Code content with syntax highlighting
            ScrollView([.horizontal, .vertical]) {
                highlightedCode
                    .font(.system(size: 12, design: .monospaced))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .background(colors.codeBlockBackground)
        }
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(language.isShell ? colors.warning.opacity(0.3) : colors.border, lineWidth: 1)
        )
    }

    private var languageIcon: String {
        switch language {
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .javascript: return "curlybraces"
        case .swift: return "swift"
        case .html: return "chevron.left.slash.chevron.right"
        case .css: return "paintbrush"
        case .react: return "atom"
        case .bash: return "terminal"
        case .zsh: return "terminal.fill"
        case .powershell: return "chevron.left.forwardslash.chevron.right"
        }
    }

    /// Basic syntax highlighting for shell commands
    @ViewBuilder
    private var highlightedCode: some View {
        if language.isShell {
            ShellSyntaxHighlighter(code: code, shellType: language.shellType ?? .bash)
        } else {
            Text(code)
                .foregroundStyle(colors.textPrimary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Shell Syntax Highlighter

struct ShellSyntaxHighlighter: View {
    let code: String
    let shellType: ShellType

    var body: some View {
        Text(highlightedText)
            .textSelection(.enabled)
    }

    private var highlightedText: AttributedString {
        var attributedString = AttributedString(code)

        // Use centralized code syntax colors
        let commandColor = CodeSyntaxColors.command
        let stringColor = CodeSyntaxColors.string
        let variableColor = CodeSyntaxColors.variable
        let commentColor = CodeSyntaxColors.comment
        let keywordColor = CodeSyntaxColors.keyword
        let flagColor = CodeSyntaxColors.flag
        let operatorColor = CodeSyntaxColors.operator

        // Highlight patterns based on shell type
        let patterns: [(String, Color)] = getPatterns(for: shellType)

        for (pattern, color) in patterns {
            do {
                let regex = try Regex(pattern)
                for match in code.matches(of: regex) {
                    if let range = Range(match.range, in: attributedString) {
                        attributedString[range].foregroundColor = color
                    }
                }
            } catch {
                // Skip invalid patterns
            }
        }

        return attributedString
    }

    private func getPatterns(for shell: ShellType) -> [(String, Color)] {
        let commandColor = CodeSyntaxColors.command
        let stringColor = CodeSyntaxColors.string
        let variableColor = CodeSyntaxColors.variable
        let commentColor = CodeSyntaxColors.comment
        let keywordColor = CodeSyntaxColors.keyword
        let flagColor = CodeSyntaxColors.flag

        var patterns: [(String, Color)] = []

        switch shell {
        case .bash, .zsh:
            patterns = [
                // Comments
                (#"#.*$"#, commentColor),
                // Strings (double and single quoted)
                (#"\"[^\"]*\""#, stringColor),
                (#"'[^']*'"#, stringColor),
                // Variables
                (#"\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?"#, variableColor),
                (#"\$[0-9]"#, variableColor),
                // Flags
                (#"\s-[a-zA-Z]+"#, flagColor),
                (#"\s--[a-zA-Z-]+"#, flagColor),
                // Keywords
                (#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|exit)\b"#, keywordColor),
                // Common commands
                (#"^\s*(echo|ls|cd|pwd|cat|grep|sed|awk|find|sort|uniq|head|tail|wc|date|whoami|mkdir|cp|mv)\b"#, commandColor),
            ]

        case .powershell:
            patterns = [
                // Comments
                (#"#.*$"#, commentColor),
                // Strings
                (#"\"[^\"]*\""#, stringColor),
                (#"'[^']*'"#, stringColor),
                // Variables
                (#"\$[a-zA-Z_][a-zA-Z0-9_]*"#, variableColor),
                // Parameters
                (#"\s-[a-zA-Z]+"#, flagColor),
                // Keywords
                (#"\b(if|else|elseif|switch|foreach|for|while|do|until|break|continue|return|exit|function|param|begin|process|end)\b"#, keywordColor),
                // Cmdlets
                (#"\b(Get|Set|New|Remove|Add|Clear|Write|Read|Out|Import|Export|Invoke|Start|Stop|Select|Where|Sort|Group|Format)-[a-zA-Z]+"#, commandColor),
            ]
        }

        return patterns
    }
}

struct ExecutionResultView: View {
    let result: ExecutionResult

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.stdout.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Output", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(colors.textSecondary)
                    ScrollView {
                        Text(result.stdout)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(colors.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                    .padding(8)
                    .background(colors.codeBlockBackground)
                    .cornerRadius(4)
                }
            }

            if !result.stderr.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Errors", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    ScrollView {
                        Text(result.stderr)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(colors.warning)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(8)
                    .background(colors.warningBackground)
                    .cornerRadius(4)
                }
            }

            if result.secretsDetected {
                HStack {
                    Image(systemName: "exclamationmark.shield")
                    Text("Secrets detected in output and redacted")
                }
                .font(.caption)
                .foregroundStyle(colors.warning)
                .padding(8)
                .background(colors.warningBackground)
                .cornerRadius(4)
            }

            if result.wasTruncated {
                HStack {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    Text("Output truncated (max size exceeded)")
                }
                .font(.caption)
                .foregroundStyle(colors.textSecondary)
            }

            // Resource usage
            HStack(spacing: 16) {
                Label("\(String(format: "%.2f", result.duration))s", systemImage: "clock")
                Label("\(formatBytes(result.resourceUsage.memoryBytes))", systemImage: "memorychip")
                Label("Exit: \(result.exitCode)", systemImage: result.exitCode == 0 ? "checkmark.circle" : "xmark.circle")
            }
            .font(.caption)
            .foregroundStyle(colors.textSecondary)
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

struct ExecutionResultBadge: View {
    let result: ExecutionResult

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.exitCode == 0 ? colors.success : colors.error)
            Text(result.exitCode == 0 ? "Success" : "Failed")
                .font(.caption)
                .foregroundStyle(colors.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(colors.surface)
        .cornerRadius(4)
    }
}

struct ErrorView: View {
    let error: Error

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        // Check if this is a blocked shell command error
        if let execError = error as? ExecutionError,
           case .dangerousShellCommand(let reason) = execError {
            BlockedCommandView(reason: reason)
        } else {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(colors.error)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(colors.textPrimary)
            }
            .padding(8)
            .background(colors.errorBackground)
            .cornerRadius(4)
        }
    }
}

// MARK: - Blocked Command View

struct BlockedCommandView: View {
    let reason: String

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(colors.error)
                Text("Command Blocked")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)
            }

            // Reason
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "shield.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.error)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Security violation detected:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(colors.textSecondary)
                    Text(reason)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(colors.error)
                }
            }

            // Explanation
            VStack(alignment: .leading, spacing: 6) {
                Text("This command pattern is blocked because it could:")
                    .font(.system(size: 11))
                    .foregroundStyle(colors.textSecondary)

                VStack(alignment: .leading, spacing: 3) {
                    blockedReasonItem("Damage or delete important files")
                    blockedReasonItem("Compromise system security")
                    blockedReasonItem("Escalate privileges without authorization")
                    blockedReasonItem("Access sensitive user data")
                }
            }

            // Helpful hint
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.info)
                Text("Try using a safer alternative or run the command in your system terminal with proper precautions.")
                    .font(.system(size: 10))
                    .foregroundStyle(colors.textSecondary)
            }
            .padding(8)
            .background(colors.infoBackground)
            .cornerRadius(4)
        }
        .padding(12)
        .background(colors.errorBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colors.error.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func blockedReasonItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(colors.error)
                .padding(.top, 3)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(colors.textSecondary)
        }
    }
}

// MARK: - Shell Blocked Commands Info View

struct ShellBlockedCommandsInfoView: View {
    @State private var isExpanded = false

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 12))
                    Text("Blocked Commands")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundStyle(colors.textSecondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    blockedCategory("Destructive Operations", items: ["rm -rf", "mkfs", "dd of=/dev"])
                    blockedCategory("Privilege Escalation", items: ["sudo", "su", "doas"])
                    blockedCategory("Permission Changes", items: ["chmod 777", "chown -R root"])
                    blockedCategory("Network Attacks", items: ["nc -l", "/dev/tcp"])
                    blockedCategory("System Modification", items: ["crontab", "~/.bashrc", "~/.zshrc"])
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(colors.surface)
        .cornerRadius(6)
    }

    @ViewBuilder
    private func blockedCategory(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(colors.textSecondary)

            HStack(spacing: 4) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(colors.error)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(colors.errorBackground)
                        .cornerRadius(3)
                }
            }
        }
    }
}

struct CapabilityRequestSheet: View {
    let capabilities: [ExecutionCapability]
    let onApprove: ([ExecutionCapability]) -> Void
    let onDeny: () -> Void

    @State private var selectedCapabilities: Set<ExecutionCapability> = []

    @Environment(\.colorScheme) private var colorScheme

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 24))
                        .foregroundStyle(colors.warning)
                    Text("Permission Required")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(colors.textPrimary)
                }

                Text("The code you're trying to run requires the following permissions:")
                    .font(.system(size: 12))
                    .foregroundStyle(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(colors.background)

            Rectangle().fill(colors.border).frame(height: 1)

            // Capabilities list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(capabilities, id: \.self) { capability in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(capability.displayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(colors.textPrimary)
                                Text(capability.description)
                                    .font(.system(size: 11))
                                    .foregroundStyle(colors.textSecondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { selectedCapabilities.contains(capability) },
                                set: { isOn in
                                    if isOn {
                                        selectedCapabilities.insert(capability)
                                    } else {
                                        selectedCapabilities.remove(capability)
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .tint(colors.accent)
                        }
                        .padding(12)
                        .background(colors.surface)
                        .cornerRadius(8)
                    }
                }
                .padding(20)
            }
            .background(colors.background)

            Rectangle().fill(colors.border).frame(height: 1)

            // Footer
            HStack {
                Button("Deny") {
                    onDeny()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(colors.textSecondary)

                Spacer()

                Button("Allow Selected") {
                    onApprove(Array(selectedCapabilities))
                }
                .buttonStyle(.borderedProminent)
                .tint(colors.accent)
                .disabled(selectedCapabilities.isEmpty)
            }
            .padding(20)
            .background(colors.background)
        }
        .frame(width: 500, height: 400)
        .background(colors.background)
        .onAppear {
            selectedCapabilities = Set(capabilities)
        }
    }
}
