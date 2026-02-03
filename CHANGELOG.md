# Changelog

All notable changes to Vaizor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-02-01

### Initial Release

The first public release of Vaizor - the power user's AI chat client for macOS.

---

### Core Features

#### Multi-Provider LLM Support
- **Anthropic Claude** integration with support for Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku, and upcoming Claude 4.x models
- **OpenAI** support for GPT-4, GPT-4 Turbo, GPT-4o, and GPT-3.5 Turbo
- **Google Gemini** integration with Gemini Pro and Gemini Pro Vision
- **Ollama** local model support - run Llama, Mistral, Phi, Qwen, and other open models with zero cloud dependency
- **Custom Providers** - connect to any OpenAI-compatible API endpoint
- Real-time streaming responses across all providers
- Automatic model availability detection

#### Model Context Protocol (MCP) Integration
- Full MCP 1.0 specification support
- Server management UI for adding, editing, and removing MCP servers
- Automatic tool, resource, and prompt discovery from connected servers
- Progress tracking for long-running MCP operations
- Sampling handler support for agentic MCP servers
- Workspace roots provider for directory access
- Server health monitoring with error reporting
- Legacy JSON config migration to SQLite database

---

### Unique Differentiators

#### AiEDR - AI Endpoint Detection & Response
A comprehensive security layer unique to Vaizor:

**Threat Detection**
- Jailbreak attempt detection (DAN mode, developer mode exploits, roleplay attacks)
- Prompt injection blocking (instruction overrides, context manipulation)
- Data exfiltration prevention (webhook detection, encoded payload analysis)
- Malicious code pattern recognition (reverse shells, privilege escalation, ransomware)
- Social engineering tactic identification
- Suspicious URL detection (raw IPs, malicious TLDs, URL shorteners)

**Credential Protection**
- Automatic detection and redaction of API keys (AWS, OpenAI, Anthropic, GitHub, Stripe, Google)
- Private key and certificate detection
- JWT token identification
- Database URL and connection string protection
- Generic password pattern matching

**Host Security Monitoring**
- macOS Firewall status verification
- FileVault disk encryption check
- Gatekeeper status monitoring
- System Integrity Protection (SIP) verification
- Suspicious process detection
- Open port analysis with backdoor detection
- Background monitoring mode (optional)

**Audit System**
- Complete security event logging
- Threat-only logging mode for privacy
- Exportable audit logs
- Configurable log retention (up to 10,000 entries)

#### Browser Automation
- AI-assisted web browsing with native WebKit integration
- Multi-tab browser management
- Page content extraction for AI analysis
- Element finding and interaction (click, type, scroll)
- Screenshot capture
- Form detection with credential form warnings
- Rate limiting to prevent abuse
- URL security validation and malicious domain blocking
- Isolated session mode for privacy

#### Shell Execution
- Sandboxed command execution for Bash, Zsh, and PowerShell
- Dangerous command validation and blocking
- Isolated environment with restricted PATH
- Resource limits: 30s CPU time, 512MB memory, 10MB output
- Secret detection and redaction in command output
- Cross-platform shell availability detection

#### DateTime & Context Enhancement
- Automatic current date/time injection for local models
- Knowledge staleness detection with 100+ trigger keywords
- Model training cutoff database for 25+ model families
- Automatic web search for time-sensitive queries
- Fresh data injection into system prompts
- DuckDuckGo integration (privacy-focused, no API key required)

---

### Design System & Premium UI

#### Visual Design
- Native SwiftUI implementation
- Dark mode optimized color palette
- Consistent spacing and typography system
- Smooth animations and transitions
- SF Symbols integration throughout

#### Chat Experience
- Real-time message streaming
- Rich Markdown rendering with syntax highlighting
- Image attachment support with drag-and-drop
- Collapsible message sections
- Message action row (copy, regenerate, edit)
- Mention suggestions (@model, @file)

#### Navigation
- Sidebar conversation list with search
- Folder organization system
- Command palette (Cmd+/)
- Keyboard shortcuts throughout
- Model selector dropdown

#### Productivity Views
- Whiteboard canvas (Excalidraw-based)
- Code execution output panel
- Visualization rendering
- Artifact preview panel
- Security dashboard with threat overview
- Cost tracking dashboard with charts

---

### Additional Features

#### Conversation Management
- SQLite-backed persistent storage via GRDB
- Full-text search across conversations
- Folder organization with drag-and-drop
- Conversation templates with variables
- Export to JSON, Markdown, and plain text
- Import from other chat clients

#### Cost Tracking
- Real-time cost calculation per message
- Session, daily, and monthly cost aggregation
- Per-conversation cost breakdown
- Model-specific pricing database (30+ models)
- Prompt cache statistics and savings tracking
- Budget alerts with configurable thresholds
- 90-day usage history

#### Prompt Caching
- Automatic cache utilization for supported models
- Cache hit/miss tracking
- Cache read/write token counting
- Estimated savings calculation

#### Parallel Model Execution
- Query multiple models simultaneously
- Side-by-side response comparison
- Latency tracking per provider
- Streaming support across parallel requests

#### Security Features
- API keys stored in macOS Keychain
- Secret detection in code output
- Data redaction service
- Prompt injection detection
- No telemetry or usage tracking

---

### Technical Details

#### Requirements
- macOS 14.0 (Sonoma) or later
- Swift 5.9+
- Xcode 15.0+ (for building from source)

#### Dependencies
- swift-markdown-ui - Markdown rendering
- GRDB.swift - SQLite database

#### Storage Locations
- Application Support: `~/Library/Application Support/Vaizor/`
- Database: `vaizor.db`
- AiEDR Audit Log: `aiedr_audit_log.json`
- Credentials: macOS Keychain

---

### Known Limitations

- Code execution currently supports Python, Bash, Zsh, and PowerShell only
- Browser automation requires user confirmation for destructive actions
- Some MCP servers may require Node.js to be installed
- Ollama requires local installation from ollama.ai

---

### Security Advisories

- AiEDR is a defense-in-depth measure and should not be relied upon as the sole security control
- Always review AI-generated code before execution
- Regularly rotate API keys stored in the application
- Enable threat-only logging if you prefer not to log normal conversations

---

[1.0.0]: https://github.com/YOUR_USERNAME/vaizor/releases/tag/v1.0.0
