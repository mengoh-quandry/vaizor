import Foundation
import SwiftUI
import MarkdownUI

/// Service for rendering markdown with caching
@MainActor
final class MarkdownRenderService {
    static let shared = MarkdownRenderService()
    
    private var cache: [String: RenderedMarkdown] = [:]
    private let maxCacheSize = 1000
    
    private struct RenderedMarkdown {
        let view: AnyView
        let size: CGSize
        let timestamp: Date
    }
    
    private init() {}
    
    /// Render markdown content, using cache if available
    func render(_ content: String, cacheKey: String? = nil) async -> AnyView {
        let key = cacheKey ?? content
        
        // Check cache first
        if let cached = cache[key] {
            return cached.view
        }
        
        // Render on main actor to avoid non-Sendable SwiftUI crossings
        let rendered = createMarkdownView(content: content)
        
        // Cache the result
        await cacheResult(key: key, view: rendered, content: content)
        
        return rendered
    }
    
    private func createMarkdownView(content: String) -> AnyView {
        // Return a basic markdown view - styling will be applied by the caller
        return AnyView(
            MarkdownUI.Markdown(content)
                .textSelection(.enabled)
        )
    }
    
    private func cacheResult(key: String, view: AnyView, content: String) async {
        // Estimate size (rough calculation)
        let estimatedSize = CGSize(width: 400, height: max(100, content.count / 10))
        
        cache[key] = RenderedMarkdown(
            view: view,
            size: estimatedSize,
            timestamp: Date()
        )
        
        // Evict old entries if cache is too large
        if cache.count > maxCacheSize {
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(cache.count - maxCacheSize)
            for (key, _) in toRemove {
                cache.removeValue(forKey: key)
            }
        }
    }
    
    func clearCache() async {
        cache.removeAll()
    }
    
    func getCacheSize() async -> Int {
        return cache.count
    }
}
