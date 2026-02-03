# Privacy Policy

**Last Updated: February 1, 2026**

Vaizor is designed with privacy as a core principle. This document explains what data Vaizor collects, stores, and transmits.

---

## Summary

- **Your data stays on your device** - Conversations are stored locally
- **No telemetry** - Vaizor does not phone home or track usage
- **Minimal cloud transmission** - Only what's necessary for AI provider APIs
- **You control security logging** - AiEDR can operate in threat-only mode

---

## Data Stored Locally

### Conversation History

All conversations are stored in a SQLite database on your local machine:

```
~/Library/Application Support/Vaizor/vaizor.db
```

This database contains:
- Conversation metadata (title, creation date, folder assignment)
- Message content (your prompts and AI responses)
- Attachment references (images, files)
- Message timestamps and model information

**Your conversations never leave your device** except when sent to AI providers for processing.

### Application Settings

User preferences are stored in:
- **UserDefaults** - General settings, UI preferences, feature toggles
- **macOS Keychain** - API keys and sensitive credentials

Settings include:
- Selected AI provider and model
- UI preferences (theme, sidebar width)
- AiEDR security settings
- Cost tracking data
- MCP server configurations

### AiEDR Security Logs

The AI Endpoint Detection & Response system maintains an audit log:

```
~/Library/Application Support/Vaizor/aiedr_audit_log.json
```

**Threat-Only Logging Mode** (enabled by default):
- Only security events and detected threats are logged
- Normal conversations are NOT recorded in the audit log
- This ensures your chat content remains private

**Full Logging Mode** (optional):
- Records all security-relevant events
- Useful for enterprise security auditing
- Can be exported for compliance purposes

Audit logs contain:
- Event timestamps
- Event types (threat detected, conversation start/end, tool execution)
- Threat severity levels
- Matched security patterns (not full message content)
- Mitigation actions taken

**Log Retention:**
- Maximum 10,000 entries by default
- Older entries are automatically purged
- You can clear the audit log at any time in Settings > Security

---

## Data Sent to AI Providers

When you send a message, Vaizor transmits data to your selected AI provider's API. This is necessary for the application to function.

### What Is Transmitted

| Data | Purpose |
|------|---------|
| Your message text | The prompt you want processed |
| Conversation history | Context for multi-turn conversations |
| System prompt | Instructions for the AI model |
| Attached images | For vision-capable models |
| Model parameters | Temperature, max tokens, etc. |

### What Is NOT Transmitted to AI Providers

- Your API keys are sent only to authenticate requests, never logged by Vaizor
- Local conversation metadata (folders, titles, timestamps)
- AiEDR security logs
- Cost tracking data
- Other conversations not in the current context

### Provider Privacy Policies

Data handling by AI providers is governed by their respective privacy policies:

| Provider | Privacy Policy |
|----------|---------------|
| Anthropic | [anthropic.com/privacy](https://www.anthropic.com/privacy) |
| OpenAI | [openai.com/privacy](https://openai.com/privacy) |
| Google | [cloud.google.com/terms](https://cloud.google.com/terms) |
| Ollama | Runs locally - no data transmitted |

**Note:** When using Ollama, your prompts are processed entirely on your local machine. No data is sent to any external server.

---

## AiEDR Security Monitoring

### How AiEDR Works

AiEDR analyzes your prompts and AI responses for security threats:

1. **Incoming Prompts** - Scanned for jailbreak attempts, prompt injection, and suspicious patterns
2. **AI Responses** - Scanned for malicious code, credential leaks, and social engineering
3. **Host System** - Optionally monitors firewall, encryption, and process activity

### What AiEDR Logs

**In Threat-Only Mode (Default):**
- Only logs when a threat is detected
- Records: threat type, severity, matched patterns, timestamp
- Does NOT log clean messages or normal conversation flow

**Example Threat Log Entry:**
```json
{
  "id": "...",
  "timestamp": "2026-02-01T10:30:00Z",
  "eventType": "Threat Detected",
  "description": "Jailbreak attempt detected: DAN Mode",
  "severity": "Critical",
  "metadata": {
    "alertCount": "1",
    "threatLevel": "Critical"
  }
}
```

### What AiEDR Does NOT Do

- Does not send security data to any external server
- Does not log your actual message content (only pattern names)
- Does not share threat data with Anthropic, OpenAI, or other providers
- Does not require internet access (works offline)

### Disabling AiEDR

You can completely disable AiEDR in **Settings > Security**:
- Toggle "Enable AiEDR" to off
- All security scanning will be disabled
- No security events will be logged

---

## Web Search Feature

When Vaizor detects a time-sensitive query, it may perform a web search to fetch current information.

### Search Provider

Vaizor uses **DuckDuckGo** for web searches:
- Privacy-focused search engine
- No user tracking or profiling
- No API key required

### What Is Searched

- A sanitized version of your query
- Never includes personal information
- Rate-limited to 10 requests per minute

### What Is NOT Searched

- Your full conversation history
- Your API keys or credentials
- System information or file contents

You can disable auto web search in **Settings > Features**.

---

## Browser Automation

The built-in browser uses WebKit and stores data locally:

### Browser Data Storage

- **Cookies** - Stored in WebKit's data store (persistent mode)
- **Cache** - Stored locally for faster page loads
- **History** - Not tracked by Vaizor

### Isolated Session Mode

You can enable isolated sessions in the browser:
- Cookies are not persisted
- No data survives after session ends
- Useful for privacy-sensitive browsing

### Clear Browser Data

You can clear all browser data at any time via the browser interface.

---

## MCP Servers

Model Context Protocol servers can extend Vaizor's capabilities:

### Local Execution

MCP servers run locally on your machine. Vaizor:
- Starts servers as child processes
- Communicates via stdin/stdout (JSON-RPC)
- Does not send MCP data to external servers

### Server Permissions

MCP servers may access:
- Files in configured directories
- Network resources (if the server requires)
- System information

**Review MCP server capabilities** before installing them.

---

## Data You Control

### Export Your Data

You can export all your data at any time:
- **Conversations** - Export to JSON, Markdown, or plain text
- **Audit Logs** - Export from Settings > Security
- **Settings** - Stored in UserDefaults, accessible via macOS tools

### Delete Your Data

To completely remove Vaizor data:

1. **Quit Vaizor**
2. **Delete application data:**
   ```bash
   rm -rf ~/Library/Application\ Support/Vaizor/
   ```
3. **Delete preferences:**
   ```bash
   defaults delete com.vaizor.app
   ```
4. **Delete Keychain items:**
   - Open Keychain Access
   - Search for "Vaizor"
   - Delete found entries

---

## No Telemetry

Vaizor does not:
- Track feature usage
- Report crashes automatically
- Phone home for updates
- Collect analytics
- Share data with third parties

The application makes network requests only when:
1. You send a message to an AI provider
2. You perform a web search
3. You use the built-in browser
4. MCP servers require network access

---

## Children's Privacy

Vaizor is not intended for children under 13. We do not knowingly collect data from children.

---

## Changes to This Policy

We will update this policy as needed. Changes will be documented in the CHANGELOG.

---

## Contact

For privacy questions or concerns, please open an issue on our GitHub repository.

---

**Your privacy matters. Vaizor is built to keep your data yours.**
