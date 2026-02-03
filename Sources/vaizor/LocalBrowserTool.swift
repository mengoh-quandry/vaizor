import Foundation

@MainActor
protocol LocalTool {
    func handleJSON(_ json: [String: Any]) async -> String
}

@MainActor
final class LocalBrowserToolAdapter: LocalTool {
    private let browserTool: BrowserTool
    init(tool: BrowserTool) { self.browserTool = tool }

    func handleJSON(_ json: [String : Any]) async -> String {
        var cmd = BrowserCommand(action: (json["action"] as? String) ?? "", url: nil, selector: nil, value: nil, clear: nil, path: nil)
        if let v = json["url"] as? String { cmd.url = v }
        if let v = json["selector"] as? String { cmd.selector = v }
        if let v = json["value"] as? String { cmd.value = v }
        if let v = json["clear"] as? Bool { cmd.clear = v }
        if let v = json["path"] as? String { cmd.path = v }
        return await browserTool.handle(cmd)
    }
}
