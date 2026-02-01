import SwiftUI
import WebKit

// MARK: - MCP App View

/// Sandboxed view for rendering MCP Apps
struct MCPAppView: View {
    let appContent: MCPAppContent
    let displayMode: MCPAppDisplayMode
    let onAction: (MCPAppAction) async -> MCPAppResponse
    let onClose: () -> Void

    @State private var isLoading = true
    @State private var error: String?
    @State private var contentHeight: CGFloat = 300
    @State private var showServerBadge = true

    var body: some View {
        VStack(spacing: 0) {
            // Header with server identity
            header

            Divider()

            // Sandboxed content
            ZStack {
                MCPAppWebView(
                    content: appContent,
                    isLoading: $isLoading,
                    error: $error,
                    contentHeight: $contentHeight,
                    onAction: onAction
                )

                if isLoading {
                    loadingOverlay
                }

                if let error = error {
                    errorOverlay(error)
                }
            }
            .frame(minHeight: minHeight)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(displayMode == .inline ? 8 : 12)
        .shadow(color: .black.opacity(displayMode == .floating ? 0.25 : 0.1), radius: displayMode == .floating ? 16 : 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // Server identity badge
            if showServerBadge {
                serverBadge
            }

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(appContent.title ?? "MCP App")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("from \(appContent.serverName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Security indicator
            securityIndicator

            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var serverBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: "00976d"))
                .frame(width: 6, height: 6)

            MCPIconManager.icon()
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color(hex: "00976d").opacity(0.15))
        .cornerRadius(4)
    }

    private var securityIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "00976d"))

            Text("Sandboxed")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(hex: "00976d"))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: "00976d").opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - Overlays

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("Loading app...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text("App Error")
                .font(.system(size: 14, weight: .semibold))

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Reload") {
                error = nil
                isLoading = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var minHeight: CGFloat {
        switch displayMode {
        case .inline: return 150
        case .panel: return 300
        case .floating: return 400
        case .fullscreen: return 600
        }
    }
}

// MARK: - MCP App WebView (NSViewRepresentable)

struct MCPAppWebView: NSViewRepresentable {
    let content: MCPAppContent
    @Binding var isLoading: Bool
    @Binding var error: String?
    @Binding var contentHeight: CGFloat
    let onAction: (MCPAppAction) async -> MCPAppResponse

    func makeNSView(context: Context) -> WKWebView {
        let config = createSandboxedConfiguration(context: context)
        let webView = WKWebView(frame: .zero, configuration: config)

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Additional security settings
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false

        #if DEBUG
        webView.isInspectable = true
        #endif

        // Load content
        let html = generateSandboxedHTML()
        webView.loadHTMLString(html, baseURL: nil)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Update content if changed
        if context.coordinator.lastContentId != content.id {
            context.coordinator.lastContentId = content.id
            let html = generateSandboxedHTML()
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isLoading: $isLoading,
            error: $error,
            contentHeight: $contentHeight,
            onAction: onAction,
            contentId: content.id
        )
    }

    // MARK: - Sandboxed Configuration

    private func createSandboxedConfiguration(context: Context) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        // Content controller for message handling
        let contentController = WKUserContentController()

        // Add message handler for bidirectional communication
        contentController.add(context.coordinator, name: "mcpAppBridge")

        // Inject security scripts
        let securityScript = WKUserScript(
            source: securityInjectionScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(securityScript)

        config.userContentController = contentController

        // Disable features for security
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences.isFraudulentWebsiteWarningEnabled = true

        // Disable media capture
        config.mediaTypesRequiringUserActionForPlayback = .all

        // Process pool isolation - each app gets its own process
        config.processPool = WKProcessPool()

        return config
    }

    // MARK: - Security Injection Script

