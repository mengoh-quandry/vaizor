import Foundation
import GRDB

struct AttachmentRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "attachments"

    var id: String
    var messageId: String
    var mimeType: String?
    var filename: String?
    var data: Data
    var isImage: Bool
    var byteCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case mimeType = "mime_type"
        case filename
        case data
        case isImage = "is_image"
        case byteCount = "byte_count"
    }
}
