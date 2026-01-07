# Code Execution Sandbox Plan

## Goals
- Safe, predictable execution with strong isolation.
- Explicit user consent for any privileged capability.
- Auditability without leaking secrets.
- Extensible to multiple languages/runtimes.

## Architecture Overview
- **Execution Service (separate process)**: hardened runner with zero trust boundaries from the UI.
- **Broker (in-app)**: validates requests, enforces policy, proxies results back.
- **Sandbox**: OS-level sandbox (seatbelt on macOS) + process resource limits.
- **Capability model**: fine-grained, per-run permissions.
- **Artifacts store**: outputs are ephemeral unless the user explicitly saves.

## 1) Threat Model & Trust Boundaries
### Threats
- Data exfiltration (files, env, network).
- Host compromise (escape via runtime or OS).
- Abuse (crypto mining, fork bombs).
- Leakage via logs/telemetry.
- Supply chain attacks in runtimes or dependencies.

### Trust Boundaries
- UI <-> Broker (trust UI intent, not code).
- Broker <-> Runner (treat code as untrusted).
- Runner <-> Host OS (strict sandboxing).

## 2) Execution Service (Runner)
### Process Isolation
- Separate executable (not in-process).
- No access to app DB/logs.
- IPC via strict protocol (JSON-RPC or protobuf).

### Language Runtimes
- Pin versions, immutable at build time.
- Bundle runtimes or use signed, verified packages.
- Maintain a curated allowlist (Python/Node/etc).

### Resource Limits
- CPU time limit per run.
- Memory limit per run.
- Output size limit.
- File size limit.
- Process count limit.
- Hard wall-clock timeout.

## 3) Sandbox & OS Controls (macOS)
### App Sandbox + XPC
- Run code in a sandboxed XPC service.
- Default deny: no network, no file access beyond working dir.
- Explicitly grant read/write for user-selected files only.

### Filesystem
- Ephemeral working dir per run.
- No access to system/user secrets (Keychain, ~/.ssh, ~/.aws).
- Optional: snapshot temp dir to prevent persistence.

### Network
- Disabled by default.
- If enabled, restrict to allowlisted domains/ports.
- Use a per-run proxy to enforce allowlist.

### Syscall Restrictions
- Block process creation, ptrace, and dynamic library injection.
- Disable JIT unless essential for a runtime.

## 4) Capability-Based Permissions
### Capabilities
- filesystem.read
- filesystem.write
- network
- clipboard.read / clipboard.write

### UX Rules
- Explicit consent for each capability on first request.
- Show scope, duration, and files/hosts involved.
- Allow "always allow for this project" per capability.

## 5) Input/Output Guardrails
### Input
- Enforce max input size.
- Reject or warn on obviously malicious patterns.
- Normalize encoding and line endings.

### Output
- Truncate output to max size with notice.
- Redact secrets if patterns match (tokens, keys).
- Avoid echoing raw environment variables.

## 6) Logging & Privacy
### Log Metadata Only
- Runtime, duration, exit code, resource usage.
- No code content or stdout/stderr unless user opts in.

### Storage
- Logs stored in app sandbox, user can disable entirely.
- Per-run "save output" option.

## 7) Security Hardening
### Runner Validation
- Code signing and integrity checks.
- Verify runtime checksums at startup.
- Lock down environment variables.

### Defense in Depth
- App sandbox + process sandbox.
- No untrusted dynamic library loading.

### Red-Team Test Suite
- Fork bomb, infinite loop, huge allocations.
- File traversal attempts.
- Network exfiltration attempts.
- Sandbox escape attempts.

## 8) UX Integration
### Workflow
- "Run code" triggers permission preview.
- Explain what will happen and why.
- Provide a "dry run" for inspection.

### Controls
- Stop button (immediate termination).
- "Kill and clean temp files."

## 9) Extensibility
### Language Plugins
- Each language adapter defines runtime path and sandbox profile.
- Allowed modules and resource limits per language.

### MCP Tool Integration
- Code execution as a tool with a strict schema:
  - language, code, files, capabilities, timeout.
- Broker enforces capability gating regardless of tool request.

## 10) Implementation Phases
### Phase 1: Core Runner
- Single runtime (Python).
- Strict sandbox, no network.
- IPC + result handling.

### Phase 2: Capability Model
- Filesystem access with prompts.
- Network capability with domain allowlist.

