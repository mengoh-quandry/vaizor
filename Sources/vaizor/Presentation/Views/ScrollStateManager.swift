import SwiftUI
import Combine

/// Scroll state manager for smooth scrolling behavior
/// Inspired by Chorus's useScrollDetection hook
@MainActor
class ScrollStateManager: ObservableObject {
    // MARK: - Published State

    /// Whether auto-scroll to bottom is enabled
    @Published var autoScrollEnabled: Bool = true

    /// Whether the scroll-to-bottom button should be shown
    @Published var showScrollButton: Bool = false

    /// Whether the scrollbar should be visible
    @Published var showScrollbar: Bool = false

    /// Whether user is currently scrolling
    @Published private(set) var isScrolling: Bool = false

    /// Current scroll offset from bottom (in points)
    @Published private(set) var distanceFromBottom: CGFloat = 0

    // MARK: - Configuration

    /// Distance from bottom (in points) before showing scroll button
    private let scrollButtonThreshold: CGFloat = 400

    /// Delay before hiding scrollbar after scroll stops (ms)
    private let scrollbarHideDelay: UInt64 = 550_000_000 // 550ms

    /// Delay before considering scroll stopped (ms)
    private let scrollStopDelay: UInt64 = 150_000_000 // 150ms

    // MARK: - Internal State (accessed by ScrollDetectionModifier)

    private var scrollStopTask: Task<Void, Never>?
    private var scrollbarHideTask: Task<Void, Never>?
    var lastContentHeight: CGFloat = 0
    private var lastScrollOffset: CGFloat = 0

    // MARK: - Public Methods

    /// Called when scroll position changes
    func onScroll(offset: CGFloat, contentHeight: CGFloat, viewportHeight: CGFloat) {
        // Calculate distance from bottom
        let maxOffset = max(0, contentHeight - viewportHeight)
        distanceFromBottom = maxOffset - offset

        // Update scroll button visibility
        let shouldShowButton = distanceFromBottom > scrollButtonThreshold
        if shouldShowButton != showScrollButton {
            withAnimation(.easeInOut(duration: 0.2)) {
                showScrollButton = shouldShowButton
            }
        }

        // Update auto-scroll state
        if distanceFromBottom < 50 {
            autoScrollEnabled = true
        } else if offset < lastScrollOffset {
            // User scrolled up, disable auto-scroll
            autoScrollEnabled = false
        }

        lastScrollOffset = offset
        lastContentHeight = contentHeight

        // Handle scrolling state for scrollbar visibility
        handleScrolling()
    }

    /// Called when content size changes (new messages, etc.)
    func onContentSizeChange(newHeight: CGFloat, viewportHeight: CGFloat) {
        let heightDelta = newHeight - lastContentHeight

        // If content grew and we're at/near bottom, stay at bottom
        if heightDelta > 0 && autoScrollEnabled && distanceFromBottom < 100 {
            // Content grew, keep auto-scroll active
        }

        lastContentHeight = newHeight
    }

    /// Request scroll to bottom
    func scrollToBottom() {
        autoScrollEnabled = true
        withAnimation(.easeInOut(duration: 0.2)) {
            showScrollButton = false
        }
    }

    /// Request scroll to top
    func scrollToTop() {
        autoScrollEnabled = false
    }

    /// Reset state (e.g., when conversation changes)
    func reset() {
        autoScrollEnabled = true
        showScrollButton = false
        distanceFromBottom = 0
        lastContentHeight = 0
        lastScrollOffset = 0
        cancelPendingTasks()
    }

    // MARK: - Private Methods

    private func handleScrolling() {
        // Cancel existing scroll stop task
        scrollStopTask?.cancel()

        // Mark as scrolling
        if !isScrolling {
            isScrolling = true
            showScrollbar = true
            scrollbarHideTask?.cancel()
        }

        // Schedule scroll stop detection
        scrollStopTask = Task {
            try? await Task.sleep(nanoseconds: scrollStopDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.isScrolling = false
                self.scheduleScrollbarHide()
            }
        }
    }

