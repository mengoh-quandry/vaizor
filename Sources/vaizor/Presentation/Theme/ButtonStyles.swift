import SwiftUI

// MARK: - Unified Button System for macOS Tahoe
// Following Apple Human Interface Guidelines
// All buttons include: focus rings, hover states, press animations, reduce motion support

// MARK: - Button Size System

enum VaizorButtonSize {
    case small      // 28pt min height, 12pt font
    case medium     // 32pt min height, 13pt font (default)
    case large      // 40pt min height, 15pt font

    var minHeight: CGFloat {
        switch self {
        case .small: return 28
        case .medium: return 32
        case .large: return 40
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .small: return VaizorSpacing.sm   // 12pt
        case .medium: return VaizorSpacing.md  // 16pt
        case .large: return VaizorSpacing.lg   // 24pt
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .small: return VaizorSpacing.xxs  // 4pt
        case .medium: return VaizorSpacing.xs  // 8pt
        case .large: return VaizorSpacing.sm   // 12pt
        }
    }

    var font: Font {
        switch self {
        case .small: return .system(size: 12, weight: .medium)
        case .medium: return .system(size: 13, weight: .semibold)
        case .large: return .system(size: 15, weight: .semibold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .small: return VaizorSpacing.radiusSm   // 6pt
        case .medium: return VaizorSpacing.radiusMd  // 8pt
        case .large: return VaizorSpacing.radiusLg   // 12pt
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 16
        case .large: return 20
        }
    }

    // Ensure minimum 44x44pt touch target for accessibility
    var touchTargetSize: CGFloat {
        return 44
    }
}

// MARK: - Button Variants

enum VaizorButtonVariant {
    case primary        // Filled accent
    case secondary      // Bordered
    case ghost          // Text only
    case destructive    // Red warning
    case icon           // Circular icon-only
}

// MARK: - Unified Button Style

struct VaizorButtonStyle: ButtonStyle {
    let variant: VaizorButtonVariant
    let size: VaizorButtonSize
    let isLoading: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    init(variant: VaizorButtonVariant = .primary, size: VaizorButtonSize = .medium, isLoading: Bool = false) {
        self.variant = variant
        self.size = size
        self.isLoading = isLoading
    }

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .font(size.font)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, variant == .icon ? 0 : size.horizontalPadding)
            .padding(.vertical, variant == .icon ? 0 : size.verticalPadding)
            .frame(minWidth: variant == .icon ? size.touchTargetSize : nil)
            .frame(minHeight: variant == .icon ? size.touchTargetSize : size.minHeight)
            .background(backgroundView(isPressed: isPressed))
            .clipShape(buttonShape)
            .overlay(borderOverlay(isPressed: isPressed))
            .overlay(focusRingOverlay)
            .scaleEffect(scaleEffect(isPressed: isPressed))
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(reduceMotion ? .none : VaizorAnimations.buttonPress, value: isPressed)
            .animation(reduceMotion ? .none : VaizorAnimations.colorTransition, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .focused($isFocused)
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Foreground Color

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return isHovered ? colors.textPrimary : colors.textSecondary
        case .ghost:
            return isHovered ? colors.textPrimary : colors.textSecondary
        case .destructive:
            return .white
        case .icon:
            return isHovered ? colors.textPrimary : colors.textSecondary
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func backgroundView(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(isPressed ? colors.accentDark : (isHovered ? colors.accentLight : colors.accent))
        case .secondary:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(isHovered ? colors.hoverBackground : Color.clear)
        case .ghost:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(isHovered ? colors.hoverBackground : Color.clear)
        case .destructive:
            RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                .fill(isPressed ? colors.error.opacity(0.8) : (isHovered ? colors.error.opacity(0.9) : colors.error))
        case .icon:
            Circle()
                .fill(isHovered ? colors.hoverBackground : Color.clear)
        }
    }

    // MARK: - Border

    @ViewBuilder
    private func borderOverlay(isPressed: Bool) -> some View {
        switch variant {
        case .primary:
            EmptyView()
        case .secondary:
            buttonShape
                .stroke(colors.border, lineWidth: 1)
        case .ghost:
            EmptyView()
        case .destructive:
            EmptyView()
        case .icon:
            EmptyView()
        }
    }

    // MARK: - Focus Ring (CRITICAL - Previously Missing)

    @ViewBuilder
    private var focusRingOverlay: some View {
        if isFocused {
            buttonShape
                .stroke(colors.accent, lineWidth: 2)
                .padding(-4) // Offset outward
                .shadow(color: colors.accent.opacity(0.4), radius: 4, x: 0, y: 0)
        }
    }

    // MARK: - Button Shape

    private var buttonShape: some Shape {
        if variant == .icon {
            return AnyShape(Circle())
        } else {
            return AnyShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
        }
    }

    // MARK: - Scale Effect

    private func scaleEffect(isPressed: Bool) -> CGFloat {
        guard !reduceMotion else { return 1.0 }
        return isPressed ? 0.97 : 1.0
    }
}

// MARK: - Type-Erased Shape Helper

struct AnyShape: Shape {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Convenience Initializers

extension VaizorButtonStyle {
    /// Primary filled button (default)
    static var primary: VaizorButtonStyle {
        VaizorButtonStyle(variant: .primary)
    }

    /// Secondary bordered button
    static var secondary: VaizorButtonStyle {
        VaizorButtonStyle(variant: .secondary)
    }