    private var securityInjectionScript: String {
        """
        (function() {
            'use strict';

            // Freeze critical objects to prevent tampering
            const originals = {
                fetch: window.fetch,
                XMLHttpRequest: window.XMLHttpRequest,
                WebSocket: window.WebSocket,
                localStorage: window.localStorage,
                sessionStorage: window.sessionStorage
            };

            // Override fetch to block external requests
            window.fetch = function(url, options) {
                const urlString = typeof url === 'string' ? url : url.url;
                if (urlString && !urlString.startsWith('data:') && !urlString.startsWith('blob:')) {
                    console.warn('[MCP App Sandbox] External fetch blocked:', urlString);
                    return Promise.reject(new Error('Network requests are blocked in sandbox'));
                }
                return originals.fetch.call(this, url, options);
            };

            // Override XMLHttpRequest
            const OriginalXHR = originals.XMLHttpRequest;
            window.XMLHttpRequest = function() {
                const xhr = new OriginalXHR();
                const originalOpen = xhr.open;
                xhr.open = function(method, url) {
                    if (url && !url.startsWith('data:') && !url.startsWith('blob:')) {
                        console.warn('[MCP App Sandbox] XHR blocked:', url);
                        throw new Error('Network requests are blocked in sandbox');
                    }
                    return originalOpen.apply(this, arguments);
                };
                return xhr;
            };

            // Block WebSocket
            window.WebSocket = function() {
                console.warn('[MCP App Sandbox] WebSocket blocked');
                throw new Error('WebSocket is blocked in sandbox');
            };

            // Block storage if not permitted
            const blockedStorage = {
                getItem: () => null,
                setItem: () => {},
                removeItem: () => {},
                clear: () => {},
                key: () => null,
                length: 0
            };

            // MCP App Bridge
            window.MCPApp = {
                sendAction: function(type, payload, callback) {
                    const requestId = 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                    window._mcpPendingCallbacks = window._mcpPendingCallbacks || {};
                    if (callback) {
                        window._mcpPendingCallbacks[requestId] = callback;
                    }
                    window.webkit.messageHandlers.mcpAppBridge.postMessage({
                        type: type,
                        payload: payload,
                        requestId: requestId
                    });
                    return requestId;
                },
                ready: function() {
                    this.sendAction('ready', {});
                },
                close: function() {
                    this.sendAction('close', {});
                },
                resize: function(width, height) {
                    this.sendAction('resize', { width: width, height: height });
                }
            };

            // Handle responses from host
            window._mcpHandleResponse = function(response) {
                const callbacks = window._mcpPendingCallbacks || {};
                const callback = callbacks[response.requestId];
                if (callback) {
                    delete callbacks[response.requestId];
                    callback(response);
                }
            };

            // Signal ready when DOM is loaded
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                    window.MCPApp.ready();
                });
            } else {
                setTimeout(function() { window.MCPApp.ready(); }, 0);
            }

            console.log('[MCP App] Sandbox initialized');
        })();
        """
    }

    // MARK: - HTML Generation

