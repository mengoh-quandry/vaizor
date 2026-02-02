import Foundation
import WebKit
import AppKit

// MARK: - Browser Models

/// Represents extracted content from a web page
struct PageContent: Codable, Sendable {
    var title: String
    var url: URL
    var text: String
    var html: String
    var links: [Link]
    var images: [ImageInfo]
    var forms: [FormInfo]
    var metadata: PageMetadata

    struct PageMetadata: Codable, Sendable {
        var description: String?
        var keywords: [String] = []
        var author: String?
        var publishedDate: String?
        var language: String?
    }
}

/// Represents a link on a web page
struct Link: Codable, Identifiable, Sendable {
    var id: String { href }
    var href: String
    var text: String
    var isExternal: Bool
    var rel: String?
}

/// Represents an image on a web page
struct ImageInfo: Codable, Identifiable, Sendable {
    var id: String { src }
    var src: String
    var alt: String?
    var width: Int?
    var height: Int?
}

/// Represents a form on a web page
struct FormInfo: Codable, Identifiable, Sendable {
    let id: String
    var action: String?
    var method: String
    var fields: [FormField]

    struct FormField: Codable, Sendable {
        var name: String
        var type: String
        var placeholder: String?
        var required: Bool
    }
}

/// Represents a web element for automation
struct WebElement: Codable, Identifiable, Sendable {
    let id: String
    var selector: String
    var tagName: String
    var text: String?
    var attributes: [String: String]
    var rect: CGRect
    var isClickable: Bool
    var isVisible: Bool
}

/// Browser tab information
struct BrowserTab: Identifiable {
    let id: UUID
    var url: URL?
    var title: String
    var favicon: NSImage?
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var webView: WKWebView?
}

/// Scroll position for automation
enum ScrollPosition: Sendable {
    case top
    case bottom
    case element(selector: String)
    case coordinates(x: CGFloat, y: CGFloat)
}

/// Browser action confirmation request
struct BrowserActionConfirmation: Identifiable {
    let id = UUID()
    let action: BrowserAction
    let description: String
    var isApproved: Bool = false

    enum BrowserAction: String, Sendable {
        case navigate
        case click
        case type
        case submit
        case download
        case screenshot
    }
}

// MARK: - Security

/// Known malicious domains blocklist
struct BrowserSecurityService {
    private static let blockedDomains: Set<String> = [
        "malware.com", "phishing.example.com",
        // Add known malicious domains here
    ]

    private static let blockedPatterns: [String] = [
        #"data:text/html"#,
        #"javascript:"#,
        #"vbscript:"#,
    ]

    /// Check if a URL is safe to navigate to
    static func isURLSafe(_ url: URL) -> (safe: Bool, reason: String?) {
        // Check scheme
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return (false, "Only HTTP/HTTPS URLs are allowed")
        }

        // Check blocked domains
        if let host = url.host?.lowercased() {
            for blocked in blockedDomains {
                if host == blocked || host.hasSuffix(".\(blocked)") {
                    return (false, "Domain is blocked for security reasons")
                }
            }
        }

        // Check URL string for dangerous patterns
        let urlString = url.absoluteString.lowercased()
        for pattern in blockedPatterns {
            if urlString.range(of: pattern, options: .regularExpression) != nil {
                return (false, "URL contains potentially dangerous content")
            }
        }

        return (true, nil)
    }

    /// Check if content appears to be a login/credential form
    static func detectCredentialForm(in html: String) -> Bool {
        let credentialPatterns = [
            #"type\s*=\s*['""]?password['""]?"#,
            #"name\s*=\s*['""]?(password|passwd|pwd|pin)['""]?"#,
            #"autocomplete\s*=\s*['""]?(current-password|new-password)['""]?"#,
            #"<input[^>]*credit[^>]*card"#,
            #"<input[^>]*ssn"#,
            #"<input[^>]*social[^>]*security"#,
        ]

        let lowercased = html.lowercased()
        return credentialPatterns.contains { pattern in
            lowercased.range(of: pattern, options: .regularExpression) != nil
        }
    }
}

// MARK: - Browser Service

/// Service for AI-assisted web browsing with automation capabilities
@MainActor
class BrowserService: NSObject, ObservableObject {
    static let shared = BrowserService()

    // MARK: - Published Properties

