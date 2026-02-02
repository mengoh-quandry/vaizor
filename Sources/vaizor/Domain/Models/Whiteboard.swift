import Foundation

// MARK: - Whiteboard Model

struct Whiteboard: Identifiable, Codable, Equatable {
    let id: UUID
    let conversationId: UUID?
    var title: String
    var content: String  // JSON string of ExcalidrawData
    let createdAt: Date
    var updatedAt: Date
    var thumbnail: Data?
    var tags: [String]
    var isShared: Bool
    
    init(
        id: UUID = UUID(),
        conversationId: UUID? = nil,
        title: String,
        content: String = "{}",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        thumbnail: Data? = nil,
        tags: [String] = [],
        isShared: Bool = false
    ) {
        self.id = id
        self.conversationId = conversationId
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.thumbnail = thumbnail
        self.tags = tags
        self.isShared = isShared
    }
    
    /// Get parsed Excalidraw data
    var excalidrawData: ExcalidrawData? {
        guard let data = content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ExcalidrawData.self, from: data)
    }
    
    /// Update with new Excalidraw data
    mutating func updateContent(_ data: ExcalidrawData) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = try encoder.encode(data)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw WhiteboardError.encodingFailed
        }
        self.content = jsonString
        self.updatedAt = Date()
    }
    
    /// Create empty whiteboard with basic structure
    static func empty(title: String, conversationId: UUID? = nil) -> Whiteboard {
        let emptyData = ExcalidrawData(
            elements: [],
            appState: ExcalidrawAppState(
                viewBackgroundColor: "#ffffff",
                gridSize: nil
            ),
            files: nil
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let jsonData = (try? encoder.encode(emptyData)) ?? Data()
        let content = String(data: jsonData, encoding: .utf8) ?? "{}"
        
        return Whiteboard(
            conversationId: conversationId,
            title: title,
            content: content
        )
    }
}

// MARK: - Excalidraw Data Structures

struct ExcalidrawData: Codable, Equatable {
    var elements: [ExcalidrawElement]
    var appState: ExcalidrawAppState
    var files: [String: ExcalidrawFile]?
    
    enum CodingKeys: String, CodingKey {
        case elements
        case appState
        case files
    }
}

struct ExcalidrawElement: Codable, Equatable {
    let id: String
    let type: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var angle: Double?
    var strokeColor: String?
    var backgroundColor: String?
    var fillStyle: String?
    var strokeWidth: Double?
    var strokeStyle: String?
    var roughness: Double?
    var opacity: Double?
    var text: String?
    var fontSize: Double?
    var fontFamily: Int?
    var textAlign: String?
    var verticalAlign: String?
    var baseline: Double?
    var isDeleted: Bool?
    var groupIds: [String]?
    var boundElements: [[String: String]]?
    var link: String?
    var locked: Bool?
    
    // Arrow-specific
    var startBinding: [String: String]?
    var endBinding: [String: String]?
    var startArrowhead: String?
    var endArrowhead: String?
    var points: [[Double]]?
    
    // Line-specific
    var lastCommittedPoint: [Double]?
    
