import Foundation

enum LLMProvider: String, Codable, CaseIterable {
    case anthropic
    case openai
    case gemini
    case ollama
    case custom

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic Claude"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .ollama: return "Ollama"
        case .custom: return "Custom Provider"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openai: return "GPT"
        case .gemini: return "Gemini"
        case .ollama: return "Ollama"
        case .custom: return "Custom"
        }
    }

    var defaultModels: [String] {
        switch self {
        case .anthropic:
            return ["claude-3-5-sonnet-20241022", "claude-3-opus-20240229"]
        case .openai:
            return ["gpt-4-turbo-preview", "gpt-3.5-turbo"]
        case .gemini:
            return ["gemini-pro", "gemini-pro-vision"]
        case .ollama:
            return ["llama2", "mistral"]
        case .custom:
            return []
        }
    }
}

struct LLMConfiguration {
    let provider: LLMProvider
    let model: String
    let temperature: Double
    let maxTokens: Int
    let systemPrompt: String?
    let enableChainOfThought: Bool

    init(
        provider: LLMProvider,
        model: String,
        temperature: Double = 0.7,
        maxTokens: Int = 4096,
        systemPrompt: String? = nil,
        enableChainOfThought: Bool = false
    ) {
        self.provider = provider
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.systemPrompt = systemPrompt
        self.enableChainOfThought = enableChainOfThought
    }
}
