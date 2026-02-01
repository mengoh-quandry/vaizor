import SwiftUI
import WebKit
import AppKit

/// View for rendering various code visualizations
struct VisualizationView: View {
    let type: VisualizationType
    let content: String
    let messageId: UUID
    
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        Group {
            switch type {
            case .html:
                HTMLRenderView(html: content, messageId: messageId)
            case .mermaid:
                MermaidDiagramView(mermaidCode: content, messageId: messageId)
            case .excalidraw:
                ExcalidrawView(excalidrawData: content, messageId: messageId)
            case .svg:
                SVGView(svgContent: content)
            }
        }
    }
}

// MARK: - HTML Renderer

struct HTMLRenderView: View {
    let html: String
    let messageId: UUID
    
    var body: some View {
        VisualizationWebView(html: sanitizedHTML, messageId: messageId)
            .frame(minHeight: 200, idealHeight: 400, maxHeight: 800)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var sanitizedHTML: String {
        // Basic HTML sanitization - remove dangerous scripts while preserving structure
        var sanitized = html
        
        // Remove script tags
        sanitized = sanitized.replacingOccurrences(
            of: #"<script[\s\S]*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove javascript: protocols
        sanitized = sanitized.replacingOccurrences(
            of: #"javascript:"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove on* event handlers
        sanitized = sanitized.replacingOccurrences(
            of: #"\s+on\w+\s*=\s*["'][^"']*["']"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Wrap in proper HTML structure if needed
        if !sanitized.contains("<html") {
            sanitized = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                        padding: 16px;
                        margin: 0;
                        background: white;
                        color: #333;
                    }
                    @media (prefers-color-scheme: dark) {
                        body {
                            background: #1e1e1e;
                            color: #e0e0e0;
                        }
                    }
                </style>
            </head>
            <body>
            \(sanitized)
            </body>
            </html>
            """
        }
        
        return sanitized
    }
}

// MARK: - Mermaid Diagram Renderer

struct MermaidDiagramView: View {
    let mermaidCode: String
    let messageId: UUID
    
    var body: some View {
        VisualizationWebView(html: mermaidHTML, messageId: messageId)
            .frame(minHeight: 200, idealHeight: 400, maxHeight: 800)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var mermaidHTML: String {
        let encodedCode = mermaidCode
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")

        // SECURITY: Use bundled mermaid.min.js only (no CDN)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="js/mermaid.min.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 16px;
                    background: white;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        background: #1e1e1e;
                    }
                }
                .mermaid {
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
            </style>
        </head>
        <body>
            <div class="mermaid">
        \(encodedCode)
            </div>
            <script>
                mermaid.initialize({
                    startOnLoad: true,
                    theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default',
                    securityLevel: 'loose',
                    flowchart: { useMaxWidth: true, htmlLabels: true }
                });
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Excalidraw Renderer

struct ExcalidrawView: View {
    let excalidrawData: String
    let messageId: UUID
    
    var body: some View {
        VisualizationWebView(html: excalidrawHTML, messageId: messageId)
            .frame(minHeight: 300, idealHeight: 500, maxHeight: 1000)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var excalidrawHTML: String {
        let encodedData = excalidrawData
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")

        // SECURITY: Use bundled React, ReactDOM, and Excalidraw only (no CDN)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="js/react.min.js"></script>
            <script src="js/react-dom.min.js"></script>
            <script src="js/excalidraw.min.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background: white;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        background: #1e1e1e;
                    }
                }
                #excalidraw-container {
                    width: 100%;
                    height: 100vh;
                    min-height: 500px;
                }
                .error-message {
                    padding: 20px;
                    color: #ff6b6b;
                    font-family: -apple-system, sans-serif;
                }
            </style>
        </head>
        <body>
            <div id="excalidraw-container"></div>
            <script>
                try {
                    const data = JSON.parse(`\(encodedData)`);
                    if (typeof ExcalidrawLib !== 'undefined' && ExcalidrawLib.Excalidraw) {
                        const excalidrawAPI = ExcalidrawLib.Excalidraw.init({
                            target: document.getElementById('excalidraw-container'),
                            elements: data.elements || [],
                            appState: data.appState || {},
                            files: data.files || {}
                        });
                    } else {
                        document.getElementById('excalidraw-container').innerHTML =
                            '<div class="error-message">Excalidraw library not loaded</div>';
                    }
                } catch (error) {
                    document.getElementById('excalidraw-container').innerHTML =
                        '<div class="error-message">Error loading Excalidraw: ' + error.message + '</div>';
                }
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - SVG Renderer

struct SVGView: View {
    let svgContent: String
    
    var body: some View {
        // Parse and render SVG directly in SwiftUI
        if let svgData = svgContent.data(using: .utf8),
           let nsImage = NSImage(data: svgData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 600)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        } else {
            // Fallback to VisualizationWebView for complex SVG
            VisualizationWebView(html: """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body {
                        margin: 0;
                        padding: 16px;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        background: white;
                    }
                    @media (prefers-color-scheme: dark) {
                        body {
                            background: #1e1e1e;
                        }
                    }
                    svg {
                        max-width: 100%;
                        height: auto;
                    }
                </style>
            </head>
            <body>
            \(svgContent)
            </body>
            </html>
            """, messageId: UUID())
            .frame(minHeight: 200, idealHeight: 400, maxHeight: 800)
            .cornerRadius(8)
        }
    }
}

// MARK: - WebView Wrapper

struct VisualizationWebView: NSViewRepresentable {
    let html: String
    let messageId: UUID

    // MARK: - Bundled JS Path Discovery

    /// Path to bundled JavaScript libraries
    static var bundledJSPath: URL? = {
        // Check app bundle Resources/js
        if let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("js") {
            if FileManager.default.fileExists(atPath: bundlePath.path) {
                return bundlePath
            }
        }

        // Check Resources/js in development
        let devPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // Views
            .deletingLastPathComponent() // Presentation
            .deletingLastPathComponent() // vaizor
            .deletingLastPathComponent() // Sources
            .appendingPathComponent("Resources/js")

        if FileManager.default.fileExists(atPath: devPath.path) {
            return devPath
        }

        return nil
    }()

    /// Check if bundled libraries are available
    static var hasBundledLibraries: Bool {
        guard let jsPath = bundledJSPath else { return false }
        let requiredFiles = ["mermaid.min.js", "react.min.js", "react-dom.min.js", "excalidraw.min.js"]
        return requiredFiles.allSatisfy { file in
            FileManager.default.fileExists(atPath: jsPath.appendingPathComponent(file).path)
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.isElementFullscreenEnabled = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        #if DEBUG
        webView.isInspectable = true
        #endif

        // SECURITY: Load HTML with bundled JS libraries only (no network calls)
        loadHTMLWithBundledJS(webView: webView, html: html)

        return webView
    }

    private func loadHTMLWithBundledJS(webView: WKWebView, html: String) {
        // SECURITY: Only use bundled libraries - no external network calls
        guard Self.hasBundledLibraries, let bundledJS = Self.bundledJSPath else {
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"></head>
            <body style="font-family: -apple-system, sans-serif; padding: 20px; background: #1c1c1e; color: #ff6b6b;">
                <h3>Libraries Not Found</h3>
                <p>The bundled JavaScript libraries could not be located.</p>
                <p style="color: #888; font-size: 12px;">Please rebuild the app with <code>./build-app.sh</code></p>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("viz_\(messageId.uuidString)")
        let jsDir = tempDir.appendingPathComponent("js")
        let htmlFile = tempDir.appendingPathComponent("index.html")

        do {
            // Create temp directory structure
            try FileManager.default.createDirectory(at: jsDir, withIntermediateDirectories: true)

            // Copy bundled JS files to temp directory
            let jsFiles = try FileManager.default.contentsOfDirectory(at: bundledJS, includingPropertiesForKeys: nil)
            for file in jsFiles where file.pathExtension == "js" {
                let destFile = jsDir.appendingPathComponent(file.lastPathComponent)
                if !FileManager.default.fileExists(atPath: destFile.path) {
                    try FileManager.default.copyItem(at: file, to: destFile)
                }
            }

            // Replace relative js/ paths with absolute file:// URLs
            let jsURL = jsDir.absoluteString
            let processedHTML = html.replacingOccurrences(
                of: "src=\"js/",
                with: "src=\"\(jsURL)/"
            )

            // Write HTML file
            try processedHTML.write(to: htmlFile, atomically: true, encoding: .utf8)

            // Load with read access to temp directory (for local JS files)
            webView.loadFileURL(htmlFile, allowingReadAccessTo: tempDir)
        } catch {
            AppLogger.shared.logError(error, context: "VisualizationView: Error setting up temp directory")
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            // Block navigation to external URLs for security
            if navigationAction.navigationType == .linkActivated {
                if let url = navigationAction.request.url,
                   url.scheme == "http" || url.scheme == "https" {
                    // Allow opening in external browser
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
