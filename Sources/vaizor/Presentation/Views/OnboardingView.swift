import SwiftUI

// MARK: - Onboarding State

enum OnboardingPage: Int, CaseIterable {
    case welcome = 0
    case connectAI = 1
    case features = 2
    case security = 3
    case ready = 4

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .connectAI: return "Connect"
        case .features: return "Features"
        case .security: return "Security"
        case .ready: return "Ready"
        }
    }
}

// MARK: - Main Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage: OnboardingPage = .welcome
    @State private var animateBackground = false
    @State private var enteredApiKey = ""
    @State private var selectedProvider: AIProvider = .claude
    @State private var isCompleting = false  // Prevent double-tap issues
    @State private var discoveredMCPServers: [DiscoveredServer] = []
    @State private var showMCPDiscovery = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mcpDiscoveryService = MCPDiscoveryService()

    // Theme colors
    private let darkBase = ThemeColors.darkBase
    private let darkSurface = ThemeColors.darkSurface
    private let darkBorder = ThemeColors.darkBorder
    private let accent = ThemeColors.accent
    private let textPrimary = ThemeColors.textPrimary
    private let textSecondary = ThemeColors.textSecondary

    var body: some View {
        ZStack {
            // Animated gradient background
            animatedBackground

            VStack(spacing: 0) {
                // Top bar with skip button
                topBar

                // Page content (no ScrollView - window is tall enough)
                VStack {
                    Spacer(minLength: 20)
                    
                    pageContent
                        .frame(maxWidth: 700)
                        .padding(.horizontal, 40)
                    
                    Spacer(minLength: 20)
                }

                // Fixed bottom navigation (always visible)
                bottomNavigation
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateBackground = true
                }
            }

            // Discover MCP servers in background for onboarding prompt
            Task {
                discoveredMCPServers = await mcpDiscoveryService.discoverServers()
            }
        }
        .sheet(isPresented: $showMCPDiscovery) {
            MCPDiscoveryView()
        }
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        ZStack {
            darkBase.ignoresSafeArea()

            // Gradient orbs (subtle, animated)
            if !reduceMotion {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accent.opacity(0.15), accent.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: 600, height: 600)
                    .offset(x: animateBackground ? -150 : -200, y: animateBackground ? -100 : -150)
                    .blur(radius: 60)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ProviderColors.gemini.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(x: animateBackground ? 200 : 250, y: animateBackground ? 150 : 200)
                    .blur(radius: 50)

                // Particle effect
                ParticleEmitterView()
                    .opacity(0.4)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            Button("Skip") {
                guard !isCompleting else { return }
                isCompleting = true
                completeOnboarding()
            }
            .buttonStyle(OnboardingSecondaryButtonStyle())
            .disabled(isCompleting)
            .padding(.trailing, 24)
            .padding(.top, 24)
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private var pageContent: some View {
        switch currentPage {
        case .welcome:
            welcomePage
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .connectAI:
            connectAIPage
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .features:
            featuresPage
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .security:
            securityPage
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        case .ready:
            readyPage
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
        }
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 32) {
            // App icon with glow
            OnboardingAppIcon()

            VStack(spacing: 16) {
                Text("Welcome to Vaizor")
                    .font(VaizorTypography.displayXLarge)
                    .foregroundStyle(textPrimary)

                Text("Your AI assistant with superpowers")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(textSecondary)
            }

            // Feature highlights preview
            HStack(spacing: 24) {
                WelcomeFeaturePill(icon: "sparkles", text: "AI Powered")
                WelcomeFeaturePill(icon: "lock.shield", text: "Secure")
                WelcomeFeaturePill(icon: "bolt", text: "Fast")
            }
            .padding(.top, 20)
        }
        .onboardingPageAnimation(reduceMotion: reduceMotion)
    }

    // MARK: - Connect AI Page

    private var connectAIPage: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(VaizorTypography.displayHeroLight)
                    .foregroundStyle(accent)

                Text("Connect Your AI")
                    .font(VaizorTypography.displayLarge)
                    .foregroundStyle(textPrimary)

                Text("Choose your preferred AI provider")
                    .font(.system(size: 16))
                    .foregroundStyle(textSecondary)
            }

            // Provider cards
            VStack(spacing: 12) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    ProviderCard(
                        provider: provider,
                        isSelected: selectedProvider == provider,
                        onSelect: { selectedProvider = provider }
                    )
                }
            }
            .padding(.horizontal, 20)

            // Ollama callout
            HStack(spacing: 12) {
                Image(systemName: "sparkle")
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Free Local AI with Ollama")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    Text("Run powerful models on your Mac - no API key needed")
                        .font(.system(size: 12))
                        .foregroundStyle(textSecondary)
                }

                Spacer()
            }
            .padding(16)
            .background(accent.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(accent.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Text("You can add API keys later in Settings")
                .font(.system(size: 13))
                .foregroundStyle(textSecondary.opacity(0.7))
        }
        .onboardingPageAnimation(reduceMotion: reduceMotion)
    }

    // MARK: - Features Page

    private var featuresPage: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                    .font(VaizorTypography.displayHeroLight)
                    .foregroundStyle(accent)

                Text("Discover Features")
                    .font(VaizorTypography.displayLarge)
                    .foregroundStyle(textPrimary)

                Text("Powerful tools at your fingertips")
                    .font(.system(size: 16))
                    .foregroundStyle(textSecondary)
            }

            // Feature grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                FeatureCard(
                    icon: "at",
                    title: "@Mentions",
                    description: "Reference files and folders directly in your chat",
                    color: ProviderColors.gemini
                )

                FeatureCard(
                    icon: "folder.badge.gearshape",
                    title: "Projects",
                    description: "Persistent memory across conversations",
                    color: ProviderColors.ollama
                )

                FeatureCard(
                    icon: "globe",
                    title: "Browser Control",
                    description: "Automate web tasks with AI assistance",
                    color: ProviderColors.claude
                )

                FeatureCard(
                    icon: "terminal",
                    title: "Shell Execution",
                    description: "Run commands securely in sandbox",
                    color: accent
                )
            }
            .padding(.horizontal, 20)

            // MCP Discovery callout (only shows if servers found)
            if !discoveredMCPServers.isEmpty {
                Button {
                    showMCPDiscovery = true
                } label: {
                    HStack(spacing: VaizorSpacing.sm) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.system(size: 20))
                            .foregroundStyle(ProviderColors.ollama)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("MCP Servers Found")
                                .font(VaizorTypography.label.weight(.semibold))
                                .foregroundStyle(textPrimary)
                            Text("We found \(discoveredMCPServers.count) MCP server\(discoveredMCPServers.count == 1 ? "" : "s") on your system")
                                .font(VaizorTypography.caption)
                                .foregroundStyle(textSecondary)
                        }

                        Spacer()

                        Text("Import")
                            .font(VaizorTypography.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, VaizorSpacing.sm)
                            .padding(.vertical, VaizorSpacing.xxs + 2)
                            .background(ProviderColors.ollama)
                            .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous))
                    }
                    .padding(VaizorSpacing.md)
                    .background(ProviderColors.ollama.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous)
                            .stroke(ProviderColors.ollama.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }
        }
        .onboardingPageAnimation(reduceMotion: reduceMotion)
    }

    // MARK: - Security Page

    private var securityPage: some View {
        VStack(spacing: 28) {
            // Shield icon with animation
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 12) {
                Text("Security First")
                    .font(VaizorTypography.displayLarge)
                    .foregroundStyle(textPrimary)

                Text("Your conversations are protected")
                    .font(.system(size: 16))
                    .foregroundStyle(textSecondary)
            }

            // Security features
            VStack(spacing: 16) {
                SecurityFeatureRow(
                    icon: "eye.slash",
                    title: "AiEDR Protection",
                    description: "Advanced threat detection for AI interactions"
                )

                SecurityFeatureRow(
                    icon: "lock.doc",
                    title: "Secret Detection",
                    description: "Automatically redacts API keys and passwords"
                )

                SecurityFeatureRow(
                    icon: "externaldrive.badge.shield",
                    title: "Local Storage",
                    description: "Your data stays on your device"
                )

                SecurityFeatureRow(
                    icon: "checkmark.shield",
                    title: "Sandboxed Execution",
                    description: "Code runs in isolated environments"
                )
            }
            .padding(.horizontal, 20)
        }
        .onboardingPageAnimation(reduceMotion: reduceMotion)
    }

    // MARK: - Ready Page

    private var readyPage: some View {
        VStack(spacing: 28) {
            // Checkmark animation
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(VaizorTypography.displayLarge)
                    .foregroundStyle(textPrimary)

                Text("Start chatting with your AI assistant")
                    .font(.system(size: 16))
                    .foregroundStyle(textSecondary)
            }

            // Quick tips
            VStack(spacing: 12) {
                Text("Quick Tips")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textSecondary)

                VStack(alignment: .leading, spacing: 10) {
                    QuickTipRow(shortcut: "N", description: "Start a new chat")
                    QuickTipRow(shortcut: "/", description: "Open slash commands")
                    QuickTipRow(shortcut: "@", description: "Mention files or folders")
                    QuickTipRow(shortcut: ",", description: "Open settings")
                }
                .padding(16)
                .background(darkSurface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(darkBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
        }
        .onboardingPageAnimation(reduceMotion: reduceMotion)
    }

    // MARK: - Bottom Navigation

    private var bottomNavigation: some View {
        VStack(spacing: 24) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(OnboardingPage.allCases, id: \.rawValue) { page in
                    Circle()
                        .fill(page == currentPage ? accent : darkBorder)
                        .frame(width: page == currentPage ? 10 : 8, height: page == currentPage ? 10 : 8)
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }

            // Navigation buttons
            HStack(spacing: 16) {
                if currentPage != .welcome {
                    Button("Back") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if let prev = OnboardingPage(rawValue: currentPage.rawValue - 1) {
                                currentPage = prev
                            }
                        }
                    }
                    .buttonStyle(OnboardingSecondaryButtonStyle())
                }

                Spacer()

                if currentPage == .ready {
                    Button("Start Chatting") {
                        guard !isCompleting else { return }
                        isCompleting = true
                        completeOnboarding()
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .disabled(isCompleting)
                } else {
                    Button("Continue") {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if let next = OnboardingPage(rawValue: currentPage.rawValue + 1) {
                                currentPage = next
                            }
                        }
                    }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 40)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func completeOnboarding() {
        // Defensive: Always set the flag, even if already set
        // Use both UserDefaults and the binding to ensure consistency
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Force synchronous write to disk
        UserDefaults.standard.synchronize()

        // Stop background animations to prevent any interference with dismissal
        animateBackground = false

        // Dismiss with explicit transaction to disable animations
        // This prevents any ongoing animations from blocking the dismissal
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isPresented = false
        }

        // Fallback: If sheet doesn't dismiss within a short time, force it
        // This handles edge cases where SwiftUI sheet state gets stuck
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.isPresented {
                // Still showing - force dismiss again with no animation
                var retryTransaction = Transaction()
                retryTransaction.disablesAnimations = true
                withTransaction(retryTransaction) {
                    self.isPresented = false
                }
            }
        }

        // Final fallback after longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.isPresented {
                // Something is very wrong - try one more time
                self.isPresented = false
            }
        }
    }
}

