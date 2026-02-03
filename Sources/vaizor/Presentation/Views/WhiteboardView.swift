import SwiftUI
import WebKit

struct WhiteboardView: View {
    @Binding var isPresented: Bool
    @State private var htmlContent: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .foregroundStyle(.blue)

                Text("Whiteboard")
                    .font(.headline)

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Canvas area
            if htmlContent.isEmpty {
                emptyState
            } else {
                WebView(htmlContent: $htmlContent)
            }
        }
        .frame(width: 800, height: 600)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Whiteboard Canvas")
                .font(.title2)
                .fontWeight(.semibold)

            Text("AI-generated visualizations, charts, and web content will appear here")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 12) {
                Button {
                    loadSampleHTML()
                } label: {
                    Label("Load Sample", systemImage: "doc.text")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    htmlContent = ""
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    private func loadSampleHTML() {
        htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                    padding: 20px;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                    color: white;
                    margin: 0;
                }
                .card {
                    background: rgba(255, 255, 255, 0.1);
                    backdrop-filter: blur(10px);
                    border-radius: 16px;
                    padding: 24px;
                    margin: 20px 0;
                }
                h1 { margin-top: 0; }
                .chart {
                    display: flex;
                    gap: 10px;
                    margin-top: 20px;
                }
                .bar {
                    flex: 1;
                    background: rgba(255, 255, 255, 0.8);
                    border-radius: 8px;
                    min-height: 100px;
                    display: flex;
                    align-items: flex-end;
                    justify-content: center;
                    padding-bottom: 10px;
                    color: #333;
                    font-weight: bold;
                }
            </style>
        </head>
        <body>
            <div class="card">
                <h1>✨ Sample Whiteboard</h1>
                <p>This is a sample visualization rendered in the whiteboard canvas.</p>
                <div class="chart">
                    <div class="bar" style="height: 150px;">Jan</div>
                    <div class="bar" style="height: 200px;">Feb</div>
                    <div class="bar" style="height: 180px;">Mar</div>
                    <div class="bar" style="height: 220px;">Apr</div>
                </div>
            </div>
        </body>
        </html>
        """
    }
}

struct WebView: NSViewRepresentable {
    @Binding var htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Finished loading
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            AppLogger.shared.log("WebView failed to load: \(error.localizedDescription)", level: .warning)
        }

        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            // Block external navigation for security
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               (url.scheme == "http" || url.scheme == "https") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
