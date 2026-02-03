import SwiftUI
import WebKit
import AppKit

@MainActor
final class BrowserAutomation: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView

    @Published var url: URL?
    @Published var title: String = ""
    @Published var isLoading: Bool = false
    @Published var progress: Double = 0

    private var nextUploadURL: URL? = nil

    override init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences.preferredContentMode = .recommended
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
        self.webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
    }

    deinit {
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
        webView.removeObserver(self, forKeyPath: "title")
    }

    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progress = webView.estimatedProgress
        } else if keyPath == "title" {
            title = webView.title ?? ""
        }
    }

    // MARK: - Navigation
    func load(_ url: URL) {
        self.url = url
        webView.load(URLRequest(url: url))
    }

    func load(html: String, baseURL: URL? = nil) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        url = webView.url
        title = webView.title ?? ""
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
    }

    // MARK: - WKUIDelegate (file upload support)
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        if let url = nextUploadURL {
            completionHandler([url])
            nextUploadURL = nil
        } else {
            completionHandler(nil)
        }
    }

    // MARK: - JavaScript
    func eval(_ js: String) async throws -> Any? {
        try await webView.evaluateJavaScriptAsync(js)
    }

    // MARK: - Automation Helpers
    func waitForSelector(_ selector: String, timeout: TimeInterval = 10) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let exists = try await eval("document.querySelector(\(selector.jsQuoted)) !== null") as? Bool ?? false
            if exists { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        throw AutomationError.timeout("waitForSelector timed out for \(selector)")
    }

    func click(_ selector: String) async throws {
        try await waitForSelector(selector)
        _ = try await eval(
            """
            (function(){
                const el = document.querySelector(\(selector.jsQuoted));
                if (!el) { return 'error:not found'; }
                el.click();
                return 'ok';
            })();
            """
        )
    }

    func type(_ selector: String, text: String, clear: Bool = false) async throws {
        try await waitForSelector(selector)
        let js = """
            (function(){
               const el = document.querySelector(\(selector.jsQuoted));
               if (!el) { return 'error:not found'; }
               if ('value' in el) {
                   \(clear ? "el.value='';" : "")
                   el.focus();
                   el.value = el.value + \(text.jsQuoted);
                   el.dispatchEvent(new Event('input', {bubbles:true}));
                   el.dispatchEvent(new Event('change', {bubbles:true}));
                   return 'ok';
               }
               return 'error:not input';
            })();
        """
        _ = try await eval(js)
    }

    func setValue(_ selector: String, value: String) async throws {
        try await waitForSelector(selector)
        let js = """
            (function(){
               const el = document.querySelector(\(selector.jsQuoted));
               if (!el) { return 'error:not found'; }
               if ('value' in el) {
                   el.value = \(value.jsQuoted);
                   el.dispatchEvent(new Event('input', {bubbles:true}));
                   el.dispatchEvent(new Event('change', {bubbles:true}));
                   return 'ok';
               }
               return 'error:not input';
            })();
        """
        _ = try await eval(js)
    }

    func innerText(_ selector: String) async throws -> String {
        try await waitForSelector(selector)
        let js = "document.querySelector(\(selector.jsQuoted))?.innerText ?? ''"
        return (try await eval(js) as? String) ?? ""
    }

    func attribute(_ selector: String, name: String) async throws -> String {
        try await waitForSelector(selector)
        let js = "document.querySelector(\(selector.jsQuoted))?.getAttribute(\(name.jsQuoted)) ?? ''"
        return (try await eval(js) as? String) ?? ""
    }

    func scrollIntoView(_ selector: String, behavior: String = "smooth") async throws {
        try await waitForSelector(selector)
        let js = """
            (function(){
                const el = document.querySelector(\(selector.jsQuoted));
                if (!el) return 'error:not found';
                el.scrollIntoView({behavior: \(behavior.jsQuoted), block:'center'});
                return 'ok';
            })();
        """
        _ = try await eval(js)
    }

    func takeSnapshot() async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            let conf = WKSnapshotConfiguration()
            conf.afterScreenUpdates = true
            webView.takeSnapshot(with: conf) { image, error in
                if let error { continuation.resume(throwing: error) }
                else if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: AutomationError.unknown("No image")) }
            }
        }
    }

    // MARK: - Network Tracking & Idle Wait

    func installNetworkTracker() async {
        let js = """
        (function(){
          if (window.__pendingRequests) return;
          window.__pendingRequests = 0;
          const origFetch = window.fetch;
          window.fetch = function(){ window.__pendingRequests++; return origFetch.apply(this, arguments).finally(()=>{ window.__pendingRequests--; }); };
          const origOpen = XMLHttpRequest.prototype.open;
          const origSend = XMLHttpRequest.prototype.send;
          XMLHttpRequest.prototype.open = function(){ this.__tracked = true; return origOpen.apply(this, arguments); };
          XMLHttpRequest.prototype.send = function(){ if (this.__tracked){ window.__pendingRequests++; this.addEventListener('loadend', ()=>{ window.__pendingRequests--; }); } return origSend.apply(this, arguments); };
        })();
        """
        _ = try? await eval(js)
    }

    func waitForNetworkIdle(timeout: TimeInterval = 10, idleDuration: TimeInterval = 0.6) async throws {
        await installNetworkTracker()
        let start = Date()
        var lastZero = Date()
        while Date().timeIntervalSince(start) < timeout {
            let pending = (try? await eval("window.__pendingRequests || 0") as? Int) ?? 0
            if pending == 0 {
                if Date().timeIntervalSince(lastZero) >= idleDuration { return }
            } else {
                lastZero = Date()
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        throw AutomationError.timeout("Network idle wait timed out")
    }

    // MARK: - DOM Helpers

    func clickByText(_ text: String, exact: Bool = false) async throws {
        let js = """
          (function(){
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            const needle = \(text.jsQuoted);
            let node;
            while (node = walker.nextNode()){
              const t = node.nodeValue.trim();
              if (!t) continue;
              if ((\(exact ? "t===needle" : "t.includes(needle)"))) {
                const el = node.parentElement; if (!el) return 'error:no element';
                el.scrollIntoView({behavior:'auto', block:'center'}); el.click(); return 'ok';
              }
            }
            return 'error:not found';
          })();
        """
        _ = try await eval(js)
    }

    func waitForText(_ text: String, timeout: TimeInterval = 10) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            let found = (try? await eval("document.body && document.body.innerText.includes(\(text.jsQuoted))") as? Bool) ?? false
            if found { return }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        throw AutomationError.timeout("waitForText timed out for \(text)")
    }

    func queryAll(_ selector: String) async throws -> [String] {
        let js = """
          Array.from(document.querySelectorAll(\(selector.jsQuoted))).map(el=>el.innerText||el.textContent||'')
        """
        return (try await eval(js) as? [String]) ?? []
    }

    // MARK: - Element Screenshot & Upload Helpers

    func screenshotElement(_ selector: String) async throws -> NSImage {
        try await scrollIntoView(selector)
        let rectJS = """
          (function(){ const r = document.querySelector(\(selector.jsQuoted))?.getBoundingClientRect(); if(!r) return null; return {x:r.x,y:r.y,width:r.width,height:r.height}; })();
        """
        guard let rect = try await eval(rectJS) as? [String: Any],
              let x = rect["x"] as? CGFloat, let y = rect["y"] as? CGFloat,
              let w = rect["width"] as? CGFloat, let h = rect["height"] as? CGFloat else {
            throw AutomationError.unknown("No rect")
        }
        let image = try await takeSnapshot()
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let cropRect = CGRect(x: x*scale, y: (image.size.height - (y+h)*scale), width: w*scale, height: h*scale)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil), let cropped = cg.cropping(to: cropRect) else {
            return image
        }
        return NSImage(cgImage: cropped, size: NSSize(width: w*scale, height: h*scale))
    }

    func uploadFile(_ selector: String, fileURL: URL) async throws {
        nextUploadURL = fileURL
        _ = try await eval("document.querySelector(\(selector.jsQuoted))?.click()")
    }

    enum AutomationError: Error { case timeout(String); case unknown(String) }
}

