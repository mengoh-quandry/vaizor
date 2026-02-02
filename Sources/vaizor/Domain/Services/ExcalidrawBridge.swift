import Foundation
import WebKit

/// Bridge between Swift and Excalidraw JavaScript running in WKWebView
@MainActor
class ExcalidrawBridge: NSObject {
    private weak var webView: WKWebView?
    private let repository: WhiteboardRepository
    private var currentWhiteboardId: UUID?
    
    // Callbacks
    var onContentChanged: ((String) -> Void)?
    var onReady: (() -> Void)?
    var onError: ((String) -> Void)?
    var onExportComplete: ((Data, ExportType) -> Void)?
    
    init(repository: WhiteboardRepository = WhiteboardRepository()) {
        self.repository = repository
        super.init()
    }
    
    func attach(to webView: WKWebView) {
        self.webView = webView
        webView.configuration.userContentController.add(self, name: "excalidrawBridge")
    }
    
    func detach() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "excalidrawBridge")
        webView = nil
    }
    
    // MARK: - Load & Save
    
    func loadWhiteboard(_ whiteboard: Whiteboard) async throws {
        currentWhiteboardId = whiteboard.id
        
        let escapedJSON = whiteboard.content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        let script = """
        if (window.excalidrawAPI) {
            try {
                const data = JSON.parse("\(escapedJSON)");
                window.excalidrawAPI.updateScene(data);
                window.webkit.messageHandlers.excalidrawBridge.postMessage({
                    type: 'loaded',
                    whiteboardId: '\(whiteboard.id.uuidString)'
                });
            } catch (error) {
                window.webkit.messageHandlers.excalidrawBridge.postMessage({
                    type: 'error',
                    message: 'Failed to load whiteboard: ' + error.message
                });
            }
        } else {
            window.webkit.messageHandlers.excalidrawBridge.postMessage({
                type: 'error',
                message: 'Excalidraw API not available'
            });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    func saveCurrentWhiteboard() async throws {
        guard let whiteboardId = currentWhiteboardId else {
            throw WhiteboardError.notFound
        }
        
        let script = """
        if (window.excalidrawAPI) {
            const elements = window.excalidrawAPI.getSceneElements();
            const appState = window.excalidrawAPI.getAppState();
            const files = window.excalidrawAPI.getFiles();
            
            const data = {
                elements: elements,
                appState: {
                    viewBackgroundColor: appState.viewBackgroundColor,
                    gridSize: appState.gridSize
                },
                files: files
            };
            
            window.webkit.messageHandlers.excalidrawBridge.postMessage({
                type: 'save',
                whiteboardId: '\(whiteboardId.uuidString)',
                content: JSON.stringify(data)
            });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    func getSceneJSON() async throws -> String {
        let script = """
        (function() {
            if (!window.excalidrawAPI) {
                throw new Error('Excalidraw API not available');
            }
            
            const elements = window.excalidrawAPI.getSceneElements();
            const appState = window.excalidrawAPI.getAppState();
            const files = window.excalidrawAPI.getFiles();
            
            return JSON.stringify({
                elements: elements,
                appState: {
                    viewBackgroundColor: appState.viewBackgroundColor,
                    gridSize: appState.gridSize
                },
                files: files
            });
        })()
        """
        
        let result = try await evaluateJavaScript(script)
        
        if let jsonString = result as? String {
            return jsonString
        }
        
        throw WhiteboardError.invalidContent
    }
    
    // MARK: - Element Manipulation
    
    func addElement(_ element: ExcalidrawElement) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(element)
        guard let json = String(data: data, encoding: .utf8) else {
            throw WhiteboardError.encodingFailed
        }
        
        let script = """
        if (window.excalidrawAPI) {
            const element = JSON.parse('\(json)');
            window.excalidrawAPI.updateScene({
                elements: [...window.excalidrawAPI.getSceneElements(), element]
            });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    func addElements(_ elements: [ExcalidrawElement]) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(elements)
        guard let json = String(data: data, encoding: .utf8) else {
            throw WhiteboardError.encodingFailed
        }
        
        let escapedJSON = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        
        let script = """
        if (window.excalidrawAPI) {
            const newElements = JSON.parse('\(escapedJSON)');
            window.excalidrawAPI.updateScene({
                elements: [...window.excalidrawAPI.getSceneElements(), ...newElements]
            });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    func clearScene() async throws {
        let script = """
        if (window.excalidrawAPI) {
            window.excalidrawAPI.updateScene({ elements: [] });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    func deleteElement(id: String) async throws {
        let script = """
        if (window.excalidrawAPI) {
            const elements = window.excalidrawAPI.getSceneElements();
            const filtered = elements.filter(el => el.id !== '\(id)');
            window.excalidrawAPI.updateScene({ elements: filtered });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    // MARK: - Export
    
    func exportToPNG(scale: Double = 2.0) async throws {
        let script = """
        (async function() {
            if (!window.excalidrawAPI) {
                throw new Error('Excalidraw API not available');
            }
            
            const blob = await window.excalidrawAPI.exportToBlob({
                mimeType: 'image/png',
                quality: 1.0,
                exportPadding: 20
            });
            
            return new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.onloadend = () => resolve(reader.result);
                reader.onerror = reject;
                reader.readAsDataURL(blob);
            });
        })()
        """
        
        let result = try await evaluateJavaScript(script)
        
        if let dataURL = result as? String,
           let data = dataURLToData(dataURL) {
            onExportComplete?(data, .png)
        } else {
            throw WhiteboardError.invalidContent
        }
    }
    
    func exportToSVG() async throws {
        let script = """
        (async function() {
            if (!window.excalidrawAPI) {
                throw new Error('Excalidraw API not available');
            }
            
            const svg = await window.excalidrawAPI.exportToSvg({
                exportPadding: 20
            });
            
            const serializer = new XMLSerializer();
            return serializer.serializeToString(svg);
        })()
        """
        
        let result = try await evaluateJavaScript(script)
        
        if let svgString = result as? String,
           let data = svgString.data(using: .utf8) {
            onExportComplete?(data, .svg)
        } else {
            throw WhiteboardError.invalidContent
        }
    }
    
    // MARK: - View Control
    
    func zoomToFit() async throws {
        let script = """
        if (window.excalidrawAPI) {
            window.excalidrawAPI.scrollToContent();
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    func resetZoom() async throws {
        let script = """
        if (window.excalidrawAPI) {
            window.excalidrawAPI.updateScene({
                appState: { zoom: { value: 1 } }
            });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    func setTheme(_ theme: ExcalidrawTheme) async throws {
        let themeValue = theme == .dark ? "dark" : "light"
        
        let script = """
        if (window.excalidrawAPI) {
            window.excalidrawAPI.updateScene({
                appState: { theme: '\(themeValue)' }
            });
        }
        """
        
        try await evaluateJavaScript(script)
    }
    
    // MARK: - Helpers
    
    private func evaluateJavaScript(_ script: String) async throws -> Any? {
        guard let webView = webView else {
            throw WhiteboardError.invalidContent
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    private func dataURLToData(_ dataURL: String) -> Data? {
        guard dataURL.hasPrefix("data:") else { return nil }
        
        let parts = dataURL.components(separatedBy: ",")
        guard parts.count == 2,
              let base64String = parts.last,
              let data = Data(base64Encoded: base64String) else {
            return nil
        }
        
        return data
    }
}

// MARK: - WKScriptMessageHandler

extension ExcalidrawBridge: WKScriptMessageHandler {
    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        Task { @MainActor in
            await handleMessage(message)
        }
    }
    
    private func handleMessage(_ message: WKScriptMessage) async {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else {
            return
        }
        
        switch type {
        case "ready":
            onReady?()
            AppLogger.shared.log("Excalidraw ready", level: .info)
            
        case "changed":
            if let content = body["content"] as? String {
                onContentChanged?(content)
            }
            
        case "save":
            if let whiteboardIdString = body["whiteboardId"] as? String,
               let whiteboardId = UUID(uuidString: whiteboardIdString),
               let content = body["content"] as? String {
                do {
                    try await repository.updateContent(whiteboardId, content: content)
                    AppLogger.shared.log("Whiteboard saved: \(whiteboardId)", level: .info)
                } catch {
                    AppLogger.shared.logError(error, context: "Failed to save whiteboard")
                    onError?("Failed to save: \(error.localizedDescription)")
                }
            }
            
        case "loaded":
            if let whiteboardIdString = body["whiteboardId"] as? String {
                AppLogger.shared.log("Whiteboard loaded: \(whiteboardIdString)", level: .info)
            }
            
        case "error":
            if let errorMessage = body["message"] as? String {
                AppLogger.shared.log("Excalidraw error: \(errorMessage)", level: .error)
                onError?(errorMessage)
            }
            
        default:
            AppLogger.shared.log("Unknown Excalidraw message type: \(type)", level: .warning)
        }
    }
}

// MARK: - Supporting Types

enum ExcalidrawTheme {
    case light
    case dark
}

enum ExportType {
    case png
    case svg
    case json
}
