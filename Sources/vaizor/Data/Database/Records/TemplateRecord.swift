import Foundation
import GRDB

struct TemplateRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "templates"
    
    var id: String
    var name: String
    var prompt: String
    var systemPrompt: String?
    var createdAt: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case prompt
        case systemPrompt = "system_prompt"
        case createdAt = "created_at"
    }
}

extension TemplateRecord {
    init(_ template: ConversationTemplate) {
        id = template.id.uuidString
        name = template.name
        prompt = template.prompt
        systemPrompt = template.systemPrompt
        createdAt = template.createdAt.timeIntervalSince1970
    }
    
    func asModel() -> ConversationTemplate {
        ConversationTemplate(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            prompt: prompt,
            systemPrompt: systemPrompt,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
}
