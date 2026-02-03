import SwiftUI
import WebKit

/// View for previewing HTML, CSS, and React code
struct WebPreviewView: View {
    let htmlContent: String
    let language: CodeLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var viewportSize: ViewportSize = .desktop

    enum ViewportSize: String, CaseIterable {
        case mobile = "Mobile"
        case tablet = "Tablet"
        case desktop = "Desktop"

        var width: CGFloat {
            switch self {
            case .mobile: return 375
            case .tablet: return 768
            case .desktop: return 1200
            }
        }
    }

    private var fullHTML: String {
        switch language {
        case .html:
            // Check if it's a complete HTML document
            if htmlContent.lowercased().contains("<html") || htmlContent.lowercased().contains("<!doctype") {
                return htmlContent
            }
            // Wrap in basic HTML structure
            return wrapInHTMLDocument(htmlContent)

        case .css:
            return wrapInHTMLDocument("""
            <style>\(htmlContent)</style>
            <div class="demo">
                <h1>CSS Preview</h1>
                <p>This is a paragraph demonstrating your styles.</p>
                <button>Sample Button</button>
                <div class="box">A sample box</div>
            </div>
            """)

        case .react:
            return createReactPreview(htmlContent)

        default:
            return wrapInHTMLDocument(htmlContent)
        }
    }

