# Vaizor 🤖✨

A powerful native macOS chat application for interacting with multiple AI language models, featuring advanced MCP (Model Context Protocol) integration and browser automation.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

### 🎯 Core Capabilities

- **Multiple AI Providers**: Seamlessly switch between Anthropic Claude, OpenAI GPT, Google Gemini, Ollama (local), and custom providers
- **Real-time Streaming**: Watch AI responses appear in real-time with dynamic "thinking" status indicators
- **Modern macOS UI**: Beautiful native SwiftUI interface with Material backgrounds and smooth animations
- **Model Selection**: Quick model switching with per-provider model management
- **Conversation Management**: Auto-generated titles, summaries, and smart conversation organization

### 🔧 MCP Server Integration

- **Dynamic Server Management**: Add, configure, enable/disable MCP servers on the fly
- **AI-Powered Import**: Scan project folders and automatically extract MCP server configurations using LLM analysis
- **Tool Call System**: Advanced tool calling with `server::tool` syntax for Ollama models
- **Connection Testing**: Validate server configurations before deployment
- **Import Preview**: Review and edit AI-generated server configs before importing

### 🌐 Browser Automation

- **WebKit Integration**: Full browser automation panel with JavaScript execution
- **Advanced Commands**: Navigate, click, type, screenshot, upload files, and more
- **Network Monitoring**: Wait for network idle, track pending requests
- **CAPTCHA Detection**: Built-in Vision-based CAPTCHA detection helpers
- **Element Screenshots**: Capture specific DOM elements
- **Time-lapse Recording**: Record browser sessions as MP4 videos
- **System Screenshots**: Capture entire displays programmatically

### 💬 Enhanced Chat Experience

- **Slash Commands**: Quick actions with `/` prefix
  - `/whiteboard` - Open visualization canvas
  - `/code` - Generate code snippets
  - `/web` - Search the web
  - `/summarize` - Summarize conversation
  - `/export` - Export chat to file
  - `/clear` - Clear conversation
- **Rich Markdown**: Full markdown support with syntax highlighting for code blocks
- **Image Attachments**: Attach and display images inline
- **Whiteboard Canvas**: Render HTML visualizations, charts, and interactive content
- **Message Roles**: User, Assistant, System, and Tool messages with distinct styling
- **Export Formats**: Export conversations as Markdown, JSON, HTML, or plain text

### 🎨 UI/UX Features

- **Glass Material Backgrounds**: Modern translucent interfaces
- **Animated Indicators**: Beautiful loading and thinking animations
- **Keyboard Shortcuts**: `⌘+Shift+I` for MCP import, `⌘+Return` to send messages
- **Sidebar Panels**: Chat history sidebar and settings sidebar
- **Message Bubbles**: Role-based color coding and avatars
- **Dark Mode**: Full dark mode support

## 📋 Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Swift**: 5.9+
- **Xcode**: 15.0+
- **Ollama** (optional): For local model support

## 🚀 Installation

### Option 1: Build from Source

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/vaizor.git
cd vaizor

# Build using the build script
chmod +x build-app.sh
./build-app.sh

# Launch the app
open Vaizor.app
```

### Option 2: Xcode

1. Open `Vaizor.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘+R)

## ⚙️ Configuration

### API Keys

Configure your API keys in **Settings** (sidebar toggle):

1. **Anthropic Claude**
   - Get your API key from https://console.anthropic.com
   - Supports: Claude 3.5 Sonnet, Claude 3 Opus

2. **OpenAI**
   - Get your API key from https://platform.openai.com
   - Supports: GPT-4 Turbo, GPT-3.5 Turbo
3. **Google Gemini**
   - Get your API key from https://makersuite.google.com
   - Supports: Gemini Pro, Gemini Pro Vision

4. **Ollama (Local)**
   - Install Ollama: `brew install ollama`
   - Pull models: `ollama pull llama2`
   - No API key required

### MCP Servers

