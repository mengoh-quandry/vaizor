import AppKit
import SwiftUI

struct SearchView: View {
    @EnvironmentObject var container: DependencyContainer
    @ObservedObject var conversationManager: ConversationManager
    @State private var searchText: String = ""
    @State private var searchResults: [(message: Message, score: Double)] = []
    @State private var isSearching: Bool = false
    @State private var selectedConversationId: UUID?
    @FocusState private var isSearchFocused: Bool
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search conversations...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isSearchFocused)
                    .onSubmit {
                        searchTask?.cancel()
                        Task {
                            await performSearch()
                        }
                    }
                    .onChange(of: searchText) { _, newValue in
                        // Cancel previous search task
                        searchTask?.cancel()
                        
                        if newValue.isEmpty {
                            searchResults = []
                            isSearching = false
                        } else {
                            // Debounce search
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                                if !Task.isCancelled && searchText == newValue {
                                    await performSearch()
                                }
                            }
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            // Search results
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No results found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Try different keywords")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else if searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("Search across all conversations")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Type to search message content")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.message.id) { index, result in
                            SearchResultRow(
                                message: result.message,
                                score: result.score,
                                searchQuery: searchText,
                                conversationManager: conversationManager,
                                onSelect: { conversationId in
                                    // Post notification to select conversation
                                    NotificationCenter.default.post(
                                        name: .selectConversation,
                                        object: nil,
                                        userInfo: ["conversationId": conversationId]
                                    )
                                }
                            )
                            
                            if index < searchResults.count - 1 {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                searchResults = []
                isSearching = false
            }
            return
        }
        
        await MainActor.run {
            isSearching = true
        }
        
        let repository = ConversationRepository()
        let results = await repository.searchMessages(
            query: searchText,
            conversationId: selectedConversationId,
            limit: 50
        )
        
        await MainActor.run {
            searchResults = results
            isSearching = false
        }
    }
}

struct SearchResultRow: View {
    let message: Message
    let score: Double
    let searchQuery: String
    let conversationManager: ConversationManager
    let onSelect: (UUID) -> Void
    
    private var conversation: Conversation? {
        conversationManager.conversations.first { $0.id == message.conversationId }
    }
    
    var body: some View {
        Button {
            onSelect(message.conversationId)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                // Conversation title
                HStack {
                    Text(conversation?.title ?? "Untitled Conversation")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(message.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Message preview with highlighting
                Text(highlightedPreview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Role indicator
                HStack(spacing: 4) {
                    Image(systemName: message.role == .user ? "person.fill" : "sparkles")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    Text(message.role == .user ? "You" : "Assistant")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.clear)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    private var highlightedPreview: AttributedString {
        let preview = String(message.content.prefix(200))
        let attributed = NSMutableAttributedString(string: preview)

        let queryWords = searchQuery.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count > 2 }

        let fullRange = NSRange(location: 0, length: (preview as NSString).length)
        for word in queryWords {
            var searchRange = fullRange
            while true {
                let foundRange = (preview as NSString).range(of: word, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
                if foundRange.location == NSNotFound { break }

                attributed.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.3), range: foundRange)
                attributed.addAttribute(.foregroundColor, value: NSColor.labelColor, range: foundRange)

                let nextLocation = foundRange.location + foundRange.length
                if nextLocation >= fullRange.length { break }
                searchRange = NSRange(location: nextLocation, length: fullRange.length - nextLocation)
            }
        }

        return AttributedString(attributed)
    }
}
