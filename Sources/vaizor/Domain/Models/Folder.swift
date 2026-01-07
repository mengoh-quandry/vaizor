import Foundation

struct Folder: Identifiable, Codable {
    let id: UUID
    var name: String
    var color: String? // Hex color code
    var parentId: UUID? // For nested folders
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        color: String? = nil,
        parentId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.parentId = parentId
        self.createdAt = createdAt
    }
}