### Phase 3: Multi-Runtime
- Add JS/Ruby/etc with per-runtime sandbox profiles.

### Phase 4: UX + Audit
- Permission UI, run history, export outputs.

## 11) Compliance & Safety Checklist
- No execution without explicit user action.
- No network by default.
- No persistence without opt-in.
- No secrets in logs.
- All execution paths test-covered.

---

## Review & Additional Thoughts

### Overall Assessment: 🟢 **Excellent Plan** (9/10)

This is a **well-thought-out, security-first approach** to code execution. The architecture is sound, the threat model is comprehensive, and the phased implementation is realistic. Below are additional considerations and suggestions.

---

## Strengths

### 1. Security Architecture ✅
- **Separate process isolation** is the right approach - prevents in-process vulnerabilities
- **Capability-based permissions** provide fine-grained control
- **Defense in depth** (App Sandbox + process sandbox) is excellent
- **Zero-trust model** treats all code as untrusted

### 2. Threat Model ✅
- Comprehensive threat identification
- Clear trust boundaries
- Good consideration of supply chain attacks

### 3. Implementation Phases ✅
- Phased approach is realistic and manageable
- Starting with Python is pragmatic
- Incremental feature addition reduces risk

---

## Recommendations & Enhancements

### 1. macOS-Specific Implementation Details

#### App Sandbox Entitlements
```xml
<!-- Recommended entitlements for XPC service -->
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>
<false/> <!-- Disabled by default -->
<key>com.apple.security.cs.allow-jit</key>
<false/> <!-- Disable JIT unless needed -->
<key>com.apple.security.cs.disable-library-validation</key>
<false/>
```

#### XPC Service Architecture
- Use **NSXPCConnection** for IPC (more secure than pipes/sockets)
- Implement **NSXPCListener** in runner service
- Use **NSXPCInterface** for type-safe protocol definition
- Consider **NSXPCConnectionOptions.privileged** for elevated operations (if needed)

#### Process Sandbox Profile (seatbelt)
```c
// Example seatbelt profile for code execution
(version 1)
(deny default)
(allow process-exec (literal "/usr/bin/python3"))
(allow file-read* (subpath "/tmp/vaizor-sandbox"))
(allow file-write* (subpath "/tmp/vaizor-sandbox"))
(deny network-outbound)
```

### 2. Runtime Management

#### Python Runtime Isolation
- **Virtual environments per execution** - Create isolated venv for each run
- **Pip restrictions** - Block `pip install` unless explicitly allowed
- **Module allowlist** - Whitelist safe stdlib modules, block dangerous ones (`os.system`, `subprocess`, `socket` by default)
- **Version pinning** - Bundle specific Python version, don't rely on system Python

#### JavaScript/Node Runtime
- **vm2 or isolated-vm** - Use proper VM isolation (not `eval`)
- **No require() by default** - Block module loading unless allowed
- **Timeout enforcement** - Use `worker_threads` with resource limits
- **No file system access** - Block `fs` module unless capability granted

### 3. Enhanced Capability Model

#### Additional Capabilities to Consider
```swift
enum ExecutionCapability: String, CaseIterable {
    case filesystemRead = "filesystem.read"
    case filesystemWrite = "filesystem.write"
    case network = "network"
    case clipboardRead = "clipboard.read"
    case clipboardWrite = "clipboard.write"
    case processSpawn = "process.spawn"  // For subprocess execution
    case environmentRead = "environment.read"  // Read env vars
    case systemInfo = "system.info"  // CPU, memory info
}
```

#### Capability Scoping
- **File-level granularity** - Not just "filesystem.read" but "read /path/to/file"
- **Time-bound permissions** - "Allow for 5 minutes" vs "Always allow"
- **Project/workspace scoping** - "Allow for this conversation" vs "Global"

### 4. Resource Limits (Specific Values)

#### Recommended Limits
```swift
struct ExecutionLimits {
    static let maxCPUTime: TimeInterval = 30.0  // 30 seconds
    static let maxMemory: Int = 512 * 1024 * 1024  // 512 MB
    static let maxOutputSize: Int = 10 * 1024 * 1024  // 10 MB
    static let maxFileSize: Int = 50 * 1024 * 1024  // 50 MB
    static let maxProcessCount: Int = 5
    static let maxWallClockTime: TimeInterval = 60.0  // 1 minute
    static let maxInputSize: Int = 1 * 1024 * 1024  // 1 MB
}
```