    init(
        id: String = UUID().uuidString,
        type: String,
        x: Double = 0,
        y: Double = 0,
        width: Double = 100,
        height: Double = 100,
        angle: Double? = 0,
        strokeColor: String? = "#000000",
        backgroundColor: String? = "transparent",
        fillStyle: String? = "hachure",
        strokeWidth: Double? = 1,
        strokeStyle: String? = "solid",
        roughness: Double? = 1,
        opacity: Double? = 100,
        text: String? = nil,
        fontSize: Double? = 20,
        fontFamily: Int? = 1,
        textAlign: String? = "left",
        verticalAlign: String? = "top",
        isDeleted: Bool? = false,
        groupIds: [String]? = nil,
        boundElements: [[String: String]]? = nil,
        link: String? = nil,
        locked: Bool? = false,
        startBinding: [String: String]? = nil,
        endBinding: [String: String]? = nil,
        startArrowhead: String? = nil,
        endArrowhead: String? = nil,
        points: [[Double]]? = nil
    ) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.angle = angle
        self.strokeColor = strokeColor
        self.backgroundColor = backgroundColor
        self.fillStyle = fillStyle
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.roughness = roughness
        self.opacity = opacity
        self.text = text
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.textAlign = textAlign
        self.verticalAlign = verticalAlign
        self.isDeleted = isDeleted
        self.groupIds = groupIds
        self.boundElements = boundElements
        self.link = link
        self.locked = locked
        self.startBinding = startBinding
        self.endBinding = endBinding
        self.startArrowhead = startArrowhead
        self.endArrowhead = endArrowhead
        self.points = points
    }
    
    /// Create a rectangle element
    static func rectangle(x: Double, y: Double, width: Double, height: Double, text: String? = nil) -> ExcalidrawElement {
        ExcalidrawElement(
            type: "rectangle",
            x: x,
            y: y,
            width: width,
            height: height,
            text: text
        )
    }
    
    /// Create an ellipse element
    static func ellipse(x: Double, y: Double, width: Double, height: Double, text: String? = nil) -> ExcalidrawElement {
        ExcalidrawElement(
            type: "ellipse",
            x: x,
            y: y,
            width: width,
            height: height,
            text: text
        )
    }
    
    /// Create a diamond element
    static func diamond(x: Double, y: Double, width: Double, height: Double, text: String? = nil) -> ExcalidrawElement {
        ExcalidrawElement(
            type: "diamond",
            x: x,
            y: y,
            width: width,
            height: height,
            text: text
        )
    }
    
    /// Create an arrow element
    static func arrow(startX: Double, startY: Double, endX: Double, endY: Double) -> ExcalidrawElement {
        let points = [[0.0, 0.0], [endX - startX, endY - startY]]
        return ExcalidrawElement(
            type: "arrow",
            x: startX,
            y: startY,
            width: abs(endX - startX),
            height: abs(endY - startY),
            startArrowhead: nil,
            endArrowhead: "arrow",
            points: points
        )
    }
    
    /// Create a text element
    static func text(x: Double, y: Double, text: String, fontSize: Double = 20) -> ExcalidrawElement {
        let estimatedWidth = Double(text.count) * fontSize * 0.6
        return ExcalidrawElement(
            type: "text",
            x: x,
            y: y,
            width: estimatedWidth,
            height: fontSize * 1.2,
            text: text,
            fontSize: fontSize
        )
    }
}

struct ExcalidrawAppState: Codable, Equatable {
    var viewBackgroundColor: String
    var gridSize: Int?
    var zoom: [String: Double]?
    var scrollX: Double?
    var scrollY: Double?
    var currentItemStrokeColor: String?
    var currentItemBackgroundColor: String?
    var currentItemFillStyle: String?
    var currentItemStrokeWidth: Double?
    var currentItemRoughness: Double?
    var currentItemOpacity: Double?
    var currentItemFontFamily: Int?
    var currentItemFontSize: Double?
    var currentItemTextAlign: String?
    var currentItemRoundness: String?
    
    init(
        viewBackgroundColor: String = "#ffffff",
        gridSize: Int? = nil,
        zoom: [String: Double]? = nil,
        scrollX: Double? = 0,
        scrollY: Double? = 0
    ) {
        self.viewBackgroundColor = viewBackgroundColor
        self.gridSize = gridSize
        self.zoom = zoom
        self.scrollX = scrollX
        self.scrollY = scrollY
    }
}

struct ExcalidrawFile: Codable, Equatable {
    let id: String
    let dataURL: String
    let mimeType: String
    let created: Double
    var lastRetrieved: Double?
}

// MARK: - Errors

enum WhiteboardError: Error, LocalizedError {
    case encodingFailed
    case decodingFailed
    case invalidContent
    case notFound
    case saveFailed(String)
    case loadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode whiteboard content"
        case .decodingFailed:
            return "Failed to decode whiteboard content"
        case .invalidContent:
            return "Whiteboard content is invalid"
        case .notFound:
            return "Whiteboard not found"
        case .saveFailed(let reason):
            return "Failed to save whiteboard: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load whiteboard: \(reason)"
        }
    }
}
