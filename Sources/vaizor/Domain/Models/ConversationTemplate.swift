import Foundation

struct ConversationTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var prompt: String
    var systemPrompt: String?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        prompt: String,
        systemPrompt: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.createdAt = createdAt
    }
}