extension WKWebView {
    @MainActor
    func evaluateJavaScriptAsync(_ script: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            self.evaluateJavaScript(script) { result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result) }
            }
        }
    }
}

extension String {
    var jsQuoted: String {
        let escaped = self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

struct BrowserAutomationView: NSViewRepresentable {
    @ObservedObject var automation: BrowserAutomation
    func makeNSView(context: Context) -> WKWebView { automation.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// Simple command model and dispatcher for automation tools
struct BrowserCommand: Codable {
    var action: String
    var url: String?
    var selector: String?
    var value: String?
    var clear: Bool?
    var path: String?
}

@MainActor
final class BrowserTool: ObservableObject {
    let automation: BrowserAutomation
    init(automation: BrowserAutomation) { self.automation = automation }

    func handle(_ cmd: BrowserCommand) async -> String {
        switch cmd.action.lowercased() {
        case "open":
            guard let u = cmd.url, let url = URL(string: u) else { return "error: bad url" }
            automation.load(url)
            return "ok"
        case "click":
            guard let sel = cmd.selector else { return "error: missing selector" }
            do { try await automation.click(sel); return "ok" } catch { return "error: \(error)" }
        case "type":
            guard let sel = cmd.selector, let val = cmd.value else { return "error: missing selector/value" }
            do { try await automation.type(sel, text: val, clear: cmd.clear ?? false); return "ok" } catch { return "error: \(error)" }
        case "waitforselector":
            guard let sel = cmd.selector else { return "error: missing selector" }
            do { try await automation.waitForSelector(sel); return "ok" } catch { return "error: \(error)" }
        case "evaluate":
            guard let script = cmd.value else { return "error: missing script" }
            do { _ = try await automation.eval(script); return "ok" } catch { return "error: \(error)" }
        case "openhtml":
            if let html = cmd.value { automation.load(html: html); return "ok" } else { return "error: missing html" }
        case "clickbytext":
            if let t = cmd.value { do { try await automation.clickByText(t) ; return "ok" } catch { return "error: \(error)" } } else { return "error: missing value" }
        case "waitfortext":
            if let t = cmd.value { do { try await automation.waitForText(t); return "ok" } catch { return "error: \(error)" } } else { return "error: missing value" }
        case "networkidle":
            do { try await automation.waitForNetworkIdle(); return "ok" } catch { return "error: \(error)" }
        case "screenshotelement":
            if let sel = cmd.selector { do { let img = try await automation.screenshotElement(sel); if let p = cmd.path { try await save(image: img, to: URL(fileURLWithPath: p)); return "ok" }; return "ok" } catch { return "error: \(error)" } } else { return "error: missing selector" }
        case "uploadfile":
            if let sel = cmd.selector, let p = cmd.path { do { try await automation.uploadFile(sel, fileURL: URL(fileURLWithPath: p)); return "ok" } catch { return "error: \(error)" } } else { return "error: missing selector/path" }
        case "osscreenshot":
            if let p = cmd.path { do { try SystemScreenshot.saveMainDisplay(to: URL(fileURLWithPath: p)); return "ok" } catch { return "error: \(error)" } } else { return "error: missing path" }
        default:
            return "error: unknown action"
        }
    }
}
private func save(image: NSImage, to url: URL) async throws {
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { throw BrowserAutomation.AutomationError.unknown("encode") }
    try png.write(to: url)
}