// MARK: - AI Provider

enum AIProvider: String, CaseIterable {
    case claude = "Claude"
    case openai = "OpenAI"
    case gemini = "Gemini"
    case ollama = "Ollama"

    var icon: String {
        switch self {
        case .claude: return "c.circle.fill"
        case .openai: return "sparkle"
        case .gemini: return "diamond.fill"
        case .ollama: return "cpu.fill"
        }
    }

    var description: String {
        switch self {
        case .claude: return "Anthropic's Claude - Advanced reasoning"
        case .openai: return "GPT-4 and GPT-4 Turbo models"
        case .gemini: return "Google's multimodal AI"
        case .ollama: return "Free local models - No API key"
        }
    }

    var color: Color {
        switch self {
        case .claude: return ProviderColors.claude
        case .openai: return ProviderColors.openai
        case .gemini: return ProviderColors.gemini
        case .ollama: return ProviderColors.ollama
        }
    }
}

// MARK: - Supporting Views

struct OnboardingAppIcon: View {
    @State private var glowPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Glow effect
            if !reduceMotion {
                Circle()
                    .fill(ThemeColors.accent.opacity(glowPulse ? 0.3 : 0.15))
                    .frame(width: 140, height: 140)
                    .blur(radius: 30)
            }

            // Icon background
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [ThemeColors.accent, ThemeColors.accent.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: ThemeColors.accent.opacity(0.3), radius: 20, x: 0, y: 10)