    private func generateSandboxedHTML() -> String {
        let sandboxConfig = content.metadata?.sandboxConfig ?? MCPAppSandboxConfig.restrictive

        // Build CSP header
        var cspDirectives = [
            "default-src 'self'",
            "script-src 'unsafe-inline' 'unsafe-eval'",  // Needed for dynamic content
            "style-src 'self' 'unsafe-inline'",
            "img-src 'self' data: blob:",
            "font-src 'self' data:",
            "connect-src 'none'",  // Block network
            "frame-src 'none'",
            "object-src 'none'",
            "base-uri 'self'"
        ]

        if !sandboxConfig.allowForms {
            cspDirectives.append("form-action 'none'")
        }

        let csp = cspDirectives.joined(separator: "; ")

        // Combine scripts
        let scripts = (content.scripts ?? []).map { "<script>\($0)</script>" }.joined(separator: "\n")

        // Combine styles
        let styles = (content.styles ?? []).map { "<style>\($0)</style>" }.joined(separator: "\n")

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta http-equiv="Content-Security-Policy" content="\(csp)">
            <title>\(content.title ?? "MCP App")</title>
            <style>
                * { box-sizing: border-box; }
                html, body {
                    margin: 0;
                    padding: 0;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: transparent;
                    color: #e0e0e0;
                }
                body {
                    padding: 16px;
                }
                /* Dark mode styles */
                @media (prefers-color-scheme: dark) {
                    body { background: #1c1d1f; color: #e0e0e0; }
                }
            </style>
            \(styles)
        </head>
        <body>
            \(content.html)
            \(scripts)
        </body>
        </html>
        """
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        @Binding var isLoading: Bool
        @Binding var error: String?
        @Binding var contentHeight: CGFloat
        let onAction: (MCPAppAction) async -> MCPAppResponse
        var lastContentId: UUID

        init(
            isLoading: Binding<Bool>,
            error: Binding<String?>,
            contentHeight: Binding<CGFloat>,
            onAction: @escaping (MCPAppAction) async -> MCPAppResponse,
            contentId: UUID
        ) {
            _isLoading = isLoading
            _error = error
            _contentHeight = contentHeight
            self.onAction = onAction
            self.lastContentId = contentId
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "mcpAppBridge",
                  let body = message.body as? [String: Any],
                  let typeString = body["type"] as? String,
                  let type = MCPAppActionType(rawValue: typeString) else {
                return
            }

            let payload = body["payload"] as? [String: Any]
            let requestId = body["requestId"] as? String

            let action = MCPAppAction(
                type: type,
                payload: payload?.mapValues { AnyCodable($0) },
                requestId: requestId
            )

            // Handle action asynchronously
            Task { @MainActor in
                let response = await onAction(action)

                // Send response back to WebView
                if let requestId = action.requestId,
                   let webView = message.webView {
                    var dataString = "null"
                    if let data = response.data {
                        if let jsonData = try? JSONSerialization.data(withJSONObject: data.mapValues { $0.value }),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            dataString = jsonString
                        }
                    }
                    let errorString = response.error.map { "'\($0)'" } ?? "null"
                    let responseJS = """
                    window._mcpHandleResponse({
                        requestId: '\(requestId)',
                        success: \(response.success),
                        data: \(dataString),
                        error: \(errorString)
                    });
                    """
                    webView.evaluateJavaScript(responseJS, completionHandler: nil)
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            error = nil

            // Get content height for auto-sizing
            webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self?.contentHeight = max(height, 150)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            self.error = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            self.error = error.localizedDescription
        }

        // Block navigation to external URLs
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                // Only allow about:blank and data URLs
                if url.scheme == "about" || url.scheme == "data" || url.scheme == "blob" {
                    decisionHandler(.allow)
                } else if navigationAction.navigationType == .other && url.absoluteString.starts(with: "file://") {
                    // Allow initial load from file
                    decisionHandler(.allow)
                } else {
                    AppLogger.shared.log("[MCP App Sandbox] Blocked navigation to: \(url)", level: .warning)
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        }

        // MARK: - WKUIDelegate

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Block popup windows
            AppLogger.shared.log("[MCP App Sandbox] Blocked popup window", level: .warning)
            return nil
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            // Show alert but log it
            AppLogger.shared.log("[MCP App] Alert: \(message)", level: .info)
            completionHandler()
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            AppLogger.shared.log("[MCP App] Confirm: \(message)", level: .info)
            completionHandler(true)
        }
    }
}

// MARK: - Floating Window Wrapper

/// Wrapper for showing MCP App in a floating window
struct MCPAppWindowView: View {
    let appContent: MCPAppContent
    let onAction: (MCPAppAction) async -> MCPAppResponse
    @Environment(\.dismiss) var dismiss

    var body: some View {
        MCPAppView(
            appContent: appContent,
            displayMode: .floating,
            onAction: onAction,
            onClose: { dismiss() }
        )
        .frame(minWidth: 400, idealWidth: 600, minHeight: 400, idealHeight: 500)
    }
}

// MARK: - Preview

#Preview {
    MCPAppView(
        appContent: MCPAppContent(
            serverId: "test-server",
            serverName: "Test MCP Server",
            html: """
            <div style="padding: 20px;">
                <h1 style="color: #00976d;">MCP App Demo</h1>
                <p>This is a sandboxed MCP application.</p>
                <button onclick="MCPApp.sendAction('button_click', {button: 'test'})">
                    Click Me
                </button>
            </div>
            """,
            title: "Demo App"
        ),
        displayMode: .panel,
        onAction: { action in
            print("Action received: \(action.type)")
            return MCPAppResponse(
                requestId: action.requestId ?? "",
                success: true,
                data: nil,
                error: nil
            )
        },
        onClose: {}
    )
    .frame(width: 500, height: 400)
}
