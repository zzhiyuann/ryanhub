import SwiftUI

// MARK: - Colors

extension Color {
    /// Primary background: dark #0A0A0F / light #F5F5F7
    static var cortexBackground: Color {
        Color("cortexBackground")
    }

    /// Surface (cards, elevated): dark #1C1C2E / light #FFFFFF
    static var cortexSurface: Color {
        Color("cortexSurface")
    }

    /// Secondary surface: dark #252540 / light #F0F0F2
    static var cortexSurfaceSecondary: Color {
        Color("cortexSurfaceSecondary")
    }

    /// Primary accent: #6366F1 (indigo, both modes)
    static let cortexPrimary = Color(red: 0x63 / 255.0, green: 0x66 / 255.0, blue: 0xF1 / 255.0)

    /// Primary light variant: #818CF8
    static let cortexPrimaryLight = Color(red: 0x81 / 255.0, green: 0x8C / 255.0, blue: 0xF8 / 255.0)

    /// Primary text: dark white / light #1A1A1A
    static var cortexTextPrimary: Color {
        Color("cortexTextPrimary")
    }

    /// Secondary text: dark #9CA3AF / light #6B7280
    static var cortexTextSecondary: Color {
        Color("cortexTextSecondary")
    }

    /// Accent green: #22C55E
    static let cortexAccentGreen = Color(red: 0x22 / 255.0, green: 0xC5 / 255.0, blue: 0x5E / 255.0)

    /// Accent red: #EF4444
    static let cortexAccentRed = Color(red: 0xEF / 255.0, green: 0x44 / 255.0, blue: 0x44 / 255.0)

    /// Accent yellow: #F59E0B
    static let cortexAccentYellow = Color(red: 0xF5 / 255.0, green: 0x9E / 255.0, blue: 0x0B / 255.0)

    /// Border: dark white.opacity(0.08) / light black.opacity(0.06)
    static var cortexBorder: Color {
        Color("cortexBorder")
    }
}

// MARK: - Adaptive Color Helpers

/// Provides adaptive colors that respond to color scheme changes without asset catalogs.
/// Use these in conjunction with the Color extensions above.
struct AdaptiveColors {
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0x0A / 255.0, green: 0x0A / 255.0, blue: 0x0F / 255.0)
            : Color(red: 0xF5 / 255.0, green: 0xF5 / 255.0, blue: 0xF7 / 255.0)
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x2E / 255.0)
            : Color.white
    }

    static func surfaceSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0x25 / 255.0, green: 0x25 / 255.0, blue: 0x40 / 255.0)
            : Color(red: 0xF0 / 255.0, green: 0xF0 / 255.0, blue: 0xF2 / 255.0)
    }

    static func textPrimary(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? .white
            : Color(red: 0x1A / 255.0, green: 0x1A / 255.0, blue: 0x1A / 255.0)
    }

    static func textSecondary(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0x9C / 255.0, green: 0xA3 / 255.0, blue: 0xAF / 255.0)
            : Color(red: 0x6B / 255.0, green: 0x72 / 255.0, blue: 0x80 / 255.0)
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
}

// MARK: - Typography

extension Font {
    /// 28pt bold — page titles
    static let cortexTitle: Font = .system(size: 28, weight: .bold)
    /// 20pt semibold — section headings
    static let cortexHeading: Font = .system(size: 20, weight: .semibold)
    /// 16pt regular — body text
    static let cortexBody: Font = .system(size: 16, weight: .regular)
    /// 13pt medium — captions, labels
    static let cortexCaption: Font = .system(size: 13, weight: .medium)
}

// MARK: - Layout Constants

enum CortexLayout {
    static let standardPadding: CGFloat = 16
    static let cardInnerPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let itemSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 12
    static let inputCornerRadius: CGFloat = 12
    static let buttonHeight: CGFloat = 48
}
