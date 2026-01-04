# Vaizor

A native macOS chat application for interacting with multiple AI language models.

## Features

- **Multiple AI Providers**: Support for Anthropic Claude, OpenAI, Google Gemini, Ollama, and custom providers
- **Real-time Streaming**: See AI responses as they're generated
- **Modern Chat Interface**: Clean, intuitive SwiftUI-based design
- **Model Selection**: Switch between different AI models on the fly
- **Slash Commands**: Quick commands for common actions
- **Whiteboard**: Built-in whiteboard feature for visual collaboration
- **Image Support**: Attach and view images in conversations
- **Markdown Rendering**: Rich text formatting with code syntax highlighting
- **Conversation History**: Persistent chat storage and retrieval

## Requirements

- macOS 14.0 or later
- Swift 5.9 or later

## Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/vaizor.git
cd vaizor
```

2. Build the application:
```bash
./build-app.sh
```

3. Run the app:
```bash
open Vaizor.app
```

## Configuration

Configure your API keys in the application settings for:
- Anthropic Claude
- OpenAI
- Google Gemini
- Custom providers

Ollama integration works locally without API keys.

## Dependencies

- [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) - Markdown rendering

## License

MIT
