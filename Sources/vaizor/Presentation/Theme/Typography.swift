import SwiftUI

/// Centralized typography system for consistent text styling across Vaizor
/// Following Apple Human Interface Guidelines for macOS
enum VaizorTypography {
    // MARK: - Hero Display (for onboarding, empty states)
    static let displayHero = Font.system(size: 48, weight: .bold)
    static let displayHeroLight = Font.system(size: 48, weight: .light)
    static let displayXLarge = Font.system(size: 42, weight: .bold)

    // MARK: - Display
    static let displayLarge = Font.system(size: 32, weight: .bold, design: .default)
    static let displayMedium = Font.system(size: 28, weight: .semibold, design: .default)

    // MARK: - Headings
    static let h1 = Font.system(size: 24, weight: .semibold, design: .default)
    static let h2 = Font.system(size: 20, weight: .semibold, design: .default)
    static let h3 = Font.system(size: 17, weight: .medium, design: .default)

    // MARK: - Body
    static let bodyLarge = Font.system(size: 15, weight: .regular, design: .default)
    static let body = Font.system(size: 14, weight: .regular, design: .default)
    static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - UI
    static let label = Font.system(size: 12, weight: .medium, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let tiny = Font.system(size: 10, weight: .medium, design: .default)

    // MARK: - Code
    static let code = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let codeSmall = Font.system(size: 12, weight: .regular, design: .monospaced)

    // MARK: - Rounded variants (DEPRECATED - not native to macOS)
    // These are kept for backwards compatibility but should be migrated to standard fonts
    @available(*, deprecated, message: "Use standard fonts instead - rounded fonts are not native to macOS")
    static let displayLargeRounded = Font.system(size: 32, weight: .bold, design: .default)
    @available(*, deprecated, message: "Use standard fonts instead - rounded fonts are not native to macOS")
    static let displayMediumRounded = Font.system(size: 28, weight: .semibold, design: .default)
    @available(*, deprecated, message: "Use standard fonts instead - rounded fonts are not native to macOS")
    static let h1Rounded = Font.system(size: 24, weight: .semibold, design: .default)
    @available(*, deprecated, message: "Use standard fonts instead - rounded fonts are not native to macOS")
    static let h2Rounded = Font.system(size: 20, weight: .bold, design: .default)
    @available(*, deprecated, message: "Use standard fonts instead - rounded fonts are not native to macOS")
    static let h3Rounded = Font.system(size: 17, weight: .semibold, design: .default)

    // MARK: - Button Text
    static let buttonSmall = Font.system(size: 12, weight: .medium)
    static let buttonMedium = Font.system(size: 13, weight: .semibold)
    static let buttonLarge = Font.system(size: 15, weight: .semibold)
}

// MARK: - Line Height Constants

enum VaizorLineHeight {
    /// Tight line height for headings (1.2x)
    static let tight: CGFloat = 0.2

    /// Normal line height for body text (1.5x)
    static let normal: CGFloat = 0.5

    /// Relaxed line height for reading (1.7x)
    static let relaxed: CGFloat = 0.7

    /// Compact line height for UI elements (1.1x)
    static let compact: CGFloat = 0.1
}

// MARK: - View Extensions for Typography

extension View {
    /// Apply heading typography with tight line spacing
    func headingStyle(_ font: Font = VaizorTypography.h2) -> some View {
        self
            .font(font)
            .lineSpacing(VaizorLineHeight.tight)
    }

    /// Apply body typography with normal line spacing for readability
    func bodyStyle(_ font: Font = VaizorTypography.body) -> some View {
        self
            .font(font)
            .lineSpacing(VaizorLineHeight.normal)
    }

    /// Apply caption/label typography with compact line spacing
    func captionStyle(_ font: Font = VaizorTypography.caption) -> some View {
        self
            .font(font)
            .lineSpacing(VaizorLineHeight.compact)
    }

    /// Apply code typography
    func codeStyle(_ font: Font = VaizorTypography.code) -> some View {
        self
            .font(font)
            .lineSpacing(VaizorLineHeight.compact)
    }
}