    private func wrapInHTMLDocument(_ content: String) -> String {
        // All scripts from bundled local files only (no network)
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <!-- Tailwind CSS (bundled) -->
            <script src="js/tailwind.js"></script>
            <script>
                tailwind.config = {
                    darkMode: 'media',
                    theme: {
                        extend: {
                            fontFamily: {
                                sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro', 'Helvetica Neue', 'sans-serif'],
                            },
                        }
                    }
                }
            </script>
            <!-- Lucide Icons (bundled) -->
            <script src="js/lucide.min.js"></script>
            <style>
                * { box-sizing: border-box; }
            </style>
        </head>
        <body class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 p-4">
        \(content)
        <script>
            if (typeof lucide !== 'undefined') {
                lucide.createIcons();
            }
        </script>
        </body>
        </html>
        """
    }

    private func createReactPreview(_ code: String) -> String {
        // Pre-process: Strip ES6 imports since we use UMD builds where React is global
        var processedCode = code

        // Remove import statements for react, react-dom (we use UMD globals)
        processedCode = processedCode.replacingOccurrences(
            of: #"import\s+(?:React|\{[^}]*\}|[\w\s,*]+)\s+from\s+['\"]react['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )
        processedCode = processedCode.replacingOccurrences(
            of: #"import\s+(?:ReactDOM|\{[^}]*\}|[\w\s,*]+)\s+from\s+['\"]react-dom['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )
        processedCode = processedCode.replacingOccurrences(
            of: #"import\s+(?:ReactDOM|\{[^}]*\}|[\w\s,*]+)\s+from\s+['\"]react-dom/client['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Remove CSS/style imports: import './file.css';
        processedCode = processedCode.replacingOccurrences(
            of: #"import\s+['\"][^'\"]+\.(css|scss|sass|less|style)['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Remove any remaining generic imports with 'from'
        processedCode = processedCode.replacingOccurrences(
            of: #"import\s+.*from\s+['\"][^'\"]+['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Strip TypeScript type annotations
        processedCode = processedCode.replacingOccurrences(
            of: #":\s*React\.(FC|FunctionComponent|ComponentType)(<[^>]*>)?\s*="#,
            with: " =",
            options: .regularExpression
        )
        processedCode = processedCode.replacingOccurrences(
            of: #"(const|let|var)\s+(\w+)\s*:\s*[A-Za-z<>\[\]|&\s,]+\s*="#,
            with: "$1 $2 =",
            options: .regularExpression
        )
        processedCode = processedCode.replacingOccurrences(
            of: #"(\w+)\s*:\s*[A-Za-z<>\[\]|&\s]+(?=[,)])"#,
            with: "$1",
            options: .regularExpression
        )
        processedCode = processedCode.replacingOccurrences(
            of: #"\)\s*:\s*[A-Za-z<>\[\]|&\s]+\s*=>"#,
            with: ") =>",
            options: .regularExpression
        )
        processedCode = processedCode.replacingOccurrences(
            of: #"\s+as\s+[A-Za-z<>\[\]|&\s]+"#,
            with: "",
            options: .regularExpression
        )

        // Remove export statements
        processedCode = processedCode.replacingOccurrences(
            of: #"export\s+default\s+"#,
            with: "",
            options: .regularExpression
        )

        let escapedCode = processedCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        // All scripts from bundled local files only (no network)
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <!-- Tailwind CSS (bundled) -->
            <script src="js/tailwind.js"></script>
            <script>
                tailwind.config = {
                    darkMode: 'media',
                    theme: {
                        extend: {
                            fontFamily: {
                                sans: ['-apple-system', 'BlinkMacSystemFont', 'SF Pro', 'Helvetica Neue', 'sans-serif'],
                            },
                        }
                    }
                }
            </script>
            <!-- Lucide Icons (bundled) -->
            <script src="js/lucide.min.js"></script>
            <style>
                .loading {
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                    min-height: 200px;
                    color: #666;
                }
                .loading-spinner {
                    width: 32px;
                    height: 32px;
                    border: 3px solid #e0e0e0;
                    border-top-color: #007AFF;
                    border-radius: 50%;
                    animation: spin 1s linear infinite;
                    margin-bottom: 12px;
                }
                @keyframes spin { to { transform: rotate(360deg); } }
                .error {
                    color: #ff3b30;
                    padding: 16px;
                    background: rgba(255, 59, 48, 0.1);
                    border-radius: 8px;
                    font-family: ui-monospace, monospace;
                    font-size: 13px;
                    white-space: pre-wrap;
                }
                #root { min-height: 100px; }
            </style>
        </head>
        <body class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 p-4">
            <div id="root">
                <div class="loading">
                    <div class="loading-spinner"></div>
                    <div>Loading React...</div>
                </div>
            </div>
            <script>
                function loadScript(src, name) {
                    return new Promise(function(resolve, reject) {
                        var script = document.createElement('script');
                        script.src = src;
                        script.onload = resolve;
                        script.onerror = function() { reject(new Error('Failed to load ' + (name || src))); };
                        document.head.appendChild(script);
                    });
                }

                // All scripts from bundled local files (no network calls)
                loadScript('js/react.min.js', 'react')
                    .then(function() { return loadScript('js/react-dom.min.js', 'reactDom'); })
                    .then(function() { return loadScript('js/babel.min.js', 'babel'); })
                    .then(function() {
                        // Load optional libraries in parallel
                        return Promise.all([
                            loadScript('js/recharts.min.js', 'recharts').catch(function() {}),
                            loadScript('js/dayjs.min.js', 'dayjs').catch(function() {})
                        ]);
                    })
                    .then(function() {
                        try {
                            // Make React hooks available as globals
                            window.useState = React.useState;
                            window.useEffect = React.useEffect;
                            window.useRef = React.useRef;
                            window.useMemo = React.useMemo;
                            window.useCallback = React.useCallback;
                            window.useContext = React.useContext;
                            window.useReducer = React.useReducer;
                            window.useLayoutEffect = React.useLayoutEffect;

                            // Make Recharts components available globally
                            if (typeof Recharts !== 'undefined') {
                                window.LineChart = Recharts.LineChart;
                                window.BarChart = Recharts.BarChart;
                                window.PieChart = Recharts.PieChart;
                                window.AreaChart = Recharts.AreaChart;
                                window.XAxis = Recharts.XAxis;
                                window.YAxis = Recharts.YAxis;
                                window.CartesianGrid = Recharts.CartesianGrid;
                                window.Tooltip = Recharts.Tooltip;
                                window.Legend = Recharts.Legend;
                                window.Line = Recharts.Line;
                                window.Bar = Recharts.Bar;
                                window.Pie = Recharts.Pie;
                                window.Area = Recharts.Area;
                                window.Cell = Recharts.Cell;
                                window.ResponsiveContainer = Recharts.ResponsiveContainer;
                            }

                            // Make Lucide icons available
                            if (typeof lucide !== 'undefined') {
                                window.LucideIcons = lucide;
                            }

                            // Register Chart.js components (v4 requires explicit registration)
                            if (typeof Chart !== 'undefined' && Chart.register) {
                                Chart.register(...Chart.registerables || []);
                                window.Chart = Chart;
                            }

                            var userCode = `\(escapedCode)`;
                            var transformed = Babel.transform(userCode, { presets: ['react'] }).code;

                            // Find component names in transformed code
                            var componentNames = [];
                            var pascalCasePattern = /(?:var|let|const) +([A-Z][a-zA-Z0-9]*) *=/g;
                            var funcPattern = /function +([A-Z][a-zA-Z0-9]*) *[(]/g;
                            var m;
                            while ((m = pascalCasePattern.exec(transformed)) !== null) componentNames.push(m[1]);
                            while ((m = funcPattern.exec(transformed)) !== null) componentNames.push(m[1]);

                            // Build code that exports components to window
                            var moduleCode = transformed + ';';
                            componentNames.forEach(function(name) {
                                moduleCode += 'if (typeof ' + name + ' !== "undefined") { window.__COMPONENTS__ = window.__COMPONENTS__ || {}; window.__COMPONENTS__["' + name + '"] = ' + name + '; }';
                            });

                            new Function(moduleCode)();

                            var root = ReactDOM.createRoot(document.getElementById('root'));
                            var Comp = null;

                            // Check extracted components
                            if (window.__COMPONENTS__) {
                                var extracted = Object.keys(window.__COMPONENTS__);
                                for (var i = 0; i < extracted.length; i++) {
                                    if (typeof window.__COMPONENTS__[extracted[i]] === 'function') {
                                        Comp = window.__COMPONENTS__[extracted[i]];
                                        break;
                                    }
                                }
                            }

                            // Fallback to common names
                            if (!Comp) {
                                var names = ['App', 'Component', 'Main', 'Root', 'Demo', 'Example', 'Dashboard', 'Counter'];
                                for (var j = 0; j < names.length; j++) {
                                    if (typeof window[names[j]] === 'function') { Comp = window[names[j]]; break; }
                                }
                            }

                            if (Comp) {
                                root.render(React.createElement(Comp));
                            } else {
                                document.getElementById('root').innerHTML = '<p style="color:#666;text-align:center;padding:40px;">No React component found.</p>';
                            }
                        } catch (err) {
                            document.getElementById('root').innerHTML = '<div class="error">' + err.message + '</div>';
                        }
                    })
                    .catch(function(err) {
                        document.getElementById('root').innerHTML = '<div class="error">' + err.message + '</div>';
                    });
            </script>
        </body>
        </html>
        """
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(language.displayName + " Preview")
                    .font(.headline)

                Spacer()

                // Viewport size picker
                Picker("Viewport", selection: $viewportSize) {
                    ForEach(ViewportSize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            // Preview area
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    WebPreviewWebView(html: fullHTML, isLoading: $isLoading)
                        .frame(
                            width: viewportSize == .desktop ? geometry.size.width : viewportSize.width,
                            height: max(400, geometry.size.height)
                        )
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(viewportSize == .desktop ? 0 : 8)
                        .shadow(color: viewportSize == .desktop ? .clear : .black.opacity(0.1), radius: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            // Loading indicator
            if isLoading {
                ProgressView("Loading preview...")
                    .padding()
            }
        }
    }
}

// MARK: - WebView Wrapper

struct WebPreviewWebView: NSViewRepresentable {
    let html: String
    @Binding var isLoading: Bool
    private let previewId = UUID()

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Use default (persistent) data store for network access

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Enable developer tools for debugging
        #if DEBUG
        webView.isInspectable = true
        #endif

        // Load HTML via temp file for proper network access
        loadHTMLWithNetworkAccess(webView: webView, html: html)

        return webView
    }

    // Get the path to bundled JS libraries
    private static var bundledJSPath: URL? {
        let fileManager = FileManager.default
        var possiblePaths: [URL] = []

        if let resourceURL = Bundle.main.resourceURL {
            possiblePaths.append(resourceURL.appendingPathComponent("js"))
        }
        if let execURL = Bundle.main.executableURL {
            let buildDir = execURL.deletingLastPathComponent()
            possiblePaths.append(buildDir.appendingPathComponent("Resources/js"))
            possiblePaths.append(buildDir.deletingLastPathComponent().appendingPathComponent("Resources/js"))
            possiblePaths.append(buildDir.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/js"))
        }
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        possiblePaths.append(cwd.appendingPathComponent("Resources/js"))

        for path in possiblePaths {
            if fileManager.fileExists(atPath: path.appendingPathComponent("react.min.js").path) {
                return path
            }
        }
        return nil
    }

    private func loadHTMLWithNetworkAccess(webView: WKWebView, html: String) {
        // SECURITY: Only use bundled libraries - no external network calls
        guard let bundledJS = Self.bundledJSPath else {
            let errorHTML = """
            <!DOCTYPE html><html><head><meta charset="utf-8"></head>
            <body style="font-family: -apple-system; padding: 20px; background: #1c1c1e; color: #ff6b6b;">
            <h3>Libraries Not Found</h3><p>Please rebuild the app with ./build-app.sh</p>
            </body></html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
            return
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("preview_\(previewId.uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Copy bundled JS files
            let jsDir = tempDir.appendingPathComponent("js")
            try FileManager.default.createDirectory(at: jsDir, withIntermediateDirectories: true)

            let jsFiles = ["react.min.js", "react-dom.min.js", "babel.min.js", "prop-types.min.js",
                          "tailwind.js", "lucide.min.js", "recharts.min.js", "dayjs.min.js"]
            for file in jsFiles {
                let src = bundledJS.appendingPathComponent(file)
                let dst = jsDir.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: src.path) {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }

            // Replace relative js/ paths with absolute file:// URLs
            let jsURL = jsDir.absoluteString
            let processedHTML = html.replacingOccurrences(
                of: "src=\"js/",
                with: "src=\"\(jsURL)/"
            )

            let htmlFile = tempDir.appendingPathComponent("index.html")
            try processedHTML.write(to: htmlFile, atomically: true, encoding: .utf8)
            webView.loadFileURL(htmlFile, allowingReadAccessTo: tempDir)
        } catch {
            let errorHTML = """
            <!DOCTYPE html><html><head><meta charset="utf-8"></head>
            <body style="font-family: -apple-system; padding: 20px; background: #1c1c1e; color: #ff6b6b;">
            <h3>Preview Error</h3><p>\(error.localizedDescription)</p>
            </body></html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
        }
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Reload if content changes
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            loadHTMLWithNetworkAccess(webView: webView, html: html)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, html: html)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var lastHTML: String

        init(isLoading: Binding<Bool>, html: String) {
            _isLoading = isLoading
            self.lastHTML = html
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }

        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            // Allow initial load and same-document navigation
            if navigationAction.navigationType == .other || navigationAction.navigationType == .reload {
                decisionHandler(.allow)
                return
            }

            // Open external links in browser
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
