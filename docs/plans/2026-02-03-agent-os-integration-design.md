# Agent OS Integration Design

## Overview

Transform the Vaizor agent from a passive responder into an always-on ambient assistant with full macOS integration. The agent continuously observes system state (iMessage, browser, file system) and proactively assists while respecting tiered autonomy controls.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Trigger model | Always-on ambient awareness |
| System access | Full Accessibility API + AppleScript |
| Autonomy | Tiered: low-risk auto, high-risk requires approval |
| Approval UI | Multi-channel with urgency tiers |
| Priority integrations | iMessage, Browser, File System |
| Browser approach | Safari native + Chromium native + Accessibility fallback |
| Observation frequency | Adaptive (1-2s active, 30s idle, paused when locked) |

---

## Architecture

### System Observation Layer

```
┌─────────────────────────────────────────────────────┐
│                   AgentService                       │
│  (existing - coordinates identity, memory, mood)     │
└─────────────────────┬───────────────────────────────┘
                      │ receives observations
┌─────────────────────▼───────────────────────────────┐
│                 SystemObserver                       │
│  - Adaptive polling loop (1s active, 30s idle)       │
│  - Publishes SystemState snapshots                   │
│  - Detects "interesting" events worth acting on      │
└─────────────────────┬───────────────────────────────┘
                      │ delegates to specialists
        ┌─────────────┼─────────────┐
        ▼             ▼             ▼
┌───────────┐  ┌───────────┐  ┌───────────┐
│ iMessage  │  │  Browser  │  │FileSystem │
│ Observer  │  │  Observer │  │ Observer  │
└───────────┘  └───────────┘  └───────────┘
```

### Adaptive Polling

The `SystemObserver` tracks user activity via `NSEvent.addGlobalMonitorForEvents` for mouse/keyboard events:
- Activity in last 60 seconds → poll every 1-2 seconds
- Idle → slow to 30 seconds
- Screen locked → pause entirely

---

## Observer Implementations

### iMessage Observer

Uses AppleScript to query Messages.app:
- Polls for new messages via `tell application "Messages" to get chats`
- Extracts sender, content, timestamp, read status
- Detects new unread messages since last poll
- Triggers agent awareness: "New message from Sarah: 'Hey, are you free tonight?'"

### Browser Observer

Three-tier approach:

1. **Safari**: AppleScript
   ```applescript
   tell application "Safari" to get {URL, name} of current tab of window 1
   ```

2. **Chromium** (Chrome/Arc/Edge/Brave): AppleScript
   ```applescript
   tell application "Google Chrome" to get {URL, title} of active tab of window 1
   ```

3. **Fallback**: Accessibility API - read window title, OCR content if needed

For page content, execute JavaScript via AppleScript:
```applescript
tell application "Safari" to do JavaScript "document.body.innerText" in current tab of window 1
```

### File System Observer

Uses `FSEvents` API (native macOS file system events):
- Watches ~/Downloads, ~/Desktop, and user-configured folders
- Detects new files, renames, deletions
- Triggers agent awareness: "New file downloaded: invoice-march-2024.pdf"

---

## Action System

### Risk Classification

| Risk Level | Examples | Behavior |
|------------|----------|----------|
| **None** | Read screen, observe browser, check messages | Silent, automatic |
| **Low** | Navigate within Vaizor, summarize content, take notes | Automatic, log only |
| **Medium** | Open app, switch tabs, organize files locally | Automatic with toast |
| **High** | Send iMessage, submit form, delete file | Requires approval |
| **Critical** | Financial transaction, password entry | Approval + confirmation |

### Action Proposal Model

```swift
struct ActionProposal: Identifiable {
    let id: UUID
    let action: ProposedAction
    let reasoning: String
    let riskLevel: RiskLevel
    let urgency: ProposalUrgency  // .routine, .timeSensitive, .urgent
    let expiresAt: Date?
    let previewContent: String?
    let createdAt: Date
}

enum ProposalUrgency {
    case routine        // In-app panel
    case timeSensitive  // System notification
    case urgent         // Floating overlay
}
```

### Execution Flow

1. Agent decides to act → creates `ActionProposal`
2. Proposal routed based on urgency:
   - `.routine` → In-app notification panel
   - `.timeSensitive` → macOS notification center
   - `.urgent` → Floating overlay
3. User approves/rejects/modifies
4. If approved → `ActionExecutor` runs via AppleScript/Accessibility
5. Result recorded in agent's episodic memory

---

## Approval UI Components

### In-App Notification Panel (Routine)

Extends existing `AgentNotificationsPanel`:
- Shows pending proposals in a queue
- Each card has: action summary, reasoning, preview, Approve/Reject buttons
- Can expand for details or modify before approving

### System Notifications (Time-Sensitive)

Uses `UNUserNotificationCenter` with actionable notifications:
- Title: "Agent wants to reply to Sarah"
- Body: Preview of draft message
- Actions: "Send", "Edit in Vaizor", "Dismiss"

### Floating Overlay (Urgent)

