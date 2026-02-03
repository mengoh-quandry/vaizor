# Vaizor

**The power user's AI chat client for macOS.**

Vaizor is a native macOS application that brings together the best AI models with advanced security, automation, and productivity features. Built with SwiftUI for a premium, native experience.

![macOS 14.0+](https://img.shields.io/badge/macOS-14.0+-blue.svg)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

---

## Screenshots

<!-- Add screenshots here -->
| Chat Interface | Security Dashboard | MCP Integration |
|:--------------:|:------------------:|:---------------:|
| *Coming soon*  | *Coming soon*      | *Coming soon*   |

---

## Features

### Multi-Provider LLM Support
- **Anthropic Claude** - Full support including Claude 3.5 Sonnet, Opus, and Haiku
- **OpenAI** - GPT-4, GPT-4 Turbo, GPT-3.5 Turbo
- **Google Gemini** - Gemini Pro and Gemini Pro Vision
- **Ollama** - Run local models with zero cloud dependency
- **Custom Providers** - Connect to any OpenAI-compatible API

### Model Context Protocol (MCP) Integration
- Full MCP server support for extensible tool use
- Automatic server discovery and management
- Built-in tools: file operations, web browsing, code execution
- Progress tracking for long-running MCP operations

### AiEDR - AI Endpoint Detection & Response
Vaizor includes a unique security layer that monitors AI interactions for threats:
- **Prompt Injection Detection** - Blocks jailbreak attempts and instruction overrides
- **Data Exfiltration Prevention** - Detects attempts to leak sensitive data
- **Malicious Code Detection** - Identifies dangerous code patterns in responses
- **Credential Leak Protection** - Automatically redacts API keys, tokens, and passwords
- **Host Security Monitoring** - Checks firewall, FileVault, Gatekeeper, and SIP status
- **Audit Logging** - Complete security event history (threat-only mode available)

### Smart Context Enhancement
- **DateTime Injection** - Automatically provides current date/time context to local models
- **Knowledge Staleness Detection** - Identifies when queries might need fresh data
- **Auto Web Search** - Fetches current information for time-sensitive queries
- **Model Cutoff Awareness** - Knows training data cutoffs for 25+ model families

### Code Execution & Shell Integration
- **Sandboxed Execution** - Run Python, Bash, Zsh, and PowerShell safely
- **Resource Limits** - CPU, memory, and output size constraints
- **Secret Detection** - Automatically redacts credentials in output
- **Browser Automation** - AI-assisted web browsing with security controls

### Premium UI/UX
- **Native SwiftUI** - Feels like a first-party macOS app
- **Real-time Streaming** - See responses as they're generated
- **Rich Markdown** - Full rendering with syntax highlighting
- **Dark Mode** - Beautiful dark theme throughout
- **Keyboard Navigation** - Power user shortcuts

### Productivity Features
- **Conversation History** - Persistent storage with search
- **Folders & Organization** - Keep conversations organized
- **Templates** - Reusable conversation starters
- **Export** - Save conversations in multiple formats
- **Cost Tracking** - Monitor API spend with daily/monthly breakdowns
- **Prompt Caching** - Reduce costs with automatic cache utilization
- **Whiteboard** - Built-in visual collaboration canvas
- **Parallel Execution** - Query multiple models simultaneously

---

## System Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Processor**: Apple Silicon (M1/M2/M3) or Intel
- **Memory**: 4 GB RAM minimum, 8 GB recommended
- **Storage**: 100 MB for application, plus space for conversation history
- **Network**: Internet connection required for cloud AI providers

---

## Installation

### Option 1: Download Release (Recommended)
1. Download the latest release from the [Releases](https://github.com/YOUR_USERNAME/vaizor/releases) page
2. Move `Vaizor.app` to your Applications folder
3. Open Vaizor and configure your API keys

### Option 2: Build from Source

**Prerequisites:**
- Xcode 15.0 or later
- Swift 5.9 or later

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/vaizor.git
cd vaizor

# Build the application
./build-app.sh

# Run the app
open Vaizor.app
```

---

## Quick Start

### 1. Configure API Keys
Open Vaizor and navigate to **Settings** (Cmd+,). Add your API keys for the providers you want to use:

| Provider | Where to get API key |
|----------|---------------------|
| Anthropic | [console.anthropic.com](https://console.anthropic.com) |
| OpenAI | [platform.openai.com](https://platform.openai.com/api-keys) |
| Google | [aistudio.google.com](https://aistudio.google.com/app/apikey) |

**Ollama** works locally without an API key. Install from [ollama.ai](https://ollama.ai).

### 2. Start Chatting
- Click the **+** button or press **Cmd+N** to start a new conversation
- Select your preferred model from the dropdown
- Type your message and press **Return** to send

### 3. Explore Features
- **Cmd+/** - Open command palette
- **Cmd+K** - Quick model switcher
- **Cmd+Shift+S** - Security dashboard
- **Cmd+,** - Settings

---

## Configuration

### MCP Servers
Configure Model Context Protocol servers in **Settings > MCP Servers**:

```json
{
  "name": "filesystem",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/directory"]
}
```

### Security Settings
AiEDR settings are available in **Settings > Security**:
- Enable/disable threat detection
- Configure auto-blocking for critical threats
- Set up threat-only logging (privacy-focused mode)
- Enable background host monitoring

### Cost Tracking
View and manage API costs in **Settings > Usage**:
- Set monthly budget alerts
- View daily/weekly/monthly spend
- Track cache hit rates and savings

---

## Privacy & Security

Vaizor is designed with privacy in mind:

- **Local Storage** - Conversations are stored locally in your Application Support folder
- **Secure Credentials** - API keys are stored in macOS Keychain
- **No Telemetry** - Vaizor does not collect or transmit usage data
- **AiEDR Logging** - Threat-only mode ensures normal conversations are not logged

See [PRIVACY.md](PRIVACY.md) for complete details.

---

## Dependencies

- [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) - Markdown rendering
- [GRDB.swift](https://github.com/groue/GRDB.swift) - SQLite database

---

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting PRs.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Acknowledgments

Built with care for the macOS power user community.

**Vaizor** by Quandry - *See AI differently.*

---

© 2024-2025 Quandry Labs. All rights reserved.