    @Published var currentURL: URL?
    @Published var pageContent: PageContent?
    @Published var isLoading: Bool = false
    @Published var loadProgress: Double = 0
    @Published var error: String?

    @Published var tabs: [BrowserTab] = []
    @Published var activeTabIndex: Int = 0

    @Published var pendingConfirmation: BrowserActionConfirmation?
    @Published var securityWarning: String?

    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    // MARK: - Private Properties

    private var webViewStore: [UUID: WKWebView] = [:]
    private let userAgent = "Vaizor/1.0 (macOS; AI Browser)"
    private var navigationDelegates: [UUID: BrowserNavigationDelegate] = [:]

    // Rate limiting
    private var actionTimestamps: [Date] = []
    private let maxActionsPerMinute = 30

    // Session management
    private var sessionDataStore: WKWebsiteDataStore?
    private var isolatedSession: Bool = false

    // MARK: - Initialization

    override private init() {
        super.init()
        setupDefaultSession()
        createNewTab()
    }

    private func setupDefaultSession() {
        // Use default persistent data store for cookies/sessions
        sessionDataStore = WKWebsiteDataStore.default()
    }

    // MARK: - Tab Management

    /// Create a new browser tab
    func createNewTab(url: URL? = nil) {
        let tabId = UUID()
        let webView = createWebView()

        let tab = BrowserTab(
            id: tabId,
            url: url,
            title: "New Tab",
            favicon: nil,
            isLoading: false,
            canGoBack: false,
            canGoForward: false,
            webView: webView
        )

        tabs.append(tab)
        webViewStore[tabId] = webView
        activeTabIndex = tabs.count - 1

        // Setup navigation delegate
        let delegate = BrowserNavigationDelegate(service: self, tabId: tabId)
        navigationDelegates[tabId] = delegate
        webView.navigationDelegate = delegate

        if let url = url {
            Task {
                await navigate(to: url)
            }
        }

        AppLogger.shared.log("Created new browser tab: \(tabId)", level: .info)
    }