Small always-on-top `NSPanel`:
```
┌─────────────────────────────────┐
│ 🤖 Reply to Sarah?              │
│ "Sure, I'm free after 7pm"      │
│                                 │
│  [Approve]  [Edit]  [Dismiss]   │
└─────────────────────────────────┘
```
- Appears in configurable corner
- Quick approve/reject buttons
- Auto-dismisses after timeout
- Draggable, remembers position

### Menu Bar Status Item

Always-visible menu bar icon showing:
- Agent status (observing/idle/acting)
- Pending proposal count badge
- Click to expand: recent observations, proposals, quick settings

### Agent Avatar

Custom avatar support:
- Appears in menu bar, overlay, notifications, in-app panel
- User can set custom image or choose from built-ins
- Stored in PersonalFile

---

## macOS Permissions

### Required Entitlements

| Permission | Purpose | Request Trigger |
|------------|---------|-----------------|
| **Accessibility** | Read screen, simulate input | First observation launch |
| **Automation (per-app)** | Control Safari, Chrome, Messages | First app interaction |
| **Notifications** | System notification delivery | First high-risk proposal |
| **Full Disk Access** | Monitor folders outside sandbox | File observer setup |

### Permission Flow

1. Show explanation: "Your agent needs system access to observe and assist"
2. Guide through System Preferences → Privacy & Security
3. Verify each permission before enabling that observer
4. Gracefully degrade if denied

---

## Decision Loop

### Observation → Decision → Action Pipeline

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Observers   │────▶│  Decision    │────▶│   Action     │
│  (raw state) │     │   Engine     │     │   Executor   │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │   LLM Call   │
                     │  (reasoning) │
                     └──────────────┘
```

### Efficiency Strategy

Not every observation triggers LLM - too expensive:

1. **Filter**: Emit events only on meaningful state changes
2. **Buffer**: Collect observations over 5-10 second windows
3. **Heuristics**: Rule-based checks for obvious triggers
4. **LLM Reasoning**: Only when heuristics flag something interesting

### Context for Decisions

Each LLM decision call includes:
- Current system state snapshot
- Recent observations (last 5 minutes)
- Relevant memories from PersonalFile
- User preferences and past decisions
- Agent personality traits

---

## File Structure

### New Files

```
Sources/vaizor/Domain/Agent/
├── SystemObserver/
│   ├── SystemObserver.swift           # Main coordinator
│   ├── ActivityTracker.swift          # Idle/active detection
│   ├── iMessageObserver.swift         # Messages.app integration
│   ├── BrowserObserver.swift          # Safari/Chrome/AX fallback
│   └── FileSystemObserver.swift       # FSEvents wrapper
├── ActionSystem/
│   ├── ActionProposal.swift           # Proposal model & risk levels
│   ├── ActionExecutor.swift           # Execute approved actions
│   ├── AppleScriptBridge.swift        # Unified AppleScript interface
│   └── AccessibilityBridge.swift      # AX API wrapper
├── AgentAvatar.swift                  # Avatar management
└── AgentService.swift                 # (extend with observation hooks)

Sources/vaizor/Presentation/
├── Views/
│   ├── AgentOverlayWindow.swift       # Floating approval overlay
│   ├── AgentMenuBarItem.swift         # Status bar presence
│   ├── ActionProposalCard.swift       # In-app proposal UI
│   └── AgentAvatarPicker.swift        # Avatar selection
└── ViewModels/
    └── AgentOverlayViewModel.swift    # Overlay state

Sources/vaizor/
└── AgentAppDelegate.swift             # Menu bar lifecycle
```

### Integration Points

1. `DependencyContainer` gets `systemObserver` instance
2. `AgentService` subscribes to observer events
3. `VaizorApp` spawns menu bar item and overlay window
4. `AgentStatusView` shows live observation status

---

## Implementation Order

### Phase 1: Foundation
1. `ActivityTracker` - user idle/active detection
2. `SystemObserver` - coordinator with adaptive polling
3. `AppleScriptBridge` - unified script execution
4. `AccessibilityBridge` - AX API wrapper
5. Permission request flow

### Phase 2: Observers
1. `BrowserObserver` - Safari + Chromium + fallback
2. `FileSystemObserver` - FSEvents integration
3. `iMessageObserver` - Messages.app reading

### Phase 3: Action System
1. `ActionProposal` model and risk classification
2. `ActionExecutor` - script/AX execution
3. Wire decision loop into AgentService

### Phase 4: Approval UI
1. `ActionProposalCard` - in-app approval
2. System notifications with actions
3. `AgentOverlayWindow` - floating approvals
4. `AgentMenuBarItem` - status bar

### Phase 5: Polish
1. `AgentAvatar` - custom avatars
2. `AgentAvatarPicker` - selection UI
3. Settings for frequency, position, etc.
4. Decision heuristic refinement

---

## Success Criteria

- [ ] Agent observes browser tabs and knows what user is reading
- [ ] Agent detects new iMessages and can propose replies
- [ ] Agent notices new downloads and proposes organization
- [ ] Low-risk actions execute automatically
- [ ] High-risk actions show approval UI before executing
- [ ] Menu bar shows agent status at all times
- [ ] Overlay appears for urgent approvals
- [ ] System works with Safari, Chrome, Arc, and other browsers
- [ ] Graceful degradation when permissions denied