#### Resource Monitoring
- Use **DispatchSource** for CPU time monitoring
- Use **task_info** (mach_task_basic_info) for memory tracking
- Use **setrlimit** for process limits
- **SIGKILL** on timeout (not SIGTERM, which can be caught)

### 5. Secret Detection & Redaction

#### Pattern Matching
```swift
struct SecretPattern {
    static let apiKey = #"([a-zA-Z0-9]{32,})"#  // Generic API keys
    static let awsKey = #"AKIA[0-9A-Z]{16}"#  // AWS access keys
    static let privateKey = #"-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----"#
    static let token = #"token[=:]\s*([a-zA-Z0-9\-_]{20,})"#
}

func redactSecrets(in text: String) -> String {
    // Replace matches with [REDACTED]
}
```

#### Output Sanitization
- Scan stdout/stderr before displaying
- Warn user if secrets detected
- Option to "Show anyway" with explicit consent
- Log redaction events (without content)

### 6. UX Enhancements

#### Permission Request UI
```swift
struct CapabilityRequestView: View {
    let capability: ExecutionCapability
    let scope: String  // "Read /path/to/file"
    let duration: Duration  // "For this run" or "Always"
    
    var body: some View {
        VStack {
            Text("Code execution requires permission:")
            Text("\(capability.displayName)")
            Text("Scope: \(scope)")
            Text("Duration: \(duration.displayName)")
            
            HStack {
                Button("Deny") { /* ... */ }
                Button("Allow Once") { /* ... */ }
                Button("Always Allow") { /* ... */ }
            }
        }
    }
}
```

#### Execution Preview
- Show **dry-run analysis** before execution
- Display **resource estimates** (expected memory, time)
- Show **capabilities required** upfront
- **"What will this do?"** explanation

#### Real-time Monitoring
- **Progress indicator** with resource usage
- **Live output streaming** (with size limits)
- **Stop button** (immediate SIGKILL)
- **Resource usage graph** (CPU, memory over time)

### 7. Integration with Existing Features

#### MCP Tool Integration
```swift
// Add code execution as MCP tool
struct CodeExecutionTool: MCPTool {
    let name = "execute_code"
    let description = "Execute code in a sandboxed environment"
    
    func execute(
        language: String,
        code: String,
        capabilities: [ExecutionCapability],
        timeout: TimeInterval
    ) async throws -> String {
        // Broker validates capabilities
        // Runner executes in sandbox
        // Return sanitized output
    }
}
```

#### Slash Commands
- `/run python` - Quick Python execution
- `/run js` - Quick JavaScript execution
- `/run --capabilities=network` - With specific capabilities

#### Code Block Integration
- **"Run" button** on code blocks
- **Auto-detect language** from code fence
- **Inline results** display below code

### 8. Testing & Validation

#### Security Test Suite
```swift
class SandboxSecurityTests: XCTestCase {
    func testForkBomb() {
        // Attempt fork bomb, verify termination
    }
    
    func testMemoryExhaustion() {
        // Allocate huge memory, verify limit enforced
    }
    
    func testNetworkExfiltration() {
        // Attempt network access, verify blocked
    }
    
    func testFileTraversal() {
        // Attempt ../../../etc/passwd, verify blocked
    }
    
    func testSandboxEscape() {
        // Attempt various escape techniques
    }
}
```

#### Performance Benchmarks
- **Startup time** - Runner process initialization
- **IPC latency** - Request/response time
- **Resource overhead** - Memory/CPU for sandbox
- **Concurrent execution** - Multiple runs simultaneously

### 9. Error Handling & Recovery

#### Graceful Degradation
- **Runtime unavailable** - Clear error message
- **Sandbox failure** - Fallback to stricter mode
- **Resource exhaustion** - Queue requests, retry later
- **IPC failure** - Retry with exponential backoff

#### User-Friendly Errors
```swift
enum ExecutionError: LocalizedError {
    case timeoutExceeded
    case memoryLimitExceeded
    case capabilityDenied(ExecutionCapability)
    case runtimeNotFound(String)
    case sandboxFailure
    
    var errorDescription: String? {
        switch self {
        case .timeoutExceeded:
            return "Code execution exceeded time limit (30s)"
        case .memoryLimitExceeded:
            return "Code execution exceeded memory limit (512MB)"
        // ...
        }
    }
}
```

