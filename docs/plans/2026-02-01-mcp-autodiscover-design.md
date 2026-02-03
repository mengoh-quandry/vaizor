# MCP Server Autodiscover Feature Design

**Date:** 2026-02-01
**Status:** Approved
**Goal:** One-click import of MCP servers from external config files

---

## Overview

Add autodiscover functionality to scan known MCP config locations (Claude Desktop, Cursor, VS Code/Cline, Claude Code) and allow users to selectively import servers into Vaizor.

## Data Model Changes

### MCPServer Model Extension

```swift
struct MCPServer: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let command: String
    let args: [String]
    let path: URL?
    let env: [String: String]?            // NEW
    let workingDirectory: String?         // NEW
    let sourceConfig: DiscoverySource?    // NEW
}

enum DiscoverySource: String, Codable {
    case manual
    case claudeDesktop
    case cursor
    case claudeCode
    case vscode
    case dotfile
}
```

### Database Migration

Add columns to `mcp_servers` table:
- `env TEXT` (JSON-encoded dictionary)
- `working_directory TEXT`
- `source_config TEXT`

---

## Discovery Service

### DiscoveredServer Model

```swift
struct DiscoveredServer: Identifiable {
    let id: String                    // hash of command+args
    let name: String                  // config key
    let command: String
    let args: [String]
    let env: [String: String]?
    let workingDirectory: String?
    let source: DiscoverySource
    let sourcePath: String
    var isAlreadyImported: Bool
}
```

### Config Locations

| Source | Path | Format |
|--------|------|--------|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `{ "mcpServers": { ... } }` |
| Cursor | `~/.cursor/mcp.json` | Same format |
| Claude Code | `~/.claude/settings.json` | MCP section |
| VS Code Cline | `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` | Similar |
| Project dotfiles | `./.mcp.json` | Same format |

### Duplicate Detection

Hash `command + sorted(args)` to match against existing servers.

---

## UI Design

### Discovery Sheet

```
┌─────────────────────────────────────────────────────────┐
│  Discover MCP Servers                              [X]  │
├─────────────────────────────────────────────────────────┤
│  Found 14 servers from 2 sources                        │
│                                                         │
│  ┌─ Cursor (13 servers) ──────────────────────────────┐ │
│  │ ☑ excalidraw          Python   ~/.cursor/mcp.json  │ │
│  │ ☑ huntress            Python                       │ │
│  │ ☐ wirespeed-cases     Python   (Already added)     │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
│  [Select All]  [Select None]         [Import Selected]  │
└─────────────────────────────────────────────────────────┘
```

### Integration Points

1. **Settings:** "Discover Servers" button in MCPSettingsView
2. **Onboarding:** Prompt when no servers configured and servers found

---

## Implementation Files

| File | Action |
|------|--------|
| `MCPServer.swift` | Add env, workingDirectory, sourceConfig fields |
| `MCPServerRecord.swift` | Add columns, update mapping |
| `Migrations.swift` | Add migration for new columns |
| `MCPDiscoveryService.swift` | NEW - scanning logic |
| `MCPDiscoveryView.swift` | NEW - discovery sheet UI |
| `MCPSettingsView.swift` | Add "Discover Servers" button |
| `OnboardingView.swift` | Add discovery prompt |
| `MCPServerConnection` | Pass env/cwd to Process |

---

## Error Handling

- Invalid JSON → Skip file, log warning
- Missing command → Show but mark "Command not found"
- Permission denied → Error toast with fix suggestion
