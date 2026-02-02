import Foundation
import AppKit

// Enhanced browser command handler with validation and error recovery
extension BrowserTool {
    enum BrowserError: LocalizedError {
        case invalidURL(String)
        case selectorNotFound(String)
        case elementNotInteractable(String)
        case missingParameter(String)
        case invalidScript(String)
        case fileNotFound(String)
        case operationTimeout(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL(let url):
                return "Invalid URL: \(url)"
            case .selectorNotFound(let selector):
                return "Element not found: \(selector)"
            case .elementNotInteractable(let selector):
                return "Element cannot be interacted with: \(selector)"
            case .missingParameter(let param):
                return "Missing required parameter: \(param)"
            case .invalidScript(let script):
                return "Invalid JavaScript: \(script)"
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .operationTimeout(let operation):
                return "Operation timed out: \(operation)"
            }
        }
    }
    
    // Enhanced command handler with validation
    func handleEnhanced(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        switch cmd.action.lowercased() {
        case "navigate", "open":
            return await handleNavigate(cmd)
            
        case "click":
            return await handleClick(cmd)
            
        case "type", "fill":
            return await handleType(cmd)
            
        case "select":
            return await handleSelect(cmd)
            
        case "wait":
            return await handleWait(cmd)
            
        case "scroll":
            return await handleScroll(cmd)
            
        case "screenshot":
            return await handleScreenshot(cmd)
            
        case "evaluate", "eval", "execute":
            return await handleEvaluate(cmd)
            
        case "extract":
            return await handleExtract(cmd)
            
        case "upload":
            return await handleUpload(cmd)
            
        case "download":
            return await handleDownload(cmd)
            
        case "back":
            automation.goBack()
            return .success("Navigated back")
            
        case "forward":
            automation.goForward()
            return .success("Navigated forward")
            
        case "reload", "refresh":
            automation.reload()
            return .success("Page reloaded")
            
        case "networkidle":
            return await handleNetworkIdle(cmd)
            
        default:
            return .failure(.missingParameter("Unknown action: \(cmd.action)"))
        }
    }
    
    private func handleNavigate(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        guard let urlString = cmd.url else {
            return .failure(.missingParameter("url"))
        }
        
        guard let url = URL(string: urlString) else {
            return .failure(.invalidURL(urlString))
        }
        
        automation.load(url)
        
        // Wait for page to start loading
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        return .success("Navigated to \(urlString)")
    }
    
    private func handleClick(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        guard let selector = cmd.selector else {
            return .failure(.missingParameter("selector"))
        }
        
        do {
            try await automation.click(selector)
            return .success("Clicked \(selector)")
        } catch BrowserAutomation.AutomationError.timeout {
            return .failure(.selectorNotFound(selector))
        } catch {
            return .failure(.elementNotInteractable(selector))
        }
    }
    
    private func handleType(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        guard let selector = cmd.selector else {
            return .failure(.missingParameter("selector"))
        }
        
        guard let value = cmd.value else {
            return .failure(.missingParameter("value"))
        }
        
        do {
            try await automation.type(selector, text: value, clear: cmd.clear ?? false)
            return .success("Typed into \(selector)")
        } catch {
            return .failure(.elementNotInteractable(selector))
        }
    }
    
    private func handleSelect(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        guard let selector = cmd.selector, let value = cmd.value else {
            return .failure(.missingParameter("selector and value"))
        }
        
        do {
            try await automation.setValue(selector, value: value)
            return .success("Set value in \(selector)")
        } catch {
            return .failure(.elementNotInteractable(selector))
        }
    }
    
    private func handleWait(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        if let selector = cmd.selector {
            do {
                try await automation.waitForSelector(selector, timeout: 10)
                return .success("Found \(selector)")
            } catch {
                return .failure(.selectorNotFound(selector))
            }
        } else if let text = cmd.value {
            do {
                try await automation.waitForText(text, timeout: 10)
                return .success("Found text: \(text)")
            } catch {
                return .failure(.operationTimeout("waitForText"))
            }
        } else {
            return .failure(.missingParameter("selector or value"))
        }
    }
    
    private func handleScroll(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        if let selector = cmd.selector {
            do {
                try await automation.scrollIntoView(selector)
                return .success("Scrolled to \(selector)")
            } catch {
                return .failure(.selectorNotFound(selector))
            }
        } else {
            // Scroll by amount or to top/bottom
            let direction = cmd.value?.lowercased() ?? "down"
            let script: String
            switch direction {
            case "top":
                script = "window.scrollTo(0, 0)"
            case "bottom":
                script = "window.scrollTo(0, document.body.scrollHeight)"
            case "up":
                script = "window.scrollBy(0, -500)"
            default:
                script = "window.scrollBy(0, 500)"
            }
            
            _ = try? await automation.eval(script)
            return .success("Scrolled \(direction)")
        }
    }
    
    private func handleScreenshot(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        do {
            if let selector = cmd.selector {
                let image = try await automation.screenshotElement(selector)
                if let path = cmd.path {
                    try await saveImage(image, to: URL(fileURLWithPath: path))
                    return .success("Screenshot saved to \(path)")
                }
                return .success("Screenshot captured")
            } else {
                let image = try await automation.takeSnapshot()
                if let path = cmd.path {
                    try await saveImage(image, to: URL(fileURLWithPath: path))
                    return .success("Screenshot saved to \(path)")
                }
                return .success("Screenshot captured")
            }
        } catch {
            return .failure(.operationTimeout("screenshot"))
        }
    }
    
    private func handleEvaluate(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        guard let script = cmd.value else {
            return .failure(.missingParameter("script"))
        }
        
        do {
            let result = try await automation.eval(script)
            if let result = result {
                return .success("Result: \(result)")
            }
            return .success("Script executed successfully")
        } catch {
            return .failure(.invalidScript(error.localizedDescription))
        }
    }
    
    private func handleExtract(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        guard let selector = cmd.selector else {
            return .failure(.missingParameter("selector"))
        }
        
        let extractType = cmd.value?.lowercased() ?? "text"
        
        do {
            switch extractType {
            case "text":
                let text = try await automation.innerText(selector)
                return .success(text)
            case "html":
                let html = try await automation.eval("document.querySelector(\(selector.jsQuoted))?.outerHTML ?? ''") as? String ?? ""
                return .success(html)
            case "attribute":
                guard let attrName = cmd.path else {
                    return .failure(.missingParameter("attribute name in path"))
                }
                let attr = try await automation.attribute(selector, name: attrName)
                return .success(attr)
            default:
                let text = try await automation.innerText(selector)
                return .success(text)
            }
        } catch {
            return .failure(.selectorNotFound(selector))
        }
    }
    
    private func handleUpload(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        guard let selector = cmd.selector, let path = cmd.path else {
            return .failure(.missingParameter("selector and path"))
        }
        
        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path))
        }
        
        do {
            try await automation.uploadFile(selector, fileURL: fileURL)
            return .success("Uploaded file: \(path)")
        } catch {
            return .failure(.elementNotInteractable(selector))
        }
    }
    
    private func handleDownload(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        // Trigger download and wait for it
        guard let selector = cmd.selector else {
            return .failure(.missingParameter("selector"))
        }
        
        do {
            try await automation.click(selector)
            // Give download time to start
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            return .success("Download triggered")
        } catch {
            return .failure(.selectorNotFound(selector))
        }
    }
    
    private func handleNetworkIdle(_ cmd: BrowserCommand) async -> Result<String, BrowserError> {
        do {
            let timeout = Double(cmd.value ?? "10") ?? 10.0
            try await automation.waitForNetworkIdle(timeout: timeout)
            return .success("Network is idle")
        } catch {
            return .failure(.operationTimeout("network idle"))
        }
    }
    
    private func saveImage(_ image: NSImage, to url: URL) async throws {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw BrowserError.operationTimeout("image encoding")
        }
        try png.write(to: url)
    }
}

// Convenience extensions for command building
extension BrowserCommand {
    static func navigate(to url: String) -> BrowserCommand {
        BrowserCommand(action: "navigate", url: url, selector: nil, value: nil, clear: nil, path: nil)
    }
    
    static func click(_ selector: String) -> BrowserCommand {
        BrowserCommand(action: "click", url: nil, selector: selector, value: nil, clear: nil, path: nil)
    }
    
    static func type(_ text: String, into selector: String, clear: Bool = false) -> BrowserCommand {
        BrowserCommand(action: "type", url: nil, selector: selector, value: text, clear: clear, path: nil)
    }
    
    static func wait(for selector: String) -> BrowserCommand {
        BrowserCommand(action: "wait", url: nil, selector: selector, value: nil, clear: nil, path: nil)
    }
    
    static func screenshot(selector: String? = nil, saveTo path: String? = nil) -> BrowserCommand {
        BrowserCommand(action: "screenshot", url: nil, selector: selector, value: nil, clear: nil, path: path)
    }
    
    static func evaluate(_ script: String) -> BrowserCommand {
        BrowserCommand(action: "evaluate", url: nil, selector: nil, value: script, clear: nil, path: nil)
    }
}
