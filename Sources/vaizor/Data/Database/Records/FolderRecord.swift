import Foundation
import GRDB

struct FolderRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "folders"
    
    var id: String
    var name: String
    var color: String?
    var parentId: String?
    var createdAt: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case parentId = "parent_id"
        case createdAt = "created_at"
    }
}

extension FolderRecord {
    init(_ folder: Folder) {
        id = folder.id.uuidString
        name = folder.name
        color = folder.color
        parentId = folder.parentId?.uuidString
        createdAt = folder.createdAt.timeIntervalSince1970
    }
    
    func asModel() -> Folder {
        Folder(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            color: color,
            parentId: parentId.flatMap { UUID(uuidString: $0) },
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
}
