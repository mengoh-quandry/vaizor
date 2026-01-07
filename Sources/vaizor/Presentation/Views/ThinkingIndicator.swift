import SwiftUI
import AppKit

struct ThinkingIndicator: View {
    let status: String
    @State private var animationPhase: Double = 0
    @State private var glowPhase: Double = 0
    private let thinkingColor = Color(hex: "00976d")

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar with pulse animation - using Vaizor icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [thinkingColor.opacity(0.25), thinkingColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(thinkingColor.opacity(0.3), lineWidth: 1.5)
                            .scaleEffect(1 + glowPhase * 0.1)
                            .opacity(1 - glowPhase)
                    )

                // Load Vaizor.png icon
                if let vaizorImage = loadVaizorIcon() {
                    Image(nsImage: vaizorImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(thinkingColor)
                        .symbolRenderingMode(.hierarchical)
                        .symbolEffect(.pulse)
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    glowPhase = 1.0
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    // Animated dots with smooth animation
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [thinkingColor, thinkingColor.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 9, height: 9)
                            .scaleEffect(dotScale(for: index))
                            .opacity(dotOpacity(for: index))
                            .shadow(color: thinkingColor.opacity(0.4 * dotOpacity(for: index)), radius: 3)
                            .animation(
                                Animation.easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: animationPhase
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.clear)
                .cornerRadius(20)
                .onAppear {
                    Task {
                        while !Task.isCancelled {
                            withAnimation(.linear(duration: 2.4)) {
                                animationPhase = animationPhase >= 1.0 ? 0.0 : animationPhase + 0.05
                            }
                            try? await Task.sleep(nanoseconds: 240_000_000)
                        }
                    }
                }

                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: status)
            }

            Spacer(minLength: 60)
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let delay = Double(index) * 0.3 // Increased delay for slower animation
        let adjustedPhase = (animationPhase + delay).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + (0.7 * sin(adjustedPhase * .pi * 2))
    }

    private func dotScale(for index: Int) -> Double {
        let delay = Double(index) * 0.3 // Increased delay for slower animation
        let adjustedPhase = (animationPhase + delay).truncatingRemainder(dividingBy: 1.0)
        return 0.6 + (0.4 * sin(adjustedPhase * .pi * 2))
    }
    
    private func loadVaizorIcon() -> NSImage? {
        // Try Bundle resource loading first
        if let bundlePath = Bundle.main.path(forResource: "Vaizor", ofType: "png", inDirectory: "Resources/Icons") ??
                            Bundle.main.path(forResource: "Vaizor", ofType: "png") {
            return NSImage(contentsOfFile: bundlePath)
        }
        
        // Try direct file paths (for development)
        let fileManager = FileManager.default
        let possiblePaths = [
            Bundle.main.bundlePath + "/../../Resources/Icons/Vaizor.png",
            Bundle.main.bundlePath + "/Resources/Icons/Vaizor.png",
            Bundle.main.resourcePath.map { $0 + "/Resources/Icons/Vaizor.png" },
            Bundle.main.resourcePath.map { $0 + "/../../Resources/Icons/Vaizor.png" },
            "/Users/marcus/Downloads/vaizor/Resources/Icons/Vaizor.png"
        ].compactMap { $0 }
        
        for path in possiblePaths {
            guard fileManager.fileExists(atPath: path) else { continue }
            if let image = NSImage(contentsOfFile: path), image.isValid {
                return image
            }
        }
        
        return nil
    }
}

struct LoadingIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 1.0)
                            .repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }

            Text("Loading...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}
