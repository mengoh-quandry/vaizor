import SwiftUI

struct ThinkingIndicator: View {
    @State private var animationPhase = 0.0

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.purple)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    // Animated dots
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.purple.opacity(dotOpacity(for: index)))
                            .frame(width: 8, height: 8)
                            .scaleEffect(dotScale(for: index))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(16)

                Text("Thinking...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            Spacer(minLength: 60)
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: false)
            ) {
                animationPhase = 1.0
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        let progress = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        return 0.3 + (0.7 * sin(progress * .pi))
    }

    private func dotScale(for index: Int) -> Double {
        let progress = (animationPhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
        return 0.8 + (0.4 * sin(progress * .pi))
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
