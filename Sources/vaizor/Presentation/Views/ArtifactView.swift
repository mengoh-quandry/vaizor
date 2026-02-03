import SwiftUI
import WebKit
import SystemConfiguration

// MARK: - Liquid Glass Compatibility Modifiers

/// Provides glass effect with fallback for older macOS versions
struct GlassBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool
    
    init(cornerRadius: CGFloat, interactive: Bool = false) {
        self.cornerRadius = cornerRadius
        self.interactive = interactive
    }
    
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            // Fallback: Use translucent material for macOS 15
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// Provides glass button style with fallback
struct GlassButtonStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .buttonStyle(.glass)
        } else {
            // Fallback: Use bordered button style for macOS 15
            content
                .buttonStyle(.bordered)
        }
    }
}

/// Claude-style artifact preview view
struct ArtifactView: View {
    let artifact: Artifact
    let onClose: () -> Void
    @State private var isLoading = true
    @State private var showCode = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            artifactHeader

            Divider()

            // Content
            if showCode {
                codeView
            } else {
                previewView
            }
        }
        .modifier(GlassBackgroundModifier(cornerRadius: 12))
    }

    private var artifactHeader: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: artifact.type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(artifact.type.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Toggle buttons
            Group {
                if #available(macOS 26.0, *) {
                    GlassEffectContainer(spacing: 4.0) {
                        HStack(spacing: 4) {
                            previewCodeButtons
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        previewCodeButtons
                    }
                }
            }

            Divider()
                .frame(height: 20)

            // Close button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .modifier(GlassBackgroundModifier(cornerRadius: 6, interactive: true))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var previewCodeButtons: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCode = false
            }
        } label: {
            Label("Preview", systemImage: "eye")
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .modifier(GlassButtonStyleModifier())
        .disabled(!showCode)
        
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCode = true
            }
        } label: {
            Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
        .modifier(GlassButtonStyleModifier())
        .disabled(showCode)
    }

    private var previewView: some View {
        ZStack {
            ArtifactWebView(artifact: artifact, isLoading: $isLoading, error: $error)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Rendering...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                    Text("Preview Error")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .frame(minHeight: 300)
    }

    private var codeView: some View {
        ScrollView {
            Text(artifact.content)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .frame(minHeight: 300)
    }
}

/// WebView for rendering artifacts
struct ArtifactWebView: NSViewRepresentable {
    let artifact: Artifact
    @Binding var isLoading: Bool
    @Binding var error: String?
    private let previewId = UUID()

    // Get the path to bundled JS libraries - checks multiple locations
    private static var bundledJSPath: URL? = {
        let fileManager = FileManager.default

        // Possible locations for JS files (in priority order)
        var possiblePaths: [URL] = []

        // 1. App bundle Resources/js (production - Vaizor.app/Contents/Resources/js)
        if let resourceURL = Bundle.main.resourceURL {
            possiblePaths.append(resourceURL.appendingPathComponent("js"))
        }

        // 2. Relative to executable (for swift run from .build)
        if let execURL = Bundle.main.executableURL {
            let execDir = execURL.deletingLastPathComponent()
            // Try various levels up from executable
            for level in 0...5 {
                var path = execDir
                for _ in 0..<level {
                    path = path.deletingLastPathComponent()
                }
                possiblePaths.append(path.appendingPathComponent("Resources/js"))
            }
        }

        // 3. Current working directory
        let cwd = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        possiblePaths.append(cwd.appendingPathComponent("Resources/js"))

        // Log what we're searching
        AppLogger.shared.log("Searching for JS libraries in \(possiblePaths.count) locations...", level: .debug)

        for possiblePath in possiblePaths {
            let testFile = possiblePath.appendingPathComponent("react.min.js")
            if fileManager.fileExists(atPath: testFile.path) {
                AppLogger.shared.log("Found JS libraries at: \(possiblePath.path)", level: .info)
                return possiblePath
            }
        }

        // Log detailed failure info
        AppLogger.shared.log("JS libraries NOT FOUND. Searched paths:", level: .error)
        for path in possiblePaths {
            let exists = fileManager.fileExists(atPath: path.path)
            AppLogger.shared.log("  \(exists ? "DIR EXISTS" : "missing"): \(path.path)", level: .error)
        }
        return nil
    }()

    // Check if bundled libraries exist
    private static var hasBundledLibraries: Bool {
        return bundledJSPath != nil
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        // Allow media playback without user gesture (for interactive components)
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Enable developer tools for debugging
        #if DEBUG
        webView.isInspectable = true
        #endif

        // Load the artifact
        let html = generateHTML(for: artifact)
        loadHTML(webView: webView, html: html)

        return webView
    }

    private func loadHTML(webView: WKWebView, html: String) {
        // Log path discovery for debugging
        AppLogger.shared.log("ArtifactWebView loadHTML called", level: .info)
        AppLogger.shared.log("hasBundledLibraries: \(Self.hasBundledLibraries)", level: .info)
        AppLogger.shared.log("bundledJSPath: \(Self.bundledJSPath?.path ?? "nil")", level: .info)

        // SECURITY: Only use bundled libraries - no external network calls
        guard Self.hasBundledLibraries, let bundledJS = Self.bundledJSPath else {
            // Show error if bundled libraries not found
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

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("vaizor_preview_\(previewId.uuidString)")

        do {
            // Create temp directory
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Copy bundled JS files (local only - no network)
            let jsDir = tempDir.appendingPathComponent("js")
            try FileManager.default.createDirectory(at: jsDir, withIntermediateDirectories: true)

            let jsFiles = [
                // Core React stack
                "react.min.js", "react-dom.min.js", "babel.min.js",
                // PropTypes (required by Recharts)
                "prop-types.min.js",
                // Styling & Icons
                "tailwind.js", "lucide.min.js",
                // Charts & Data Viz
                "recharts.min.js", "d3.min.js",
                // Canvas & Graphics
                "fabric.min.js", "rough.min.js",
                // 3D
                "three.min.js",
                // Animation
                "anime.min.js",
                // Diagrams
                "mermaid.min.js",
                // Export & Utils
                "jspdf.min.js", "html2canvas.min.js", "dayjs.min.js"
            ]

            var copiedCount = 0
            var copyErrors: [String] = []
            for file in jsFiles {
                let src = bundledJS.appendingPathComponent(file)
                let dst = jsDir.appendingPathComponent(file)
                if FileManager.default.fileExists(atPath: src.path) {
                    do {
                        if FileManager.default.fileExists(atPath: dst.path) {
                            try FileManager.default.removeItem(at: dst)
                        }
                        try FileManager.default.copyItem(at: src, to: dst)
                        copiedCount += 1
                    } catch {
                        copyErrors.append("\(file): \(error.localizedDescription)")
                    }
                } else {
                    copyErrors.append("\(file): not found at \(src.path)")
                }
            }
            AppLogger.shared.log("Copied \(copiedCount)/\(jsFiles.count) JS files to temp dir: \(jsDir.path)", level: copyErrors.isEmpty ? .info : .warning)
            if !copyErrors.isEmpty {
                AppLogger.shared.log("Copy errors: \(copyErrors.joined(separator: ", "))", level: .error)
            }

            // Verify files exist
            let verifyFiles = ["react.min.js", "react-dom.min.js", "babel.min.js"]
            for file in verifyFiles {
                let filePath = jsDir.appendingPathComponent(file)
                let exists = FileManager.default.fileExists(atPath: filePath.path)
                AppLogger.shared.log("Verify \(file): \(exists ? "EXISTS" : "MISSING") at \(filePath.path)", level: exists ? .debug : .error)
            }

            // Replace relative js/ paths with absolute file:// URLs to the temp js directory
            let jsURL = jsDir.absoluteString
            var processedHTML = html
            processedHTML = processedHTML.replacingOccurrences(
                of: "src=\"js/",
                with: "src=\"\(jsURL)/"
            )

            // Write HTML file
            let htmlFile = tempDir.appendingPathComponent("index.html")
            try processedHTML.write(to: htmlFile, atomically: true, encoding: .utf8)
            AppLogger.shared.log("HTML written to: \(htmlFile.path)", level: .info)
            AppLogger.shared.log("JS URL base: \(jsURL)", level: .info)

            // Load from file with access to the temp directory only (no network)
            AppLogger.shared.log("Loading with access to: \(tempDir.path)", level: .info)
            webView.loadFileURL(htmlFile, allowingReadAccessTo: tempDir)
        } catch {
            AppLogger.shared.log("Failed to setup artifact preview: \(error)", level: .error)
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head><meta charset="utf-8"></head>
            <body style="font-family: -apple-system, sans-serif; padding: 20px; background: #1c1c1e; color: #ff6b6b;">
                <h3>Preview Error</h3>
                <p>\(error.localizedDescription)</p>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
        }
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Reload if content changes
        if context.coordinator.lastContent != artifact.content {
            context.coordinator.lastContent = artifact.content
            let html = generateHTML(for: artifact)
            loadHTML(webView: webView, html: html)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, error: $error, content: artifact.content)
    }

    /// Check if we're online and can use CDN resources
    private var isOnline: Bool {
        // Simple check - could be enhanced with NetworkMonitor
        var flags = SCNetworkReachabilityFlags()
        if let reachability = SCNetworkReachabilityCreateWithName(nil, "cdn.jsdelivr.net") {
            SCNetworkReachabilityGetFlags(reachability, &flags)
            return flags.contains(.reachable) && !flags.contains(.connectionRequired)
        }
        return false
    }

    /// Generate CDN script tags for extended libraries (only when online)
    private var cdnScripts: String {
        guard isOnline else { return "" }
        return """
        <!-- Extended libraries (CDN - online only) -->
        <script src="https://esm.sh/@radix-ui/react-slot@1.1.0" type="module"></script>
        <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/gsap@3.12.4/dist/gsap.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/lottie-web@5.12.2/build/player/lottie.min.js"></script>
        """
    }

    private func generateHTML(for artifact: Artifact) -> String {
        switch artifact.type {
        case .react:
            return generateReactHTML(artifact.content)
        case .html:
            return wrapHTML(artifact.content)
        case .svg:
            return wrapSVG(artifact.content)
        case .mermaid:
            return generateMermaidHTML(artifact.content)
        case .chart:
            return generateReactHTML(artifact.content) // Charts use React (Recharts)
        case .canvas:
            return generateCanvasHTML(artifact.content)
        case .three:
            return generateThreeHTML(artifact.content)
        case .presentation:
            return generatePresentationHTML(artifact.content)
        case .animation:
            return generateAnimationHTML(artifact.content)
        case .sketch:
            return generateSketchHTML(artifact.content)
        case .d3:
            return generateD3HTML(artifact.content)
        }
    }

    /// Sanitize LLM-generated code by removing non-code content
    private func sanitizeLLMCode(_ code: String) -> String {
        var result = code

        // Extract code from markdown fences if present
        if let fenceRegex = try? NSRegularExpression(pattern: #"```(?:jsx?|tsx?|javascript|typescript|react)?\s*([\s\S]*?)```"#, options: []),
           let match = fenceRegex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           let range = Range(match.range(at: 1), in: result) {
            result = String(result[range])
            AppLogger.shared.log("Extracted code from markdown fence", level: .debug)
        }

        // Helper to apply multiline regex replacement
        func replaceMultiline(_ text: String, pattern: String, with replacement: String) -> String {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive]) else {
                return text
            }
            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: replacement
            )
        }

        // Remove markdown headers (# Header)
        result = replaceMultiline(result, pattern: #"^#+\s+.*$"#, with: "")

        // Remove numbered instructions (1. Do this, 2. Do that)
        result = replaceMultiline(result, pattern: #"^\s*\d+\.\s+[A-Z][^{;]*$"#, with: "")

        // Remove shell commands
        result = replaceMultiline(result, pattern: #"^\s*(npm|npx|yarn|pnpm|cd|mkdir|git)\s+.*$"#, with: "")

        // Remove common prose starters that aren't code
        let prosePatterns = [
            #"^\s*First,?\s+[^{;]*$"#,
            #"^\s*Then,?\s+[^{;]*$"#,
            #"^\s*Next,?\s+[^{;]*$"#,
            #"^\s*Now,?\s+[^{;]*$"#,
            #"^\s*Here'?s?\s+[^{;]*$"#,
            #"^\s*This\s+(will|is|creates?|shows?)[^{;]*$"#,
            #"^\s*Create\s+a\s+[^{;]*$"#,
            #"^\s*Let'?s\s+[^{;]*$"#,
            #"^\s*Step\s+\d+[^{;]*$"#,
        ]

        for pattern in prosePatterns {
            result = replaceMultiline(result, pattern: pattern, with: "")
        }

        // Clean up excessive blank lines
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )

        // Trim
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // If we removed a lot, log it
        if result.count < code.count * 3 / 4 {
            AppLogger.shared.log("Sanitized code: \(code.count) -> \(result.count) chars", level: .info)
        }

        return result
    }

    private func generateReactHTML(_ code: String) -> String {
        // Pre-process: Sanitize LLM output
        var processedCode = sanitizeLLMCode(code)

        // If LLM generated a full HTML document, extract just the script content
        if processedCode.contains("<!DOCTYPE") || processedCode.contains("<html") {
            // Try to extract content from <script type="text/babel"> or similar
            let scriptPatterns = [
                #"<script[^>]*type\s*=\s*[\"']text/babel[\"'][^>]*>([\s\S]*?)</script>"#,
                #"<script[^>]*type\s*=\s*[\"']text/jsx[\"'][^>]*>([\s\S]*?)</script>"#,
                #"<script[^>]*>([\s\S]*?function\s+\w+[\s\S]*?)</script>"#
            ]

            for pattern in scriptPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: processedCode, range: NSRange(processedCode.startIndex..., in: processedCode)),
                   let range = Range(match.range(at: 1), in: processedCode) {
                    let extracted = String(processedCode[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !extracted.isEmpty && extracted.contains("function") {
                        processedCode = extracted
                        AppLogger.shared.log("Extracted component code from HTML document (\(extracted.count) chars)", level: .info)
                        break
                    }
                }
            }

            // If we couldn't extract, try to find the component function directly
            if processedCode.contains("<!DOCTYPE") || processedCode.contains("<html") {
                // Look for function Component pattern
                if let regex = try? NSRegularExpression(pattern: #"(function\s+\w+\s*\([^)]*\)\s*\{[\s\S]+\})\s*(?:ReactDOM|$)"#, options: []),
                   let match = regex.firstMatch(in: processedCode, range: NSRange(processedCode.startIndex..., in: processedCode)),
                   let range = Range(match.range(at: 1), in: processedCode) {
                    processedCode = String(processedCode[range])
                    AppLogger.shared.log("Extracted function from HTML document", level: .info)
                }
            }
        }

        // Remove CDN script tags that LLM might have included
        processedCode = processedCode.replacingOccurrences(
            of: #"<script[^>]*src\s*=\s*[\"'][^\"']*(?:cdn|unpkg|jsdelivr|cloudflare)[^\"']*[\"'][^>]*>\s*</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

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

        // Remove CSS/style imports (no 'from' keyword): import './file.css';
        processedCode = processedCode.replacingOccurrences(
            of: #"import\s+['\"][^'\"]+\.(css|scss|sass|less|style)['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )

        // Remove any remaining generic imports with 'from' that might break
        processedCode = processedCode.replacingOccurrences(
            of: #"import\s+.*from\s+['\"][^'\"]+['\"];?\s*"#,
            with: "",
            options: .regularExpression
        )

        // TypeScript is now handled by Babel with the 'typescript' preset
        // No manual stripping needed - Babel transforms TS to JS

        // Remove export statements
        processedCode = processedCode.replacingOccurrences(
            of: #"export\s+default\s+"#,
            with: "",
            options: .regularExpression
        )
        processedCode = processedCode.replacingOccurrences(
            of: #"export\s+\{"#,
            with: "// export {",
            options: .regularExpression
        )

        // Escape the code for safe embedding in JS template literal
        let escapedCode = processedCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        // All scripts loaded from bundled local files only (no network)
        // Use regular script tags for reliable loading with WKWebView file access
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <!-- Core Libraries - loaded via script tags for reliable file:// access -->
            <script src="js/react.min.js"></script>
            <script src="js/react-dom.min.js"></script>
            <script src="js/prop-types.min.js"></script>
            <script src="js/babel.min.js"></script>
            <!-- Styling -->
            <script src="js/tailwind.js"></script>
            <script>\(ArtifactTheme.tailwindConfig)</script>
            <script src="js/lucide.min.js"></script>
            <!-- Charts -->
            <script src="js/recharts.min.js"></script>
            <script src="js/d3.min.js"></script>
            <script src="js/dayjs.min.js"></script>
            \(cdnScripts)
            <!-- Vaizor Design System -->
            <style>\(ArtifactTheme.css)</style>
            <!-- shadcn/ui Component Styles -->
            <style>\(ShadcnComponents.componentCSS)</style>
        </head>
        <body>
            <div id="root">
                <div class="loading">
                    <div class="loading-spinner"></div>
                    <div>Loading...</div>
                </div>
            </div>

            <script>
                console.log('[Vaizor] Checking libraries...');
                console.log('[Vaizor] Document URL:', window.location.href);

                // Check if libraries loaded
                var reactLoaded = typeof React !== 'undefined';
                var reactDomLoaded = typeof ReactDOM !== 'undefined';
                var babelLoaded = typeof Babel !== 'undefined';

                console.log('[Vaizor] React:', reactLoaded, 'ReactDOM:', reactDomLoaded, 'Babel:', babelLoaded);

                if (!reactLoaded || !reactDomLoaded || !babelLoaded) {
                    document.getElementById('root').innerHTML = '<div class="error" style="padding: 20px; font-family: -apple-system, sans-serif;">' +
                        '<h3 style="color: #ff6b6b; margin-bottom: 12px;">Failed to load libraries</h3>' +
                        '<p><strong>React:</strong> ' + (reactLoaded ? 'OK' : 'MISSING') + '</p>' +
                        '<p><strong>ReactDOM:</strong> ' + (reactDomLoaded ? 'OK' : 'MISSING') + '</p>' +
                        '<p><strong>Babel:</strong> ' + (babelLoaded ? 'OK' : 'MISSING') + '</p>' +
                        '<p style="margin-top: 12px; color: #888; font-size: 12px;">Document: ' + window.location.href + '</p>' +
                        '</div>';
                } else {
                    // All libraries loaded - setup globals and run
                    console.log('[Vaizor] All libraries loaded successfully!');

                    // Make React hooks available as globals
                    window.useState = React.useState;
                    window.useEffect = React.useEffect;
                    window.useRef = React.useRef;
                    window.useMemo = React.useMemo;
                    window.useCallback = React.useCallback;
                    window.useContext = React.useContext;
                    window.useReducer = React.useReducer;
                    window.useLayoutEffect = React.useLayoutEffect;

                    // Initialize Lucide icons if available
                    if (typeof lucide !== 'undefined') {
                        window.LucideIcons = lucide;
                    }

                    // Make Recharts components available globally
                    if (typeof Recharts !== 'undefined') {
                        window.LineChart = Recharts.LineChart;
                        window.BarChart = Recharts.BarChart;
                        window.PieChart = Recharts.PieChart;
                        window.AreaChart = Recharts.AreaChart;
                        window.RadarChart = Recharts.RadarChart;
                        window.ComposedChart = Recharts.ComposedChart;
                        window.ScatterChart = Recharts.ScatterChart;
                        window.Treemap = Recharts.Treemap;
                        window.XAxis = Recharts.XAxis;
                        window.YAxis = Recharts.YAxis;
                        window.ZAxis = Recharts.ZAxis;
                        window.CartesianGrid = Recharts.CartesianGrid;
                        window.Tooltip = Recharts.Tooltip;
                        window.Legend = Recharts.Legend;
                        window.Line = Recharts.Line;
                        window.Bar = Recharts.Bar;
                        window.Pie = Recharts.Pie;
                        window.Area = Recharts.Area;
                        window.Cell = Recharts.Cell;
                        window.Scatter = Recharts.Scatter;
                        window.Radar = Recharts.Radar;
                        window.RadialBar = Recharts.RadialBar;
                        window.RadialBarChart = Recharts.RadialBarChart;
                        window.PolarGrid = Recharts.PolarGrid;
                        window.PolarAngleAxis = Recharts.PolarAngleAxis;
                        window.PolarRadiusAxis = Recharts.PolarRadiusAxis;
                        window.ResponsiveContainer = Recharts.ResponsiveContainer;
                        window.ReferenceLine = Recharts.ReferenceLine;
                        window.ReferenceArea = Recharts.ReferenceArea;
                        window.Brush = Recharts.Brush;
                        console.log('[Vaizor] Recharts components exposed globally');
                    }

                    // Load shadcn/ui-style components
                    \(ShadcnComponents.componentDefinitions)

                    // Run the React code
                    runReactCode();
                }

                function runReactCode() {
                    var debugLog = [];
                    function debug(msg) {
                        debugLog.push(msg);
                        console.log('[React Debug]', msg);
                    }

                    try {
                        debug('Starting runReactCode');
                        debug('React available: ' + (typeof React !== 'undefined'));
                        debug('ReactDOM available: ' + (typeof ReactDOM !== 'undefined'));
                        debug('Babel available: ' + (typeof Babel !== 'undefined'));

                        // Make React hooks available as globals
                        window.useState = React.useState;
                        window.useEffect = React.useEffect;
                        window.useRef = React.useRef;
                        window.useMemo = React.useMemo;
                        window.useCallback = React.useCallback;
                        window.useContext = React.useContext;
                        window.useReducer = React.useReducer;
                        window.useLayoutEffect = React.useLayoutEffect;
                        debug('Hooks assigned to window');

                        // User's React code
                        var userCode = `\(escapedCode)`;
                        debug('User code length: ' + userCode.length);

                        // Sanitize code - strip markdown, instructions, and non-code content
                        function sanitizeCode(code) {
                            var original = code;

                            // Extract code from markdown code fences if present
                            var fenceMatch = code.match(/```(?:jsx?|tsx?|javascript|typescript)?\\s*([\\s\\S]*?)```/);
                            if (fenceMatch) {
                                code = fenceMatch[1].trim();
                                debug('Extracted code from fence, length: ' + code.length);
                            }

                            // Remove markdown headers (# Header)
                            code = code.replace(/^#+\\s+.*$/gm, '');

                            // Remove numbered/bulleted lists that look like instructions
                            code = code.replace(/^\\s*\\d+\\.\\s+(?!\\{|\\[|return|const|let|var|function|class|if|for|while).*$/gm, '');
                            code = code.replace(/^\\s*[-*]\\s+(?!\\{|\\[|return|const|let|var|function|class).*$/gm, '');

                            // Remove lines that look like prose (start with common instruction words)
                            code = code.replace(/^\\s*(?:First|Then|Next|Now|Create|Run|Install|Step|Note|This|The|You|We|To|In|For|After|Before|Make|Add|Copy|Open|Save|Update|Click|Navigate|Start|Build|Use|Set|Get|Here|Below|Above)[^{;]*$/gim, '');

                            // Remove shell commands
                            code = code.replace(/^\\s*(?:npm|npx|yarn|pnpm|cd|mkdir|touch|git|curl|wget)\\s+.*$/gm, '');

                            // Remove empty lines at start
                            code = code.replace(/^\\s*\\n+/, '');

                            // Remove excessive blank lines
                            code = code.replace(/\\n{3,}/g, '\\n\\n');

                            if (code !== original) {
                                debug('Code sanitized, new length: ' + code.length);
                            }

                            return code.trim();
                        }

                        userCode = sanitizeCode(userCode);

                        // Transform with Babel (with retry on failure)
                        debug('Transforming with Babel...');
                        var transformed;
                        var retryCount = 0;
                        var maxRetries = 2;
                        var lastError = null;

                        while (retryCount <= maxRetries) {
                            try {
                                transformed = Babel.transform(userCode, {
                                    presets: ['react', 'typescript'],
                                    filename: 'component.tsx'
                                }).code;
                                debug('Babel transform successful, output length: ' + transformed.length);
                                break;
                            } catch (babelErr) {
                                lastError = babelErr;
                                debug('Babel error (attempt ' + (retryCount + 1) + '): ' + babelErr.message);

                                if (retryCount < maxRetries) {
                                    // Try more aggressive sanitization
                                    debug('Attempting recovery...');

                                    // Try to extract just the function/component
                                    var funcMatch = userCode.match(/((?:function|const|let|var)\\s+[A-Z][a-zA-Z0-9]*[\\s\\S]*)/);
                                    if (funcMatch) {
                                        userCode = funcMatch[1];
                                        debug('Extracted component definition, length: ' + userCode.length);
                                    } else {
                                        // Remove first few lines which often contain instructions
                                        var lines = userCode.split('\\n');
                                        var startIdx = 0;
                                        for (var i = 0; i < Math.min(5, lines.length); i++) {
                                            if (lines[i].match(/^\\s*(function|const|let|var|class|import|export|\\/\\/|\\/\\*|<)/)) {
                                                startIdx = i;
                                                break;
                                            }
                                            startIdx = i + 1;
                                        }
                                        userCode = lines.slice(startIdx).join('\\n');
                                        debug('Removed first ' + startIdx + ' lines');
                                    }
                                }
                                retryCount++;
                            }
                        }

                        if (!transformed) {
                            throw lastError || new Error('Failed to transform code');
                        }

                        // Create a module-like scope that exposes top-level declarations
                        // We'll parse the transformed code to find PascalCase variable assignments
                        var componentNames = [];
                        var pascalCasePattern = /(?:var|let|const) +([A-Z][a-zA-Z0-9]*) *=/g;
                        var funcPattern = /function +([A-Z][a-zA-Z0-9]*) *[(]/g;
                        var m;
                        while ((m = pascalCasePattern.exec(transformed)) !== null) {
                            componentNames.push(m[1]);
                        }
                        while ((m = funcPattern.exec(transformed)) !== null) {
                            componentNames.push(m[1]);
                        }
                        debug('Found component names: ' + JSON.stringify(componentNames));

                        // Execute the code, then try to extract components
                        // Use Function constructor to get access to local scope
                        var moduleCode = transformed + ';';
                        componentNames.forEach(function(name) {
                            moduleCode += 'if (typeof ' + name + ' !== "undefined") { window.__COMPONENTS__ = window.__COMPONENTS__ || {}; window.__COMPONENTS__["' + name + '"] = ' + name + '; }';
                        });

                        // Execute
                        debug('Executing module code...');
                        try {
                            new Function(moduleCode)();
                            debug('Module code executed successfully');
                        } catch (execErr) {
                            debug('Execution error: ' + execErr.message);
                            throw execErr;
                        }

                        // Find component to render
                        debug('Looking for components...');
                        debug('window.__COMPONENTS__: ' + JSON.stringify(window.__COMPONENTS__ ? Object.keys(window.__COMPONENTS__) : null));

                        var root = ReactDOM.createRoot(document.getElementById('root'));
                        var ComponentToRender = null;
                        var foundVia = '';

                        // Check our extracted components first
                        if (window.__COMPONENTS__) {
                            var extracted = Object.keys(window.__COMPONENTS__);
                            debug('Extracted components: ' + JSON.stringify(extracted));
                            for (var i = 0; i < extracted.length; i++) {
                                var comp = window.__COMPONENTS__[extracted[i]];
                                debug('Checking ' + extracted[i] + ': typeof=' + typeof comp);
                                if (typeof comp === 'function') {
                                    ComponentToRender = comp;
                                    foundVia = 'extracted: ' + extracted[i];
                                    break;
                                }
                            }
                        }

                        // Fallback: check common names on window
                        if (!ComponentToRender) {
                            var common = ['App', 'Component', 'Main', 'Root', 'Demo', 'Example', 'Preview', 'Counter', 'Dashboard', 'Widget', 'Card'];
                            for (var j = 0; j < common.length; j++) {
                                if (typeof window[common[j]] === 'function') {
                                    ComponentToRender = window[common[j]];
                                    foundVia = 'common: ' + common[j];
                                    break;
                                }
                            }
                        }

                        // Last resort: find any React-like function on window
                        if (!ComponentToRender) {
                            var builtins = ['React', 'ReactDOM', 'Babel', 'Function', 'Object', 'Array', 'String', 'Number', 'Boolean', 'Promise', 'Symbol', 'Error', 'Map', 'Set', 'WeakMap', 'WeakSet', 'JSON', 'Math', 'Date', 'RegExp', 'Proxy', 'Reflect', 'Intl', 'WebAssembly'];
                            var keys = Object.keys(window);
                            for (var k = keys.length - 1; k >= 0; k--) {
                                var key = keys[k];
                                if (/^[A-Z][a-zA-Z0-9]*$/.test(key) && typeof window[key] === 'function' && builtins.indexOf(key) === -1) {
                                    ComponentToRender = window[key];
                                    foundVia = 'window scan: ' + key;
                                    break;
                                }
                            }
                        }

                        debug('ComponentToRender found: ' + (ComponentToRender ? 'yes' : 'no') + ', via: ' + foundVia);

                        if (ComponentToRender) {
                            debug('Rendering component...');
                            try {
                                root.render(React.createElement(ComponentToRender));
                                debug('Render called successfully');
                            } catch (renderErr) {
                                debug('Render error: ' + renderErr.message);
                                throw renderErr;
                            }
                        } else {
                            debug('No component found!');
                            document.getElementById('root').innerHTML = '<div class="info">No React component found.<br><br>Debug log:<br><pre style="text-align:left;font-size:11px;background:#f0f0f0;padding:10px;border-radius:4px;overflow:auto;">' + debugLog.join('\\n') + '</pre></div>';
                        }
                    } catch (err) {
                        document.getElementById('root').innerHTML = '<div class="error">' + (err.message || err) + '<br><br>Debug log:<br><pre style="text-align:left;font-size:11px;background:#fff0f0;padding:10px;border-radius:4px;overflow:auto;max-height:200px;">' + debugLog.join('\\n') + '</pre></div>';
                    }
                }
            </script>
        </body>
        </html>
        """
    }

    private func wrapHTML(_ content: String) -> String {
        if content.lowercased().contains("<html") || content.lowercased().contains("<!doctype") {
            return content
        }

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
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 0;
                    padding: 16px;
                    line-height: 1.5;
                }
            </style>
        </head>
        <body class="bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100">
        \(content)
        <script>
            // Initialize Lucide icons
            if (typeof lucide !== 'undefined') {
                lucide.createIcons();
            }
        </script>
        </body>
        </html>
        """
    }

    private func wrapSVG(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    margin: 0;
                    padding: 16px;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: calc(100vh - 32px);
                    background: white;
                }
                @media (prefers-color-scheme: dark) {
                    body { background: #1c1c1e; }
                }
                svg { max-width: 100%; height: auto; }
            </style>
        </head>
        <body>
        \(content)
        </body>
        </html>
        """
    }

    private func generateMermaidHTML(_ content: String) -> String {
        let jsPath = "js"
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="\(jsPath)/mermaid.min.js"></script>
            <style>
                body {
                    margin: 0;
                    padding: 16px;
                    display: flex;
                    justify-content: center;
                    background: white;
                }
                @media (prefers-color-scheme: dark) {
                    body { background: #1c1c1e; }
                }
                .mermaid { max-width: 100%; }
            </style>
        </head>
        <body>
            <pre class="mermaid">
            \(content)
            </pre>
            <script>
                mermaid.initialize({
                    startOnLoad: true,
                    theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'default'
                });
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Canvas (Fabric.js)
    private func generateCanvasHTML(_ code: String) -> String {
        let jsPath = "js"
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="\(jsPath)/fabric.min.js"></script>
            <script src="\(jsPath)/tailwind.js"></script>
            <style>
                body { margin: 0; padding: 16px; background: white; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
                @media (prefers-color-scheme: dark) { body { background: #1c1c1e; } }
                canvas { border: 1px solid #e5e7eb; border-radius: 8px; }
                @media (prefers-color-scheme: dark) { canvas { border-color: #374151; } }
            </style>
        </head>
        <body>
            <canvas id="canvas" width="800" height="600"></canvas>
            <script>
                var canvas = new fabric.Canvas('canvas', {
                    backgroundColor: window.matchMedia('(prefers-color-scheme: dark)').matches ? '#1f2937' : '#ffffff'
                });
                try {
                    \(escapedCode)
                } catch(e) {
                    console.error('Canvas error:', e);
                    document.body.innerHTML = '<div style="color:red;padding:20px;">Error: ' + e.message + '</div>';
                }
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Three.js (3D)
    private func generateThreeHTML(_ code: String) -> String {
        let jsPath = "js"
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="\(jsPath)/three.min.js"></script>
            <style>
                body { margin: 0; overflow: hidden; background: #000; }
                canvas { display: block; }
            </style>
        </head>
        <body>
            <script>
                // Three.js globals
                var scene = new THREE.Scene();
                var camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
                var renderer = new THREE.WebGLRenderer({ antialias: true });
                renderer.setSize(window.innerWidth, window.innerHeight);
                renderer.setPixelRatio(window.devicePixelRatio);
                document.body.appendChild(renderer.domElement);
                
                // Handle resize
                window.addEventListener('resize', function() {
                    camera.aspect = window.innerWidth / window.innerHeight;
                    camera.updateProjectionMatrix();
                    renderer.setSize(window.innerWidth, window.innerHeight);
                });
                
                // User code
                try {
                    \(escapedCode)
                    
                    // Default animation loop if not defined
                    if (typeof animate !== 'function') {
                        function animate() {
                            requestAnimationFrame(animate);
                            renderer.render(scene, camera);
                        }
                        animate();
                    }
                } catch(e) {
                    console.error('Three.js error:', e);
                    document.body.innerHTML = '<div style="color:red;padding:20px;background:#111;">Error: ' + e.message + '</div>';
                }
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Presentation (Reveal.js-style)
    private func generatePresentationHTML(_ code: String) -> String {
        let jsPath = "js"
        
        // Parse slides from code (expected format: slides separated by ---)
        let slides = code.components(separatedBy: "---").map { slide in
            "<section>\(slide.trimmingCharacters(in: .whitespacesAndNewlines))</section>"
        }.joined(separator: "\n")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="\(jsPath)/tailwind.js"></script>
            <style>
                body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #1a1a2e; color: white; }
                .slides-container { width: 100vw; height: 100vh; overflow: hidden; position: relative; }
                .slide { width: 100%; height: 100%; display: none; padding: 60px; box-sizing: border-box; 
                         flex-direction: column; justify-content: center; align-items: center; text-align: center; }
                .slide.active { display: flex; }
                .slide h1 { font-size: 3em; margin-bottom: 0.5em; font-weight: 700; }
                .slide h2 { font-size: 2em; margin-bottom: 0.5em; font-weight: 600; }
                .slide p { font-size: 1.5em; opacity: 0.9; max-width: 800px; }
                .slide ul { font-size: 1.3em; text-align: left; }
                .slide li { margin: 0.5em 0; }
                .nav { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); display: flex; gap: 10px; }
                .nav button { padding: 10px 20px; border: none; background: rgba(255,255,255,0.2); color: white; 
                              border-radius: 5px; cursor: pointer; font-size: 14px; }
                .nav button:hover { background: rgba(255,255,255,0.3); }
                .progress { position: fixed; bottom: 0; left: 0; height: 4px; background: #4f46e5; transition: width 0.3s; }
                .slide-count { position: fixed; bottom: 20px; right: 20px; opacity: 0.5; font-size: 14px; }
            </style>
        </head>
        <body>
            <div class="slides-container" id="slides">
                \(slides)
            </div>
            <div class="nav">
                <button onclick="prevSlide()">← Previous</button>
                <button onclick="nextSlide()">Next →</button>
            </div>
            <div class="progress" id="progress"></div>
            <div class="slide-count" id="slideCount"></div>
            <script>
                var currentSlide = 0;
                var slides = document.querySelectorAll('.slide, section');
                slides.forEach(function(s) { s.classList.add('slide'); });
                
                function showSlide(n) {
                    slides.forEach(function(s) { s.classList.remove('active'); });
                    currentSlide = Math.max(0, Math.min(n, slides.length - 1));
                    slides[currentSlide].classList.add('active');
                    document.getElementById('progress').style.width = ((currentSlide + 1) / slides.length * 100) + '%';
                    document.getElementById('slideCount').textContent = (currentSlide + 1) + ' / ' + slides.length;
                }
                function nextSlide() { showSlide(currentSlide + 1); }
                function prevSlide() { showSlide(currentSlide - 1); }
                document.addEventListener('keydown', function(e) {
                    if (e.key === 'ArrowRight' || e.key === ' ') nextSlide();
                    if (e.key === 'ArrowLeft') prevSlide();
                });
                showSlide(0);
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Animation (Anime.js)
    private func generateAnimationHTML(_ code: String) -> String {
        let jsPath = "js"
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="\(jsPath)/anime.min.js"></script>
            <script src="\(jsPath)/tailwind.js"></script>
            <style>
                body { margin: 0; padding: 20px; min-height: 100vh; display: flex; justify-content: center; 
                       align-items: center; background: white; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
                @media (prefers-color-scheme: dark) { body { background: #1c1c1e; color: white; } }
                .animation-container { position: relative; width: 100%; max-width: 800px; min-height: 400px; }
            </style>
        </head>
        <body>
            <div class="animation-container" id="container"></div>
            <script>
                var container = document.getElementById('container');
                try {
                    \(escapedCode)
                } catch(e) {
                    console.error('Animation error:', e);
                    container.innerHTML = '<div style="color:red;">Error: ' + e.message + '</div>';
                }
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Sketch (Rough.js)
    private func generateSketchHTML(_ code: String) -> String {
        let jsPath = "js"
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="\(jsPath)/rough.min.js"></script>
            <style>
                body { margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center;
                       min-height: 100vh; background: #fffef5; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
                @media (prefers-color-scheme: dark) { body { background: #1c1c1e; } }
                svg { max-width: 100%; background: #fffef5; border-radius: 8px; }
                @media (prefers-color-scheme: dark) { svg { background: #2d2d30; } }
            </style>
        </head>
        <body>
            <svg id="canvas" width="800" height="600"></svg>
            <script>
                var svg = document.getElementById('canvas');
                var rc = rough.svg(svg);
                var isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                var strokeColor = isDark ? '#e5e5e5' : '#333333';
                try {
                    \(escapedCode)
                } catch(e) {
                    console.error('Sketch error:', e);
                    document.body.innerHTML = '<div style="color:red;padding:20px;">Error: ' + e.message + '</div>';
                }
            </script>
        </body>
        </html>
        """
    }

    // MARK: - D3.js Visualization
    private func generateD3HTML(_ code: String) -> String {
        let jsPath = "js"
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script src="\(jsPath)/d3.min.js"></script>
            <script src="\(jsPath)/tailwind.js"></script>
            <style>
                body { margin: 0; padding: 20px; background: white; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
                @media (prefers-color-scheme: dark) { body { background: #1c1c1e; color: white; } }
                svg { max-width: 100%; overflow: visible; }
                .axis path, .axis line { stroke: currentColor; }
                .axis text { fill: currentColor; }
            </style>
        </head>
        <body>
            <div id="chart"></div>
            <script>
                var container = d3.select('#chart');
                var width = Math.min(800, window.innerWidth - 40);
                var height = 500;
                var margin = { top: 20, right: 20, bottom: 40, left: 50 };
                var isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
                
                try {
                    \(escapedCode)
                } catch(e) {
                    console.error('D3 error:', e);
                    container.html('<div style="color:red;">Error: ' + e.message + '</div>');
                }
            </script>
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var error: String?
        var lastContent: String

        init(isLoading: Binding<Bool>, error: Binding<String?>, content: String) {
            _isLoading = isLoading
            _error = error
            self.lastContent = content
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = true
                self.error = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError err: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = err.localizedDescription
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError err: Error) {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = err.localizedDescription
            }
        }

        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
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

/// Inline artifact preview (collapsed by default)
struct InlineArtifactView: View {
    let artifact: Artifact
    @State private var isExpanded = false
    @State private var showFullPreview = false
    @Namespace private var namespace

    var body: some View {
        if #available(macOS 26.0, *) {
            modernGlassView
        } else {
            fallbackView
        }
    }
    
    @available(macOS 26.0, *)
    private var modernGlassView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Icon with glass background
                    Image(systemName: artifact.type.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular.tint(.accentColor), in: .rect(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artifact.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("Click to \(isExpanded ? "collapse" : "preview")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Buttons with glass container for merging effects
                    GlassEffectContainer(spacing: 8.0) {
                        HStack(spacing: 8) {
                            // Expand button
                            Button {
                                showFullPreview = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.borderless)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
                            .glassEffectID("expand", in: namespace)

                            // Chevron
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .frame(width: 24, height: 24)
                                .glassEffect(.regular, in: .rect(cornerRadius: 6))
                                .glassEffectID("chevron", in: namespace)
                        }
                    }
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular, in: .rect(cornerRadius: 10))

            // Expanded preview
            if isExpanded {
                ArtifactWebView(
                    artifact: artifact,
                    isLoading: .constant(false),
                    error: .constant(nil)
                )
                .frame(height: 300)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showFullPreview) {
            ArtifactView(artifact: artifact) {
                showFullPreview = false
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }
    
    private var fallbackView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Icon with background
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 28, height: 28)

                        Image(systemName: artifact.type.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(artifact.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("Click to \(isExpanded ? "collapse" : "preview")")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Buttons
                    HStack(spacing: 8) {
                        // Expand button
                        Button {
                            showFullPreview = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(6)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.borderless)

                        // Chevron
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(12)
            }
            .buttonStyle(.plain)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Expanded preview
            if isExpanded {
                ArtifactWebView(
                    artifact: artifact,
                    isLoading: .constant(false),
                    error: .constant(nil)
                )
                .frame(height: 300)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showFullPreview) {
            ArtifactView(artifact: artifact) {
                showFullPreview = false
            }
            .frame(minWidth: 600, minHeight: 500)
        }
    }
}
