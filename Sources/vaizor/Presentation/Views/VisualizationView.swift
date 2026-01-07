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
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
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
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.jsdelivr.net/npm/@excalidraw/excalidraw@latest/dist/index.umd.js"></script>
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
                            '<div style="padding: 20px;">Excalidraw library loading...</div>';
                    }
                } catch (error) {
                    document.getElementById('excalidraw-container').innerHTML = 
                        '<div style="padding: 20px; color: red;">Error loading Excalidraw: ' + error.message + '</div>';
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
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        if #available(macOS 11.0, *) {
            // Use modern API
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        
        // Security: Disable dangerous features
        if #available(macOS 11.0, *) {
            config.preferences.isElementFullscreenEnabled = false
        }
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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
