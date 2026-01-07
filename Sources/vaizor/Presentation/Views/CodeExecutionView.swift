import SwiftUI

/// View for executing code blocks
struct CodeExecutionView: View {
    let code: String
    let language: CodeLanguage
    let conversationId: UUID
    
    @StateObject private var broker = ExecutionBroker.shared
    @State private var isExecuting = false
    @State private var result: ExecutionResult?
    @State private var error: Error?
    @State private var showCapabilityRequest = false
    @State private var pendingCapabilities: [ExecutionCapability] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Code preview
            CodePreview(code: code, language: language)
            
            // Execution controls
            HStack {
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
                            Image(systemName: "play.fill")
                        }
                        Text(isExecuting ? "Running..." : "Run Code")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExecuting)
                
                if isExecuting {
                    Button {
                        // Stop execution (would need cancellation support)
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if let result = result {
                    ExecutionResultBadge(result: result)
                }
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
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
            if code.contains("subprocess") || code.contains("os.system") {
                capabilities.append(.processSpawn)
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
        case .swift:
            // Swift capabilities detection
            break
        }
        
        return capabilities
    }
}

// MARK: - Supporting Views

struct CodePreview: View {
    let code: String
    let language: CodeLanguage
    
    var body: some View {
        ScrollView(.horizontal) {
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 200)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(4)
    }
}

struct ExecutionResultView: View {
    let result: ExecutionResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !result.stdout.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Output", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(result.stdout)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
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
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
            if result.secretsDetected {
                HStack {
                    Image(systemName: "exclamationmark.shield")
                    Text("Secrets detected in output and redacted")
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(4)
            }
            
            if result.wasTruncated {
                HStack {
                    Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    Text("Output truncated (max size exceeded)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            // Resource usage
            HStack(spacing: 16) {
                Label("\(String(format: "%.2f", result.duration))s", systemImage: "clock")
                Label("\(formatBytes(result.resourceUsage.memoryBytes))", systemImage: "memorychip")
                Label("Exit: \(result.exitCode)", systemImage: result.exitCode == 0 ? "checkmark.circle" : "xmark.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.exitCode == 0 ? .green : .red)
            Text(result.exitCode == 0 ? "Success" : "Failed")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
    }
}

struct ErrorView: View {
    let error: Error
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error.localizedDescription)
                .font(.caption)
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(4)
    }
}

struct CapabilityRequestSheet: View {
    let capabilities: [ExecutionCapability]
    let onApprove: ([ExecutionCapability]) -> Void
    let onDeny: () -> Void
    
    @State private var selectedCapabilities: Set<ExecutionCapability> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Code Execution Requires Permissions")
                .font(.headline)
            
            Text("The code you're trying to run requires the following permissions:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            ForEach(capabilities, id: \.self) { capability in
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(capability.displayName, isOn: Binding(
                        get: { selectedCapabilities.contains(capability) },
                        set: { isOn in
                            if isOn {
                                selectedCapabilities.insert(capability)
                            } else {
                                selectedCapabilities.remove(capability)
                            }
                        }
                    ))
                    Text(capability.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack {
                Button("Deny") {
                    onDeny()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Allow") {
                    onApprove(Array(selectedCapabilities))
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCapabilities.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            selectedCapabilities = Set(capabilities)
        }
    }
}