### 10. Additional Security Considerations

#### Code Injection Prevention
- **Validate code structure** before execution
- **Block dangerous patterns** (eval, exec, __import__)
- **Sanitize user input** passed to code
- **Whitelist safe operations** per language

#### Audit Logging
```swift
struct ExecutionAuditLog {
    let timestamp: Date
    let codeHash: String  // SHA256 of code
    let language: String
    let capabilities: [ExecutionCapability]
    let duration: TimeInterval
    let exitCode: Int
    let resourceUsage: ResourceUsage
    // NO code content, NO output (privacy)
}
```

#### Rate Limiting
- **Max executions per minute** (e.g., 10)
- **Max concurrent executions** (e.g., 3)
- **User-configurable limits**
- **Prevent abuse** (crypto mining, DDoS)

### 11. Implementation Complexity Estimate

#### Phase 1: Core Runner (2-3 weeks)
- XPC service setup: 3-4 days
- Python runtime integration: 4-5 days
- Sandbox configuration: 3-4 days
- IPC protocol: 2-3 days
- Testing: 3-4 days

#### Phase 2: Capability Model (1-2 weeks)
- Permission system: 3-4 days
- Filesystem access: 2-3 days
- Network capability: 2-3 days
- UI integration: 2-3 days

#### Phase 3: Multi-Runtime (2-3 weeks)
- JavaScript/Node: 1 week
- Additional languages: 1-2 weeks
- Per-runtime profiles: 3-4 days

#### Phase 4: UX + Audit (1-2 weeks)
- Permission UI: 3-4 days
- Run history: 2-3 days
- Export outputs: 1-2 days
- Documentation: 2-3 days

**Total Estimate: 6-10 weeks** (with proper testing and security review)

---

## Potential Concerns & Mitigations

### 1. macOS Sandbox Limitations
**Concern:** macOS App Sandbox can be restrictive, may limit functionality  
**Mitigation:** Use XPC service with appropriate entitlements, test thoroughly

### 2. Performance Overhead
**Concern:** Separate process + sandbox adds latency  
**Mitigation:** Optimize IPC, use connection pooling, cache runtime initialization

### 3. User Experience Friction
**Concern:** Too many permission prompts may frustrate users  
**Mitigation:** Smart defaults, "always allow" options, clear explanations

### 4. Maintenance Burden
**Concern:** Runtime updates, security patches, compatibility  
**Mitigation:** Pin versions, automated testing, clear update process

### 5. Legal/Compliance
**Concern:** Code execution liability, malicious code  
**Mitigation:** Clear terms, user consent, audit logs, disclaimers

---

## Final Recommendations

### Must-Have (Phase 1)
1. ✅ Separate XPC service (not in-process)
2. ✅ Strict resource limits (CPU, memory, time)
3. ✅ Default deny (no network, no file access)
4. ✅ Code signing & integrity checks
5. ✅ Comprehensive test suite

### Should-Have (Phase 2)
1. ✅ Capability-based permissions
2. ✅ Filesystem access with prompts
3. ✅ Secret detection & redaction
4. ✅ Audit logging (metadata only)

### Nice-to-Have (Phase 3+)
1. ⚠️ Multi-runtime support
2. ⚠️ Network capability
3. ⚠️ Advanced UX features
4. ⚠️ MCP tool integration

### Priority Order
1. **Security first** - Get sandboxing right before adding features
2. **Python only** - Start simple, expand later
3. **User consent** - Always explicit, never automatic
4. **Privacy** - No code/output in logs without opt-in

---

## Conclusion

This is an **excellent, security-first plan**. The architecture is sound, the threat model is comprehensive, and the phased approach is realistic. The main recommendations are:

1. **Use XPC services** (not raw processes) for better security
2. **Add secret detection** to prevent accidental leakage
3. **Implement resource monitoring** with specific limits
4. **Create comprehensive test suite** before launch
5. **Focus on UX** to reduce permission friction

With proper implementation, this will be a **significant competitive advantage** over Open WebUI and other competitors. The security-first approach aligns perfectly with Vaizor's privacy-focused positioning.

**Estimated Timeline:** 6-10 weeks for full implementation  
**Risk Level:** Medium (mitigated by phased approach)  
**Competitive Impact:** High (matches Open WebUI, unique in native apps)