    /// Ghost text-only button
    static var ghost: VaizorButtonStyle {
        VaizorButtonStyle(variant: .ghost)
    }

    /// Destructive red button
    static var destructive: VaizorButtonStyle {
        VaizorButtonStyle(variant: .destructive)
    }

    /// Icon-only circular button
    static var icon: VaizorButtonStyle {
        VaizorButtonStyle(variant: .icon)
    }

    /// Small primary button
    static var smallPrimary: VaizorButtonStyle {
        VaizorButtonStyle(variant: .primary, size: .small)
    }

    /// Large primary button
    static var largePrimary: VaizorButtonStyle {
        VaizorButtonStyle(variant: .primary, size: .large)
    }
}

// MARK: - Icon Button Style (Specialized)

/// Specialized style for icon-only buttons with proper hit target
struct VaizorIconButtonStyle: ButtonStyle {
    let size: VaizorButtonSize
    let isActive: Bool
    let activeColor: Color?

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    init(size: VaizorButtonSize = .medium, isActive: Bool = false, activeColor: Color? = nil) {
        self.size = size
        self.isActive = isActive
        self.activeColor = activeColor
    }

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        configuration.label
            .font(.system(size: size.iconSize, weight: .medium))
            .foregroundStyle(iconColor)
            .frame(width: size.touchTargetSize, height: size.touchTargetSize)
            .background(
                Circle()
                    .fill(isHovered ? colors.hoverBackground : Color.clear)
            )
            .overlay(focusRingOverlay)
            .scaleEffect(scaleEffect(isPressed: isPressed))
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(reduceMotion ? .none : VaizorAnimations.buttonPress, value: isPressed)
            .animation(reduceMotion ? .none : VaizorAnimations.colorTransition, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .focused($isFocused)
            .accessibilityAddTraits(.isButton)
    }

    private var iconColor: Color {
        if isActive {
            return activeColor ?? colors.accent
        }
        return isHovered ? colors.textPrimary : colors.textSecondary
    }

    @ViewBuilder
    private var focusRingOverlay: some View {
        if isFocused {
            Circle()
                .stroke(colors.accent, lineWidth: 2)
                .padding(-4)
                .shadow(color: colors.accent.opacity(0.4), radius: 4, x: 0, y: 0)
        }
    }

    private func scaleEffect(isPressed: Bool) -> CGFloat {
        guard !reduceMotion else { return 1.0 }
        return isPressed ? 0.92 : 1.0
    }
}

// MARK: - View Extensions

extension View {
    /// Apply the unified Vaizor button style
    func vaizorButtonStyle(_ variant: VaizorButtonVariant = .primary, size: VaizorButtonSize = .medium) -> some View {
        self.buttonStyle(VaizorButtonStyle(variant: variant, size: size))
    }

    /// Apply icon button style
    func vaizorIconButtonStyle(size: VaizorButtonSize = .medium, isActive: Bool = false, activeColor: Color? = nil) -> some View {
        self.buttonStyle(VaizorIconButtonStyle(size: size, isActive: isActive, activeColor: activeColor))
    }
}

// MARK: - Toolbar Button Style

/// Specialized style for toolbar buttons (smaller, no visible background until hover)
struct VaizorToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isHovered ? colors.textPrimary : colors.textSecondary)
            .padding(.horizontal, VaizorSpacing.xs)
            .padding(.vertical, VaizorSpacing.xxs)
            .frame(minHeight: 28)
            .background(
                RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous)
                    .fill(isHovered ? colors.hoverBackground : Color.clear)
            )
            .overlay(focusRingOverlay)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .animation(reduceMotion ? .none : VaizorAnimations.buttonPress, value: configuration.isPressed)
            .animation(reduceMotion ? .none : VaizorAnimations.colorTransition, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .focused($isFocused)
    }

    @ViewBuilder
    private var focusRingOverlay: some View {
        if isFocused {
            RoundedRectangle(cornerRadius: VaizorSpacing.radiusSm, style: .continuous)
                .stroke(colors.accent, lineWidth: 2)
                .padding(-2)
        }
    }
}

// MARK: - Send Button Style

/// Specialized style for the chat send button
struct VaizorSendButtonStyle: ButtonStyle {
    let isStreaming: Bool
    let isEmpty: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    private var colors: AdaptiveColors {
        AdaptiveColors(colorScheme: colorScheme)
    }

    private var isInteractive: Bool {
        !isEmpty || isStreaming
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(focusRingOverlay)
            .scaleEffect(scaleEffect(isPressed: configuration.isPressed))
            .opacity(isInteractive ? 1.0 : 0.4)
            .animation(reduceMotion ? .none : VaizorAnimations.buttonPress, value: configuration.isPressed)
            .animation(reduceMotion ? .none : VaizorAnimations.colorTransition, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
            .focused($isFocused)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isStreaming {
            return colors.error
        }
        if isPressed {
            return colors.accentDark
        }
        if isHovered && isInteractive {
            return colors.accentLight
        }
        return colors.accent
    }

    @ViewBuilder
    private var focusRingOverlay: some View {
        if isFocused {
            Circle()
                .stroke(colors.accent, lineWidth: 2)
                .padding(-4)
                .shadow(color: colors.accent.opacity(0.4), radius: 4, x: 0, y: 0)
        }
    }

    private func scaleEffect(isPressed: Bool) -> CGFloat {
        guard !reduceMotion, isInteractive else { return 1.0 }
        return isPressed ? 0.92 : 1.0
    }
}