**Manual Configuration:**
1. Go to Settings → MCP Servers → Add Server
2. Fill in server details:
   - **Name**: Server identifier (e.g., "filesystem")
   - **Description**: What the server does
   - **Command**: Executable (e.g., `npx`, `python3`)
   - **Arguments**: Command arguments (e.g., `-y @modelcontextprotocol/server-filesystem /path`)
   - **Path**: Working directory

**AI-Powered Import:**
1. Select **Extensions → Import MCP Servers from Folder…** (⌘+Shift+I)
2. Choose a project folder
3. The LLM analyzes files and extracts server configurations
4. Review and edit the generated configs
5. Test connections before importing

**Example MCP Server (Filesystem):**
```json
{
  "name": "filesystem",
  "description": "Access local files and directories",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/you/Documents"],
  "path": "/Users/you"
}
```

## 🎮 Usage

### Basic Chat

1. **Start a conversation**: Type in the input field and press Return
2. **Switch models**: Use the model dropdown in the chat input bar
3. **New chat**: Click the pencil icon or use ⌘+N

### Using MCP Tools (Ollama)

Enable MCP servers in settings, then use the `server::tool` syntax:

```
Can you list the files in my Documents folder using filesystem::list?
```

The model will:
1. Detect the tool call
2. Execute `filesystem::list` on your MCP server
3. Include the results in its response

### Browser Automation

1. Click the globe icon to open the Browser Panel
2. Navigate to any website
3. Use JavaScript commands or the automation API:
   - **Navigate**: `automation.load(URL(string: "https://example.com")!)`
   - **Click**: `await automation.click(".button-selector")`
   - **Type**: `await automation.type("#input", text: "Hello")`
   - **Screenshot**: `await automation.takeSnapshot()`

### Whiteboard

1. Type `/whiteboard` or click the whiteboard icon
2. The AI can generate HTML/CSS/JS visualizations
3. Content renders in the whiteboard canvas

### Export Conversations

1. Use `/export` slash command or Settings → Export
2. Choose format:
   - **Markdown**: `.md` with formatted messages
   - **JSON**: `.json` with full metadata
   - **HTML**: `.html` with styled output
   - **Plain Text**: `.txt` simple format

## 🛠️ Architecture

```
Vaizor/
├── VaizorApp.swift              # Main app entry and UI
├── ChatView.swift               # Chat interface
├── ChatViewModel.swift          # Chat logic and state
├── ConversationManager.swift    # Conversation persistence
├── MCPServer.swift              # MCP server management
├── MCPImportEnhanced.swift      # AI-powered MCP import
├── BrowserAutomation.swift      # WebKit automation
├── BrowserCommandsEnhanced.swift # Enhanced browser commands
├── LLMProvider.swift            # Provider abstraction
├── OllamaProvider.swift         # Ollama + MCP integration
├── AnthropicProvider.swift      # Anthropic API
├── OpenAIProvider.swift         # OpenAI API
├── ToolCallParser.swift         # Tool call detection
├── EnhancedSlashCommands.swift  # Command system
├── ConversationExporter.swift   # Export functionality
└── Supporting Files/
    ├── Message.swift
    ├── Conversation.swift
    ├── DependencyContainer.swift
    └── UI Components/
```

## 📚 Dependencies

- **[MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui)**: Markdown rendering with syntax highlighting
- **WebKit**: Browser automation
- **Vision**: CAPTCHA text recognition
- **AVFoundation**: Video recording

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 TODO

- [ ] Gemini provider implementation
- [ ] Custom provider configuration UI
- [ ] Voice input support
- [ ] File attachment handling
- [ ] Multi-modal image analysis
- [ ] Plugin system for extensions
- [ ] Cloud sync for conversations
- [ ] Advanced MCP server discovery

## 🐛 Known Issues

- Large file attachments may cause performance issues
- Some MCP servers require specific Node.js versions
- Browser automation may not work with all websites

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Anthropic](https://anthropic.com) for Claude API
- [OpenAI](https://openai.com) for GPT API
- [Google](https://ai.google.dev) for Gemini API
- [Ollama](https://ollama.ai) for local model runtime
- [Model Context Protocol](https://modelcontextprotocol.io) for MCP specification
- The Swift and macOS developer community

---

Made with ❤️ for the macOS AI community

