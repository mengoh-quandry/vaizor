import Foundation

class OllamaProvider: LLMProviderProtocol {
    private let baseURL = "http://localhost:11434"

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        // This method is for non-streaming, but we'll implement streaming separately
        throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use streaming method instead"])
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void
    ) async throws {
        let url = URL(string: "\(baseURL)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build messages array from conversation history
        var messages: [[String: Any]] = []

        // Add system prompt if provided
        if let systemPrompt = configuration.systemPrompt {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        // Add conversation history
        for message in conversationHistory {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ])
        }

        // Add current message
        messages.append([
            "role": "user",
            "content": text
        ])

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "stream": true,
            "options": [
                "temperature": configuration.temperature,
                "num_predict": configuration.maxTokens
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OllamaProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Ollama"])
        }

        var fullResponse = ""

        for try await line in asyncBytes.lines {
            guard !line.isEmpty else { continue }

            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let messageContent = json["message"] as? [String: Any],
               let content = messageContent["content"] as? String {
                fullResponse += content
                onChunk(content)
                // Add 30ms delay for smoother streaming
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }
}

// Anthropic Provider
class AnthropicProvider: LLMProviderProtocol {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        throw NSError(domain: "AnthropicProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use streaming method instead"])
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void
    ) async throws {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build messages
        var messages: [[String: Any]] = []

        for message in conversationHistory {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ])
        }

        messages.append([
            "role": "user",
            "content": text
        ])

        var body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "max_tokens": configuration.maxTokens,
            "stream": true
        ]

        if let systemPrompt = configuration.systemPrompt {
            body["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AnthropicProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Anthropic"])
        }

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard !jsonString.contains("[DONE]"),
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let type = json["type"] as? String,
               type == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                onChunk(text)
            }
        }
    }
}

// OpenAI Provider
class OpenAIProvider: LLMProviderProtocol {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func sendMessage(_ text: String, configuration: LLMConfiguration) async throws -> String {
        throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Use streaming method instead"])
    }

    func streamMessage(
        _ text: String,
        configuration: LLMConfiguration,
        conversationHistory: [Message],
        onChunk: @escaping (String) -> Void
    ) async throws {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messages: [[String: Any]] = []

        if let systemPrompt = configuration.systemPrompt {
            messages.append([
                "role": "system",
                "content": systemPrompt
            ])
        }

        for message in conversationHistory {
            messages.append([
                "role": message.role == .user ? "user" : "assistant",
                "content": message.content
            ])
        }

        messages.append([
            "role": "user",
            "content": text
        ])

        let body: [String: Any] = [
            "model": configuration.model,
            "messages": messages,
            "temperature": configuration.temperature,
            "max_tokens": configuration.maxTokens,
            "stream": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "OpenAIProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to connect to OpenAI"])
        }

        for try await line in asyncBytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            guard !jsonString.contains("[DONE]"),
                  let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            if let choices = json["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let content = delta["content"] as? String {
                onChunk(content)
            }
        }
    }
}
