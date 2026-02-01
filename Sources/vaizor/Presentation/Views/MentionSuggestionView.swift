import SwiftUI

/// Popup view showing mention suggestions
struct MentionSuggestionView: View {
    let suggestions: [MentionableItem]
    let selectedIndex: Int
    let onSelect: (MentionableItem) -> Void
    let onDismiss: () -> Void

    @State private var hoveredIndex: Int? = nil

    private var groupedSuggestions: [(title: String, items: [MentionableItem])] {
        var groups: [(String, [MentionableItem])] = []

        // Recent files first
        let recent = suggestions.filter { $0.isRecent }
        if !recent.isEmpty {
            groups.append(("Recent", recent))
        }

        // Group by type
        let typeGroups = Dictionary(grouping: suggestions.filter { !$0.isRecent }) { $0.type }
        for type in MentionType.allCases {
            if let items = typeGroups[type], !items.isEmpty {
                groups.append((type.displayName + "s", items))
            }
        }

        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if suggestions.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(groupedSuggestions.enumerated()), id: \.offset) { groupIndex, group in
                                VStack(spacing: 0) {
                                    // Section header
                                    HStack {
                                        Text(group.title)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .textCase(.uppercase)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.03))

                                    // Items in group
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { itemIndex, item in
                                        let globalIndex = calculateGlobalIndex(groupIndex: groupIndex, itemIndex: itemIndex)

                                        MentionSuggestionRow(
                                            item: item,
                                            isSelected: globalIndex == selectedIndex,
                                            isHovered: globalIndex == hoveredIndex,
                                            onSelect: { onSelect(item) }
                                        )
                                        .id(globalIndex)
                                        .onHover { hovering in
                                            hoveredIndex = hovering ? globalIndex : nil
                                        }
                                    }

                                    // Divider between groups
                                    if groupIndex < groupedSuggestions.count - 1 {
                                        Divider()
                                            .padding(.vertical, 2)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            // Keyboard hints
            keyboardHints
        }
        .frame(width: 320)
        .background(.thinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            Text("No matches found")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("Try a different search term")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var keyboardHints: some View {
        HStack(spacing: 12) {
            keyHint(keys: ["", ""], label: "navigate")
            keyHint(keys: [""], label: "select")
            keyHint(keys: ["esc"], label: "dismiss")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
    }

    private func keyHint(keys: [String], label: String) -> some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .cornerRadius(3)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }

    private func calculateGlobalIndex(groupIndex: Int, itemIndex: Int) -> Int {
        var index = 0
        for i in 0..<groupIndex {
            index += groupedSuggestions[i].items.count
        }
        return index + itemIndex
    }
}

/// Individual row in the mention suggestion list
struct MentionSuggestionRow: View {
    let item: MentionableItem
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void

    private var iconColor: Color {
        Color(hex: MentionableItem.colorForPath(item.value, type: item.type))
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 26, height: 26)

                    Image(systemName: item.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(item.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if item.isRecent {
                            Text("recent")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(ThemeColors.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(ThemeColors.accent.opacity(0.12))
                                .cornerRadius(3)
                        }
                    }

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 0)

                // File size if available
                if let size = item.fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                // Type badge
                Text(item.type.prefix)
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(iconColor)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (isSelected || isHovered) ? iconColor.opacity(0.1) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.type.displayName): \(item.displayName)")
        .accessibilityHint(item.subtitle ?? "")
    }
}

/// A styled pill/chip view for displaying a mention in the input area
struct MentionPillView: View {
    let mention: Mention
    let onRemove: () -> Void
    let onTap: (() -> Void)?

    @State private var isHovered = false

    private var pillColor: Color {
        Color(hex: mention.type.color)
    }

    var body: some View {
        HStack(spacing: 4) {
            // Icon
            Image(systemName: MentionableItem.iconForPath(mention.value, type: mention.type))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(pillColor)

            // Name
            Text(mention.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Token count if resolved
            if let tokenCount = mention.tokenCount, tokenCount > 0 {
                Text("~\(tokenCount)")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            // Remove button (shown on hover)
            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(pillColor.opacity(isHovered ? 0.2 : 0.12))
        )
        .overlay(
            Capsule()
                .stroke(pillColor.opacity(isHovered ? 0.4 : 0.25), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap?()
        }
        .help("\(mention.type.displayName): \(mention.value)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mention.type.displayName): \(mention.displayName)")
        .accessibilityHint("Double tap to view details, or use delete key to remove")
    }
}

/// View showing all active mentions in a horizontal scroll
struct MentionPillsView: View {
    let mentions: [Mention]
    let onRemove: (Mention) -> Void
    let onTap: ((Mention) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(mentions) { mention in
                    MentionPillView(
                        mention: mention,
                        onRemove: { onRemove(mention) },
                        onTap: onTap != nil ? { onTap?(mention) } : nil
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Token count warning view
struct MentionContextWarningView: View {
    let totalTokens: Int
    let warnings: [String]

    private var severity: Severity {
        if totalTokens > 20000 { return .high }
        if totalTokens > 10000 { return .medium }
        if !warnings.isEmpty { return .low }
        return .none
    }

    private enum Severity {
        case none, low, medium, high

        var color: Color {
            switch self {
            case .none: return .clear
            case .low: return ThemeColors.info
            case .medium: return ThemeColors.warning
            case .high: return ThemeColors.error
            }
        }

        var icon: String {
            switch self {
            case .none: return ""
            case .low: return "info.circle.fill"
            case .medium: return "exclamationmark.triangle.fill"
            case .high: return "exclamationmark.octagon.fill"
            }
        }
    }

    var body: some View {
        if severity != .none {
            HStack(spacing: 8) {
                Image(systemName: severity.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(severity.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Context: ~\(totalTokens) tokens")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)

                    if !warnings.isEmpty {
                        Text(warnings.first ?? "")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(severity.color.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

// MARK: - Preview

#Preview("Mention Suggestions") {
    MentionSuggestionView(
        suggestions: [
            MentionableItem(type: .file, value: "/Users/test/main.swift", displayName: "main.swift", subtitle: "/Users/test", isRecent: true),
            MentionableItem(type: .file, value: "/Users/test/app.py", displayName: "app.py", subtitle: "/Users/test"),
            MentionableItem(type: .folder, value: "/Users/test/src", displayName: "src", subtitle: "12 items"),
            MentionableItem(type: .url, value: "https://github.com", displayName: "github.com", subtitle: "GitHub"),
            MentionableItem(type: .project, value: "/Users/test/myproject", displayName: "myproject", subtitle: "Swift Package")
        ],
        selectedIndex: 0,
        onSelect: { _ in },
        onDismiss: {}
    )
    .padding()
    .background(Color(nsColor: .windowBackgroundColor))
}

#Preview("Mention Pills") {
    VStack {
        MentionPillsView(
            mentions: [
                Mention(type: .file, value: "/path/to/file.swift", tokenCount: 250),
                Mention(type: .folder, value: "/src", tokenCount: 1200),
                Mention(type: .url, value: "https://docs.swift.org", tokenCount: 3000)
            ],
            onRemove: { _ in },
            onTap: nil
        )
        .padding()

        MentionContextWarningView(totalTokens: 15000, warnings: ["Large context may affect response quality"])
            .padding()
    }
    .frame(width: 400)
    .background(Color(nsColor: .windowBackgroundColor))
}