            // Icon symbol
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.white)
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }
        }
    }
}

struct WelcomeFeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(ThemeColors.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ThemeColors.darkSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(ThemeColors.darkBorder, lineWidth: 1)
        )
    }
}

struct ProviderCard: View {
    let provider: AIProvider
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Provider icon
                ZStack {
                    Circle()
                        .fill(provider.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: provider.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(provider.color)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.rawValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)

                    Text(provider.description)
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeColors.textSecondary)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? ThemeColors.accent : ThemeColors.darkBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(ThemeColors.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? ThemeColors.accent.opacity(0.1) : (isHovered ? ThemeColors.darkElevated : ThemeColors.darkSurface))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? ThemeColors.accent.opacity(0.5) : ThemeColors.darkBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(isHovered ? ThemeColors.darkElevated : ThemeColors.darkSurface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColors.darkBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SecurityFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ThemeColors.accent.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(ThemeColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ThemeColors.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(ThemeColors.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(ThemeColors.darkSurface)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(ThemeColors.darkBorder, lineWidth: 1)
        )
    }
}

struct QuickTipRow: View {
    let shortcut: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Text("\u{2318}")
                    .font(.system(size: 12))
                Text(shortcut)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(ThemeColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(ThemeColors.darkBase)
            .cornerRadius(6)

            Text(description)
                .font(.system(size: 13))
                .foregroundStyle(ThemeColors.textPrimary)

            Spacer()
        }
    }
}

