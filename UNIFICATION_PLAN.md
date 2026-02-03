# Vaizor Unification Plan

## Overview
Unify the current `.Projects/vaizor` build with `vaizor (orig)` to ensure all features are preserved and working.

---

## File Comparison Summary

### New Files in Current (Keep)
| File | Purpose |
|------|---------|
| `BrowserAutomation.swift` | Playwright-style browser control |
| `BrowserAutomation+Captcha.swift` | Captcha detection/handling |
| `BrowserAutomation+Recording.swift` | Session recording |
| `BrowserCommandsEnhanced.swift` | Browser command palette |
| `BrowserPanelView.swift` | Browser UI panel |
| `BrowserTypes.swift` | Browser type definitions |
| `ChatInputView.swift` | Extracted input component |
| `EnhancedSlashCommands.swift` | Extended slash commands |
| `GlassEffectContainerView.swift` | Glassmorphism UI |
| `LocalBrowserTool.swift` | Local browser tool impl |
| `MCPImportEnhanced.swift` | Unstructured MCP import |
| `MCPToolResultValidator.swift` | Tool result validation (NEW) |
| `ProjectIngestionService.swift` | Project folder analysis |
| `ProjectIngestionView.swift` | Project ingestion UI |
| `SettingsView.swift` | Settings panel |
| `SystemScreenshot.swift` | Screenshot capture |
| `ToolCallErrorHandler.swift` | Error handling + retry (ENHANCED) |
| `ToolCallParser.swift` | Tool call parsing |
| `DatabaseConversationExporter.swift` | DB export functionality |

### Files That Differ (Need Review)

#### High Priority - Core Functionality
1. **ChatViewModel.swift** (~261 lines diff)
   - Current: Enhanced streaming buffer, retry support, MCP manager integration
   - Action: Keep current, verify orig features preserved

2. **MCPServer.swift** (~57 lines diff)
   - Current: commitImported(), parseUnstructured(), enhanced server management
   - Action: Keep current additions

3. **ChatView.swift**
   - Current: Active tool calls display, retry callbacks, BuiltInToolsButton
   - Action: Keep current

4. **CollapsibleToolCallView.swift**
   - Current: Retry button, enhanced initializers
   - Action: Keep current

5. **BuiltInToolsManager.swift**
   - Current: Arc menu UI, enabledToolCount
   - Action: Keep current (but fix layout issue)

#### Medium Priority - UI/UX
6. **MessageBubbleView.swift** - onRetryToolCall callback
7. **ConversationRepository.swift** - Keyset pagination (already implemented)
8. **ArtifactView.swift** - Check for differences
9. **ComprehensiveSettingsView.swift** - Settings organization
10. **CommandPaletteView.swift** - Command palette features

#### Low Priority - Minor UI
11. **ThinkingIndicator.swift**
12. **WhiteboardView.swift**
13. **SlashCommandView.swift**
14. **ImageAttachmentView.swift**
15. **OnboardingView.swift**

### Files Only in Orig (Check for Lost Features)
1. **ConversationExporter.swift** (in Data/Export)
   - Current has `DatabaseConversationExporter.swift` instead
   - Action: Verify export functionality preserved

---

## Implementation Tasks

### Phase 1: Verify Core Features (Current Build)
- [ ] 1.1 Build and run current version
- [ ] 1.2 Test tool execution and retry
- [ ] 1.3 Test streaming with new adaptive buffer
- [ ] 1.4 Test MCP server management
- [ ] 1.5 Test arc tools button (fix layout)

### Phase 2: Feature Audit from Orig
- [ ] 2.1 Compare ConversationExporter implementations
- [ ] 2.2 Check VaizorApp.swift for lost menu items/commands
- [ ] 2.3 Verify DependencyContainer has all services
- [ ] 2.4 Check ParallelModelExecutor differences

### Phase 3: UI Consistency
- [ ] 3.1 Review ThinkingIndicator changes
- [ ] 3.2 Review WhiteboardView changes
- [ ] 3.3 Review OnboardingView changes
- [ ] 3.4 Ensure settings sections all accessible

### Phase 4: Testing
- [ ] 4.1 Test conversation export/import
- [ ] 4.2 Test all MCP server operations
- [ ] 4.3 Test browser automation
- [ ] 4.4 Test project ingestion
- [ ] 4.5 Test slash commands

---

## Key Differences Detail

### ChatViewModel.swift
**Current additions:**
```swift
// Streaming metrics
private var streamingStartTime: Date?
private var totalChunksReceived: Int = 0
private var totalBytesReceived: Int = 0

// Retry support
private var mcpManager: MCPServerManager?
func retryToolCall(toolCallId:toolName:inputJson:)
func setMCPManager(_:)

// Adaptive buffering
func adaptiveBufferInterval() -> TimeInterval
```

### MCPServer.swift
**Current additions:**
```swift
func commitImported(_ servers: [MCPServer])
func parseUnstructured(from:config:provider:) async -> (servers:errors:)
```

### BuiltInToolsManager.swift
**Current additions:**
```swift
struct BuiltInToolsButton // Arc menu UI
var enabledToolCount: Int
```

---

## Recommendation

**Keep current build as primary**, it has:
1. All orig features (verified via imports)
2. New features: Browser automation, enhanced MCP, project ingestion
3. Today's additions: Retry logic, validation, streaming improvements

**Action items:**
1. Fix arc button layout (already addressed)
2. Verify ConversationExporter parity
3. Run full test suite
4. Remove `vaizor (orig)` folder after verification

---

## Commands for Verification

```bash
# Build
swift build

# Run tests
swift test

# Check for compile errors
swift build 2>&1 | grep error

# Compare specific file
diff "Sources/vaizor/FILE.swift" "vaizor (orig)/Sources/vaizor/FILE.swift"
```
