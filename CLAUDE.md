# Vaizor - Claude Code Guidelines

## Project Overview
Vaizor is a macOS SwiftUI chat application with AI integration, MCP server support, security features (AiEDR), and code execution capabilities.

## Build & Test Commands
```bash
swift build              # Build the project
swift test               # Run all tests (453 tests)
./build-app.sh           # Build the app bundle
./build-app.sh --release # Build for distribution
```

## Critical SwiftUI Patterns - DO NOT VIOLATE

### 1. Never Use @StateObject with @MainActor Singletons

**WRONG - Will crash:**
```swift
struct MyView: View {
    @StateObject private var service = SomeService.shared  // CRASH!
}

@MainActor
class SomeService: ObservableObject {
    static let shared = SomeService()
}
```

**CORRECT - Use @ObservedObject for singletons:**
```swift
struct MyView: View {
    @ObservedObject private var service = SomeService.shared  // Safe
}
```

**Why:** `@StateObject` initialization can happen off the main actor, but accessing `@MainActor`-isolated static properties requires being on the main actor. This causes a crash.

**Rule:** If it's a `.shared` singleton, use `@ObservedObject`. `@StateObject` is for objects the view owns and creates.

### 2. Never Evaluate Expensive Operations in View Modifiers

**WRONG - Evaluated on every body call:**
```swift
.fileExporter(
    isPresented: $showExport,
    document: AuditLogDocument(data: service.exportData()),  // Called EVERY render!
    ...
)
```

**CORRECT - Lazy evaluation:**
```swift
@State private var exportDocument: AuditLogDocument?

Button("Export") {
    exportDocument = AuditLogDocument(data: service.exportData())
    showExport = true
}
.fileExporter(
    isPresented: $showExport,
    document: exportDocument ?? AuditLogDocument(data: Data()),
    ...
)
```

### 3. Never Mutate State in Computed Properties or View Body

**WRONG - State mutation during render:**
```swift
private var groupedItems: [Group] {
    let groups = items.grouped()
    expandedGroups.insert(groups.first!.id)  // CRASH! Mutating @State during render
    return groups
}
```

**CORRECT - Mutate in .task or .onAppear:**
```swift
.task {
    let groups = items.grouped()
    expandedGroups.insert(groups.first!.id)  // Safe - async context
}
```

### 4. Never Use Timer.scheduledTimer in SwiftUI Views

**WRONG - Memory leak, wrong thread:**
```swift
@State private var timer: Timer?

func startAnimation() {
    timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
        dots = dots + "."  // Modifying @State from background thread!
    }
}
```

**CORRECT - Use Task-based animation:**
```swift
@State private var animationTask: Task<Void, Never>?

func startAnimation() {
    animationTask = Task { @MainActor in
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }
}
```

### 5. Always Add @MainActor to Async Functions Modifying @State

**WRONG - Concurrent access:**
```swift
private func testAPIKey() async {
    isTesting = true  // May not be on main actor!
    // ... async work
    isTesting = false
}
```

**CORRECT:**
```swift
@MainActor
private func testAPIKey() async {
    isTesting = true  // Guaranteed main actor
    // ... async work
    isTesting = false
}
```

## @MainActor Services in This Codebase

These services are `@MainActor` isolated - always use `@ObservedObject` with them:
- `AiEDRService.shared`
- `MentionService.shared`
- `BrowserService.shared`
- `ExecutionBroker.shared`
- `ExtensionRegistry.shared`
- `ExtensionInstaller.shared`
- `DataRedactor.shared`
- `CostTracker.shared`
- `AppSettings.shared`
- `ProjectTemplatesManager.shared`
- `ChatImporter.shared`
- `MCPAppManager.shared`

## Database Conventions

- Uses GRDB with SQLite
- Foreign key constraints are enforced
- Tests must create parent records before child records (e.g., create conversation before message)
- In-memory databases use `MEMORY` journal mode, not `WAL`

## Security Patterns

- `SecretDetector`: Order patterns from specific to generic (AWS keys before generic API keys)
- `DataRedactor`: Test JWT patterns with complete 3-part tokens
- `AiEDR`: Detect standalone destructive commands, not just chained ones
- `MCPDiscoveryService`: Validate commands for shell injection, validate paths for traversal

## Testing

- 453 tests total
- Run `swift test` to verify changes
- Tests use in-memory databases
- Security tests verify pattern detection order matters

## Pre-commit Checklist

Before claiming any fix is complete:
1. Run `swift build` - must compile without errors
2. Run `swift test` - all 453 tests must pass
3. For UI changes, run `./build-app.sh` and manually test the feature
4. Check for `@StateObject` with `.shared` - change to `@ObservedObject`
5. Check for expensive operations in view modifiers - make them lazy