// MARK: - Particle Emitter

struct ParticleEmitterView: View {
    @State private var particles: [Particle] = []
    @State private var timer: Timer?
    @State private var hasInitialized = false

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var speed: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(ThemeColors.accent.opacity(particle.opacity))
                        .frame(width: 4 * particle.scale, height: 4 * particle.scale)
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true

                // Generate initial particles
                for _ in 0..<30 {
                    particles.append(Particle(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height),
                        scale: CGFloat.random(in: 0.5...1.5),
                        opacity: Double.random(in: 0.2...0.6),
                        speed: Double.random(in: 0.5...2)
                    ))
                }

                // Animate particles with stored timer reference
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
                    for i in particles.indices {
                        particles[i].y -= CGFloat(particles[i].speed)
                        if particles[i].y < 0 {
                            particles[i].y = geometry.size.height
                            particles[i].x = CGFloat.random(in: 0...geometry.size.width)
                        }
                    }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
        }
    }
}

// MARK: - Button Styles

struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VaizorTypography.buttonLarge)
            .foregroundStyle(.white)
            .padding(.horizontal, VaizorSpacing.xl)
            .padding(.vertical, VaizorSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusLg, style: .continuous)
                    .fill(ThemeColors.accent)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct OnboardingSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VaizorTypography.label)
            .foregroundStyle(ThemeColors.textSecondary)
            .padding(.horizontal, VaizorSpacing.lg - 4)
            .padding(.vertical, VaizorSpacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous)
                    .fill(ThemeColors.darkSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: VaizorSpacing.radiusMd, style: .continuous)
                            .stroke(ThemeColors.darkBorder, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - View Extensions

extension View {
    func onboardingPageAnimation(reduceMotion: Bool) -> some View {
        self
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: reduceMotion)
    }

    func staggeredAnimation(index: Int, reduceMotion: Bool) -> some View {
        self
            .opacity(1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.1),
                value: index
            )
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(isPresented: .constant(true))
        .frame(width: 900, height: 700)
}