    private func scheduleScrollbarHide() {
        scrollbarHideTask?.cancel()

        scrollbarHideTask = Task {
            try? await Task.sleep(nanoseconds: scrollbarHideDelay)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                if !self.isScrolling {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.showScrollbar = false
                    }
                }
            }
        }
    }

    private func cancelPendingTasks() {
        scrollStopTask?.cancel()
        scrollbarHideTask?.cancel()
        scrollStopTask = nil
        scrollbarHideTask = nil
    }

    deinit {
        scrollStopTask?.cancel()
        scrollbarHideTask?.cancel()
    }
}

// MARK: - Scroll Position Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Scroll Detection View Modifier

struct ScrollDetectionModifier: ViewModifier {
    @ObservedObject var scrollState: ScrollStateManager
    @State private var viewportHeight: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { outerGeo in
            content
                .background(
                    GeometryReader { innerGeo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: outerGeo.frame(in: .global).minY - innerGeo.frame(in: .global).minY
                            )
                            .preference(
                                key: ContentHeightPreferenceKey.self,
                                value: innerGeo.size.height
                            )
                    }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    scrollState.onScroll(
                        offset: offset,
                        contentHeight: scrollState.lastContentHeight,
                        viewportHeight: viewportHeight
                    )
                }
                .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                    scrollState.onContentSizeChange(
                        newHeight: height,
                        viewportHeight: viewportHeight
                    )
                }
                .onAppear {
                    viewportHeight = outerGeo.size.height
                }
                .onChange(of: outerGeo.size.height) { _, newHeight in
                    viewportHeight = newHeight
                }
        }
    }
}

extension View {
    func trackScrollState(_ scrollState: ScrollStateManager) -> some View {
        modifier(ScrollDetectionModifier(scrollState: scrollState))
    }
}

// MARK: - Smart Scroll-to-Bottom Button

struct SmartScrollButton: View {
    @ObservedObject var scrollState: ScrollStateManager
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var hasNewMessages = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if scrollState.showScrollButton {
            Button(action: {
                // Press feedback
                if !reduceMotion {
                    withAnimation(VaizorAnimations.buttonPress) {
                        isPressed = true
                    }
                    // Quick bounce back
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(VaizorAnimations.buttonPress) {
                            isPressed = false
                        }
                    }
                }
                scrollState.scrollToBottom()
                action()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .symbolEffect(.bounce, value: hasNewMessages)

                    Text("Scroll to bottom")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(ThemeColors.accent)
                        .shadow(
                            color: ThemeColors.accent.opacity(isHovered ? 0.4 : 0.25),
                            radius: isHovered ? 10 : 5,
                            y: isHovered ? 3 : 2
                        )
                )
                .scaleEffect(isPressed ? 0.95 : (isHovered && !reduceMotion ? 1.05 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(VaizorAnimations.subtleSpring) {
                    isHovered = hovering
                }
            }
            .transition(
                .asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: 20)),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                )
            )
            .animation(VaizorAnimations.quickBounce, value: scrollState.showScrollButton)
        }
    }
}

// MARK: - Dynamic Input Spacer

/// A spacer that grows with the input height to prevent messages being hidden
struct DynamicInputSpacer: View {
    let inputHeight: CGFloat
    let baseHeight: CGFloat

    var body: some View {
        Color.clear
            .frame(height: max(baseHeight, inputHeight + 20))
    }
}

// MARK: - Scrollbar Visibility Modifier

struct ScrollbarVisibilityModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .scrollIndicators(isVisible ? .visible : .hidden)
    }
}

extension View {
    func scrollbarVisibility(_ isVisible: Bool) -> some View {
        modifier(ScrollbarVisibilityModifier(isVisible: isVisible))
    }
}
