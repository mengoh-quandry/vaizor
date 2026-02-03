import SwiftUI

/// Centralized spacing system for consistent layout across Vaizor
/// Based on an 8px grid system with smaller values for fine-tuning
enum VaizorSpacing {
    /// 2pt - Minimal spacing for tight elements
    static let xxxs: CGFloat = 2

    /// 4pt - Very small spacing
    static let xxs: CGFloat = 4

    /// 8pt - Small spacing (base unit)
    static let xs: CGFloat = 8

    /// 12pt - Medium-small spacing
    static let sm: CGFloat = 12

    /// 16pt - Medium spacing (common padding)
    static let md: CGFloat = 16

    /// 24pt - Large spacing
    static let lg: CGFloat = 24

    /// 32pt - Extra large spacing
    static let xl: CGFloat = 32

    /// 48pt - Very large spacing
    static let xxl: CGFloat = 48

    /// 64pt - Maximum spacing
    static let xxxl: CGFloat = 64
}

// MARK: - Component-Specific Spacing

extension VaizorSpacing {
    /// Card internal padding
    static let cardPadding: CGFloat = md

    /// Card internal padding (compact)
    static let cardPaddingCompact: CGFloat = sm

    /// Section spacing in lists/forms
    static let sectionSpacing: CGFloat = lg

    /// Item spacing in lists
    static let listItemSpacing: CGFloat = xs

    /// Button internal padding (horizontal)
    static let buttonPaddingH: CGFloat = sm

    /// Button internal padding (vertical)
    static let buttonPaddingV: CGFloat = xs

    /// Input field padding
    static let inputPadding: CGFloat = sm

    /// Icon spacing from text
    static let iconSpacing: CGFloat = xs

    /// Avatar size (standard)
    static let avatarSize: CGFloat = xl

    /// Avatar size (small)
    static let avatarSizeSmall: CGFloat = lg

    /// Corner radius (small)
    static let radiusSm: CGFloat = 6

    /// Corner radius (medium)
    static let radiusMd: CGFloat = 8

    /// Corner radius (large)
    static let radiusLg: CGFloat = 12

    /// Corner radius (extra large)
    static let radiusXl: CGFloat = 16

    /// Message bubble corner radius
    static let bubbleRadius: CGFloat = radiusXl

    // MARK: - Modal/Window Sizes

    /// Standardized modal sizes for consistent window dimensions
    enum ModalSize {
        case small      // 400×300 - Simple dialogs
        case medium     // 550×450 - Settings panels
        case large      // 700×550 - Complex settings, project settings
        case xlarge     // 900×700 - Onboarding, major features
        case browser    // 1000×700 - Browser panels
        case custom(width: CGFloat, height: CGFloat)

        var size: CGSize {
            switch self {
            case .small:
                return CGSize(width: 400, height: 300)
            case .medium:
                return CGSize(width: 550, height: 450)
            case .large:
                return CGSize(width: 700, height: 550)
            case .xlarge:
                return CGSize(width: 900, height: 700)
            case .browser:
                return CGSize(width: 1000, height: 700)
            case .custom(let width, let height):
                return CGSize(width: width, height: height)
            }
        }

        var width: CGFloat { size.width }
        var height: CGFloat { size.height }
    }

    // MARK: - Minimum Touch Target

    /// Minimum touch/click target size per accessibility guidelines (44pt)
    static let minTouchTarget: CGFloat = 44
}

// MARK: - View Extensions for Spacing

extension View {
    /// Apply standard card padding
    func cardPadding() -> some View {
        self.padding(VaizorSpacing.cardPadding)
    }

    /// Apply compact card padding
    func cardPaddingCompact() -> some View {
        self.padding(VaizorSpacing.cardPaddingCompact)
    }

    /// Apply standard section padding
    func sectionPadding() -> some View {
        self.padding(.vertical, VaizorSpacing.sectionSpacing)
    }

    /// Apply standard horizontal page margin
    func pageMargin() -> some View {
        self.padding(.horizontal, VaizorSpacing.lg)
    }

    /// Apply standard corner radius
    func standardCornerRadius() -> some View {
        self.cornerRadius(VaizorSpacing.radiusMd)
    }

    /// Apply large corner radius
    func largeCornerRadius() -> some View {
        self.cornerRadius(VaizorSpacing.radiusLg)
    }
}

// MARK: - EdgeInsets Helpers

extension EdgeInsets {
    /// Standard card insets
    static var card: EdgeInsets {
        EdgeInsets(
            top: VaizorSpacing.cardPadding,
            leading: VaizorSpacing.cardPadding,
            bottom: VaizorSpacing.cardPadding,
            trailing: VaizorSpacing.cardPadding
        )
    }

    /// Compact card insets
    static var cardCompact: EdgeInsets {
        EdgeInsets(
            top: VaizorSpacing.cardPaddingCompact,
            leading: VaizorSpacing.cardPaddingCompact,
            bottom: VaizorSpacing.cardPaddingCompact,
            trailing: VaizorSpacing.cardPaddingCompact
        )
    }

    /// Input field insets
    static var input: EdgeInsets {
        EdgeInsets(
            top: VaizorSpacing.inputPadding,
            leading: VaizorSpacing.inputPadding,
            bottom: VaizorSpacing.inputPadding,
            trailing: VaizorSpacing.inputPadding
        )
    }

    /// Button insets
    static var button: EdgeInsets {
        EdgeInsets(
            top: VaizorSpacing.buttonPaddingV,
            leading: VaizorSpacing.buttonPaddingH,
            bottom: VaizorSpacing.buttonPaddingV,
            trailing: VaizorSpacing.buttonPaddingH
        )
    }
}