    /// Close a tab
    func closeTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }

        let tab = tabs[index]
        webViewStore.removeValue(forKey: tab.id)
        navigationDelegates.removeValue(forKey: tab.id)
        tabs.remove(at: index)

        // Adjust active tab index
        if tabs.isEmpty {
            createNewTab()
        } else if activeTabIndex >= tabs.count {
            activeTabIndex = tabs.count - 1
        }

        AppLogger.shared.log("Closed browser tab: \(tab.id)", level: .info)
    }

    /// Switch to a specific tab
    func switchToTab(at index: Int) {
        guard index >= 0 && index < tabs.count else { return }
        activeTabIndex = index

        if let webView = currentWebView {
            updateNavigationState(from: webView)
        }
    }

    /// Get the current active WebView
    var currentWebView: WKWebView? {
        guard activeTabIndex >= 0 && activeTabIndex < tabs.count else { return nil }
        return webViewStore[tabs[activeTabIndex].id]
    }

    // MARK: - Navigation

    /// Navigate to a URL
    func navigate(to url: URL) async {
        // Security check
        let securityCheck = BrowserSecurityService.isURLSafe(url)
        guard securityCheck.safe else {
            error = securityCheck.reason
            securityWarning = securityCheck.reason
            AppLogger.shared.log("Blocked navigation to unsafe URL: \(url)", level: .warning)
            return
        }

        // Rate limiting
        guard checkRateLimit() else {
            error = "Too many actions. Please wait."
            return
        }

        guard let webView = currentWebView else {
            error = "No active browser tab"
            return
        }

        isLoading = true
        error = nil
        currentURL = url

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        webView.load(request)

        // Update tab info
        if activeTabIndex < tabs.count {
            tabs[activeTabIndex].url = url
            tabs[activeTabIndex].isLoading = true
        }

        AppLogger.shared.log("Navigating to: \(url)", level: .info)
    }

    /// Navigate to a URL string
    func navigate(to urlString: String) async {
        // Try to create URL, adding https:// if needed
        var cleanedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanedURL.hasPrefix("http://") && !cleanedURL.hasPrefix("https://") {
            cleanedURL = "https://\(cleanedURL)"
        }

        guard let url = URL(string: cleanedURL) else {
            error = "Invalid URL: \(urlString)"
            return
        }

        await navigate(to: url)
    }

    /// Go back in history
    func goBack() {
        guard let webView = currentWebView, webView.canGoBack else { return }
        guard checkRateLimit() else { return }
        webView.goBack()
        AppLogger.shared.log("Browser going back", level: .info)
    }

    /// Go forward in history
    func goForward() {
        guard let webView = currentWebView, webView.canGoForward else { return }
        guard checkRateLimit() else { return }
        webView.goForward()
        AppLogger.shared.log("Browser going forward", level: .info)
    }

    /// Refresh current page
    func refresh() {
        guard let webView = currentWebView else { return }
        guard checkRateLimit() else { return }
        webView.reload()
        AppLogger.shared.log("Browser refreshing", level: .info)
    }

    /// Stop loading
    func stopLoading() {
        guard let webView = currentWebView else { return }
        webView.stopLoading()
        isLoading = false
    }

    // MARK: - AI Integration

    /// Extract page content for AI analysis
    func extractPageContent() async -> PageContent? {
        guard let webView = currentWebView,
              let url = webView.url else { return nil }

        // JavaScript to extract page content
        let extractionScript = """
        (function() {
            // Extract text content
            function getTextContent() {
                const clone = document.body.cloneNode(true);
                clone.querySelectorAll('script, style, noscript').forEach(el => el.remove());
                return clone.innerText.trim();
            }

            // Extract links
            function getLinks() {
                return Array.from(document.querySelectorAll('a[href]')).map(a => ({
                    href: a.href,
                    text: a.innerText.trim(),
                    isExternal: a.host !== window.location.host,
                    rel: a.rel || null
                })).filter(l => l.href && l.href.startsWith('http'));
            }

            // Extract images
            function getImages() {
                return Array.from(document.querySelectorAll('img[src]')).map(img => ({
                    src: img.src,
                    alt: img.alt || null,
                    width: img.naturalWidth || null,
                    height: img.naturalHeight || null
                })).filter(i => i.src);
            }

            // Extract forms
            function getForms() {
                return Array.from(document.querySelectorAll('form')).map((form, idx) => ({
                    id: form.id || 'form-' + idx,
                    action: form.action || null,
                    method: form.method || 'GET',
                    fields: Array.from(form.querySelectorAll('input, textarea, select')).map(f => ({
                        name: f.name || '',
                        type: f.type || 'text',
                        placeholder: f.placeholder || null,
                        required: f.required || false
                    })).filter(f => f.name)
                }));
            }

            // Extract metadata
            function getMetadata() {
                const getMeta = (name) => {
                    const el = document.querySelector(`meta[name="${name}"], meta[property="${name}"]`);
                    return el ? el.content : null;
                };
                return {
                    description: getMeta('description') || getMeta('og:description'),
                    keywords: (getMeta('keywords') || '').split(',').map(k => k.trim()).filter(k => k),
                    author: getMeta('author'),
                    publishedDate: getMeta('article:published_time'),
                    language: document.documentElement.lang || null
                };
            }

            return {
                title: document.title,
                text: getTextContent(),
                html: document.documentElement.outerHTML,
                links: getLinks().slice(0, 100),
                images: getImages().slice(0, 50),
                forms: getForms().slice(0, 10),
                metadata: getMetadata()
            };
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(extractionScript)

            guard let dict = result as? [String: Any] else {
                AppLogger.shared.log("Failed to extract page content: invalid result type", level: .error)
                return nil
            }

            // Parse the result
            let content = parsePageContent(dict, url: url)
            self.pageContent = content

            // Security check for credential forms
            if BrowserSecurityService.detectCredentialForm(in: content.html) {
                securityWarning = "This page contains a login/credential form. Be cautious about entering sensitive information."
            }

            AppLogger.shared.log("Extracted page content: \(content.title)", level: .info)
            return content

        } catch {
            AppLogger.shared.logError(error, context: "Failed to extract page content")
            return nil
        }
    }

    private func parsePageContent(_ dict: [String: Any], url: URL) -> PageContent {
        let title = dict["title"] as? String ?? ""
        let text = dict["text"] as? String ?? ""
        let html = dict["html"] as? String ?? ""

        // Parse links
        var links: [Link] = []
        if let linksArray = dict["links"] as? [[String: Any]] {
            links = linksArray.compactMap { linkDict in
                guard let href = linkDict["href"] as? String else { return nil }
                return Link(
                    href: href,
                    text: linkDict["text"] as? String ?? "",
                    isExternal: linkDict["isExternal"] as? Bool ?? false,
                    rel: linkDict["rel"] as? String
                )
            }
        }

        // Parse images
        var images: [ImageInfo] = []
        if let imagesArray = dict["images"] as? [[String: Any]] {
            images = imagesArray.compactMap { imgDict in
                guard let src = imgDict["src"] as? String else { return nil }
                return ImageInfo(
                    src: src,
                    alt: imgDict["alt"] as? String,
                    width: imgDict["width"] as? Int,
                    height: imgDict["height"] as? Int
                )
            }
        }

        // Parse forms
        var forms: [FormInfo] = []
        if let formsArray = dict["forms"] as? [[String: Any]] {
            forms = formsArray.compactMap { formDict in
                let formId = formDict["id"] as? String ?? UUID().uuidString
                let fields: [FormInfo.FormField] = (formDict["fields"] as? [[String: Any]] ?? []).compactMap { fieldDict in
                    guard let name = fieldDict["name"] as? String else { return nil }
                    return FormInfo.FormField(
                        name: name,
                        type: fieldDict["type"] as? String ?? "text",
                        placeholder: fieldDict["placeholder"] as? String,
                        required: fieldDict["required"] as? Bool ?? false
                    )
                }
                return FormInfo(
                    id: formId,
                    action: formDict["action"] as? String,
                    method: formDict["method"] as? String ?? "GET",
                    fields: fields
                )
            }
        }

        // Parse metadata
        var metadata = PageContent.PageMetadata()
        if let metaDict = dict["metadata"] as? [String: Any] {
            metadata.description = metaDict["description"] as? String
            metadata.keywords = metaDict["keywords"] as? [String] ?? []
            metadata.author = metaDict["author"] as? String
            metadata.publishedDate = metaDict["publishedDate"] as? String
            metadata.language = metaDict["language"] as? String
        }

        return PageContent(
            title: title,
            url: url,
            text: text,
            html: html,
            links: links,
            images: images,
            forms: forms,
            metadata: metadata
        )
    }

    /// Take a screenshot of the current page
    func takeScreenshot() async -> NSImage? {
        guard let webView = currentWebView else { return nil }

        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds

        do {
            let image = try await webView.takeSnapshot(configuration: config)
            AppLogger.shared.log("Took browser screenshot", level: .info)
            return image
        } catch {
            AppLogger.shared.logError(error, context: "Failed to take screenshot")
            return nil
        }
    }

    /// Find elements matching a selector or description
    func findElements(matching query: String) async -> [WebElement] {
        guard let webView = currentWebView else { return [] }

        // JavaScript to find elements
        let findScript = """
        (function() {
            const query = `\(query.replacingOccurrences(of: "`", with: "\\`"))`;
            let elements = [];

            // Try CSS selector first
            try {
                elements = Array.from(document.querySelectorAll(query));
            } catch(e) {
                // If not valid selector, search by text content
                const allElements = document.querySelectorAll('*');
                elements = Array.from(allElements).filter(el =>
                    el.innerText && el.innerText.toLowerCase().includes(query.toLowerCase())
                );
            }

            return elements.slice(0, 50).map((el, idx) => {
                const rect = el.getBoundingClientRect();
                const style = window.getComputedStyle(el);
                return {
                    id: el.id || 'element-' + idx,
                    selector: getUniqueSelector(el),
                    tagName: el.tagName.toLowerCase(),
                    text: el.innerText ? el.innerText.substring(0, 200) : null,
                    attributes: Object.fromEntries(Array.from(el.attributes).map(a => [a.name, a.value])),
                    rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
                    isClickable: el.tagName === 'A' || el.tagName === 'BUTTON' || el.onclick != null || style.cursor === 'pointer',
                    isVisible: rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none'
                };
            });

            function getUniqueSelector(el) {
                if (el.id) return '#' + el.id;
                if (el.className && typeof el.className === 'string') {
                    const classes = el.className.split(' ').filter(c => c).slice(0, 2).join('.');
                    if (classes) return el.tagName.toLowerCase() + '.' + classes;
                }
                return el.tagName.toLowerCase();
            }
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(findScript)

            guard let elementsArray = result as? [[String: Any]] else { return [] }

            let elements = elementsArray.compactMap { dict -> WebElement? in
                guard let selector = dict["selector"] as? String,
                      let tagName = dict["tagName"] as? String else { return nil }

                var rect = CGRect.zero
                if let rectDict = dict["rect"] as? [String: Any] {
                    rect = CGRect(
                        x: rectDict["x"] as? CGFloat ?? 0,
                        y: rectDict["y"] as? CGFloat ?? 0,
                        width: rectDict["width"] as? CGFloat ?? 0,
                        height: rectDict["height"] as? CGFloat ?? 0
                    )
                }

                return WebElement(
                    id: dict["id"] as? String ?? UUID().uuidString,
                    selector: selector,
                    tagName: tagName,
                    text: dict["text"] as? String,
                    attributes: dict["attributes"] as? [String: String] ?? [:],
                    rect: rect,
                    isClickable: dict["isClickable"] as? Bool ?? false,
                    isVisible: dict["isVisible"] as? Bool ?? true
                )
            }

            AppLogger.shared.log("Found \(elements.count) elements matching: \(query)", level: .info)
            return elements

        } catch {
            AppLogger.shared.logError(error, context: "Failed to find elements")
            return []
        }
    }

    // MARK: - Automation

    /// Click on an element
    func click(element: WebElement, requireConfirmation: Bool = true) async -> Bool {
        if requireConfirmation {
            let confirmed = await requestConfirmation(
                action: .click,
                description: "Click on \(element.tagName): \(element.text ?? element.selector)"
            )
            guard confirmed else { return false }
        }

        guard let webView = currentWebView else { return false }
        guard checkRateLimit() else { return false }

        let clickScript = """
        (function() {
            const el = document.querySelector(`\(element.selector.replacingOccurrences(of: "`", with: "\\`"))`);
            if (el) {
                el.click();
                return true;
            }
            return false;
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(clickScript)
            let success = result as? Bool ?? false
            AppLogger.shared.log("Clicked element: \(element.selector) - success: \(success)", level: .info)
            return success
        } catch {
            AppLogger.shared.logError(error, context: "Failed to click element")
            return false
        }
    }

    /// Type text into an element
    func type(text: String, into element: WebElement, requireConfirmation: Bool = true) async -> Bool {
        if requireConfirmation {
            let confirmed = await requestConfirmation(
                action: .type,
                description: "Type '\(text.prefix(50))...' into \(element.tagName)"
            )
            guard confirmed else { return false }
        }

        guard let webView = currentWebView else { return false }
        guard checkRateLimit() else { return false }

        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\n", with: "\\n")

        let typeScript = """
        (function() {
            const el = document.querySelector(`\(element.selector.replacingOccurrences(of: "`", with: "\\`"))`);
            if (el) {
                el.focus();
                el.value = `\(escapedText)`;
                el.dispatchEvent(new Event('input', { bubbles: true }));
                el.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
            }
            return false;
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(typeScript)
            let success = result as? Bool ?? false
            AppLogger.shared.log("Typed into element: \(element.selector) - success: \(success)", level: .info)
            return success
        } catch {
            AppLogger.shared.logError(error, context: "Failed to type into element")
            return false
        }
    }

    /// Scroll to a position
    func scroll(to position: ScrollPosition) async {
        guard let webView = currentWebView else { return }
        guard checkRateLimit() else { return }

        let scrollScript: String
        switch position {
        case .top:
            scrollScript = "window.scrollTo({ top: 0, behavior: 'smooth' });"
        case .bottom:
            scrollScript = "window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });"
        case .element(let selector):
            scrollScript = """
            (function() {
                const el = document.querySelector(`\(selector.replacingOccurrences(of: "`", with: "\\`"))`);
                if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
            })();
            """
        case .coordinates(let x, let y):
            scrollScript = "window.scrollTo({ top: \(y), left: \(x), behavior: 'smooth' });"
        }

        do {
            try await webView.evaluateJavaScript(scrollScript)
            AppLogger.shared.log("Scrolled to: \(position)", level: .info)
        } catch {
            AppLogger.shared.logError(error, context: "Failed to scroll")
        }
    }

    /// Execute arbitrary JavaScript
    func executeScript(_ js: String) async -> Any? {
        guard let webView = currentWebView else { return nil }

        do {
            let result = try await webView.evaluateJavaScript(js)
            AppLogger.shared.log("Executed custom script", level: .info)
            return result
        } catch {
            AppLogger.shared.logError(error, context: "Failed to execute script")
            return nil
        }
    }

    // MARK: - Session Management

    /// Enable isolated session (no persistent cookies)
    func enableIsolatedSession() {
        isolatedSession = true
        sessionDataStore = WKWebsiteDataStore.nonPersistent()

        // Recreate all web views with new session
        for tab in tabs {
            if let oldWebView = webViewStore[tab.id] {
                let newWebView = createWebView()
                webViewStore[tab.id] = newWebView

                if let url = tab.url {
                    newWebView.load(URLRequest(url: url))
                }
            }
        }

        AppLogger.shared.log("Enabled isolated browser session", level: .info)
    }

    /// Clear browsing data
    func clearBrowsingData() async {
        guard let dataStore = sessionDataStore else { return }

        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let date = Date(timeIntervalSince1970: 0)

        await dataStore.removeData(ofTypes: dataTypes, modifiedSince: date)
        AppLogger.shared.log("Cleared browser data", level: .info)
    }

    // MARK: - Private Helpers

    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        if let dataStore = sessionDataStore {
            config.websiteDataStore = dataStore
        }

        // Disable file URL access for security
        config.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = userAgent
        webView.allowsBackForwardNavigationGestures = true

        #if DEBUG
        webView.isInspectable = true
        #endif

        return webView
    }

    private func checkRateLimit() -> Bool {
        actionTimestamps.removeAll { Date().timeIntervalSince($0) > 60 }

        if actionTimestamps.count >= maxActionsPerMinute {
            error = "Too many browser actions. Please wait."
            return false
        }

        actionTimestamps.append(Date())
        return true
    }

    private func requestConfirmation(action: BrowserActionConfirmation.BrowserAction, description: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                pendingConfirmation = BrowserActionConfirmation(
                    action: action,
                    description: description
                )

                // Wait for user response (timeout after 30 seconds)
                Task {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if pendingConfirmation != nil {
                        pendingConfirmation = nil
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    /// Approve pending confirmation
    func approveConfirmation() {
        pendingConfirmation?.isApproved = true
        pendingConfirmation = nil
    }

    /// Deny pending confirmation
    func denyConfirmation() {
        pendingConfirmation = nil
    }

    fileprivate func updateNavigationState(from webView: WKWebView) {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        currentURL = webView.url

        if activeTabIndex < tabs.count {
            tabs[activeTabIndex].canGoBack = webView.canGoBack
            tabs[activeTabIndex].canGoForward = webView.canGoForward
            tabs[activeTabIndex].url = webView.url
            tabs[activeTabIndex].title = webView.title ?? "Loading..."
        }
    }

    fileprivate func handleNavigationFinished(tabId: UUID, webView: WKWebView) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].isLoading = false
            tabs[index].title = webView.title ?? webView.url?.host ?? "Page"
            tabs[index].canGoBack = webView.canGoBack
            tabs[index].canGoForward = webView.canGoForward
        }

        if tabs[activeTabIndex].id == tabId {
            isLoading = false
            updateNavigationState(from: webView)
        }
    }

    fileprivate func handleNavigationFailed(tabId: UUID, error: Error) {
        if let index = tabs.firstIndex(where: { $0.id == tabId }) {
            tabs[index].isLoading = false
        }

        if tabs[activeTabIndex].id == tabId {
            isLoading = false
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Navigation Delegate

private class BrowserNavigationDelegate: NSObject, WKNavigationDelegate {
    weak var service: BrowserService?
    let tabId: UUID

    init(service: BrowserService, tabId: UUID) {
        self.service = service
        self.tabId = tabId
    }

    @MainActor
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        service?.isLoading = true
    }

    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        service?.handleNavigationFinished(tabId: tabId, webView: webView)
    }

    @MainActor
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        service?.handleNavigationFailed(tabId: tabId, error: error)
    }

    @MainActor
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        service?.handleNavigationFailed(tabId: tabId, error: error)
    }

    @MainActor
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // Security check
        let securityCheck = BrowserSecurityService.isURLSafe(url)
        if !securityCheck.safe {
            service?.securityWarning = securityCheck.reason
            decisionHandler(.cancel)
            return
        }

        // Allow normal navigation
        decisionHandler(.allow)
    }
}
