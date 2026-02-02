import SwiftUI
import WebKit

/// Enhanced side panel for displaying artifacts with animations and polish
struct ArtifactPanelView: View {
    let artifact: Artifact
    let onClose: () -> Void

    @State private var showCode = false
    @State private var isLoading = true
    @State private var error: String?
    @State private var isAppearing = false
    @State private var isRefreshing = false
    @State private var panelWidth: CGFloat = 500

    // Animation
    @State private var contentOpacity: Double = 0
    @State private var headerOffset: CGFloat = -20
    @State private var panelOffset: CGFloat = 50
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            // Resize handle on left edge
            resizeHandle

            // Main panel content
            VStack(spacing: 0) {
                // Header
                header
                    .offset(y: headerOffset)

                Divider()

                // Content
                ZStack {
                    if showCode {
                        codeView
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        previewView
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .opacity(contentOpacity)
                .animation(VaizorAnimations.contentCrossfade, value: showCode)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 350, idealWidth: panelWidth, maxWidth: 800)
        .offset(x: reduceMotion ? 0 : panelOffset)
        .onAppear {
            guard !reduceMotion else {
                isAppearing = true
                contentOpacity = 1
                headerOffset = 0
                panelOffset = 0
                return
            }

            withAnimation(VaizorAnimations.panelSlide) {
                isAppearing = true
                contentOpacity = 1
                headerOffset = 0
                panelOffset = 0
            }
        }
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .overlay(
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 1)
                    .padding(.vertical, 8),
                alignment: .leading
            )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // Icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: artifact.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            // Title and type
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)

                Text(artifact.type.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Refresh button (preview mode only)
                if !showCode {
                    Button {
                        refreshPreview()
                    } label: {
                        Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(6)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                    .help("Refresh preview")
                }

                // Preview/Code toggle
                Picker("", selection: $showCode) {
                    Image(systemName: "eye").tag(false)
                    Image(systemName: "chevron.left.forwardslash.chevron.right").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)
                .help(showCode ? "Show preview" : "Show code")

                // Copy button
                Button {
                    copyToClipboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Copy code")

                // Close button
                Button {
                    if reduceMotion {
                        onClose()
                    } else {
                        withAnimation(VaizorAnimations.panelSlide) {
                            contentOpacity = 0
                            headerOffset = -20
                            panelOffset = 50
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onClose()
                        }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
                .help("Close panel (Esc)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    // MARK: - Preview View

    private var previewView: some View {
        ZStack {
            ArtifactWebView(artifact: artifact, isLoading: $isLoading, error: $error)

            // Loading overlay
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(.accentColor)

                    Text("Rendering artifact...")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .transition(.opacity)
            }

            // Error overlay
            if let error = error {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                    }

                    Text("Preview Error")
                        .font(.system(size: 15, weight: .semibold))

                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button("View Code") {
                        showCode = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .animation(.easeInOut(duration: 0.2), value: error)
    }

    // MARK: - Code View

    private var codeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Code header
                HStack {
                    Text(artifact.type.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(artifact.content.components(separatedBy: "\n").count) lines")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.03))

                Divider()

                // Code content with line numbers
                HStack(alignment: .top, spacing: 0) {
                    // Line numbers
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach(Array(artifact.content.components(separatedBy: "\n").enumerated()), id: \.offset) { index, _ in
                            Text("\(index + 1)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .frame(height: 18)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.02))

                    Divider()

                    // Code
                    Text(artifact.content)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Actions

    private func refreshPreview() {
        isRefreshing = true
        withAnimation(.linear(duration: 0.5).repeatCount(2)) {
            // Animation handled by rotationEffect
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRefreshing = false
            isLoading = true
            // Force reload by toggling
            error = nil
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(artifact.content, forType: .string)

        // Could add a toast notification here
    }
}

// MARK: - Preview

#Preview {
    HStack {
        Color.gray.opacity(0.1)
            .frame(width: 400)

        ArtifactPanelView(
            artifact: Artifact(
                type: .react,
                title: "Sales Dashboard",
                content: """
                function Dashboard() {
                    const [data, setData] = useState([
                        { name: 'Jan', sales: 4000, profit: 2400 },
                        { name: 'Feb', sales: 3000, profit: 1398 },
                        { name: 'Mar', sales: 5000, profit: 3200 },
                    ]);

                    return (
                        <div className="min-h-screen bg-slate-50 p-8">
                            <h1 className="text-3xl font-bold mb-8">Dashboard</h1>
                            <Card>
                                <CardHeader>
                                    <CardTitle>Revenue</CardTitle>
                                </CardHeader>
                                <CardContent>
                                    <ResponsiveContainer width="100%" height={300}>
                                        <AreaChart data={data}>
                                            <XAxis dataKey="name" />
                                            <YAxis />
                                            <Area dataKey="sales" fill="#3b82f6" />
                                        </AreaChart>
                                    </ResponsiveContainer>
                                </CardContent>
                            </Card>
                        </div>
                    );
                }
                """,
                language: "react"
            ),
            onClose: {}
        )
    }
    .frame(width: 900, height: 600)
}
