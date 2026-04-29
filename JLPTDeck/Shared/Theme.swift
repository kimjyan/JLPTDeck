import SwiftUI

/// Design tokens from Claude Design JLPTDeck handoff.
/// Warm paper-like palette with muted semantic colors.
enum Theme {
    // MARK: - Background (paper / ink)
    static let bg = Color(light: .init(hex: 0xF6F4EF), dark: .init(hex: 0x15141A))
    static let surface = Color(light: .init(hex: 0xFBFAF6), dark: .init(hex: 0x1F1E25))
    static let surface2 = Color(light: .init(hex: 0xEDEAE2), dark: .init(hex: 0x2A2932))

    // MARK: - Text
    static let text = Color(light: .init(hex: 0x1F1D24), dark: .init(hex: 0xF2F0EA))
    static let secondary = Color(light: .init(hex: 0x3C3746).opacity(0.58), dark: .init(hex: 0xE8E5DD).opacity(0.60))
    static let tertiary = Color(light: .init(hex: 0x3C3746).opacity(0.30), dark: .init(hex: 0xE8E5DD).opacity(0.32))

    // MARK: - Accent (clay/terracotta — warm, fits paper bg)
    static let accent = Color(light: .init(hex: 0xB86A4D), dark: .init(hex: 0xD98A6A))

    // MARK: - Semantic
    static let red = Color(light: .init(hex: 0xC9554F), dark: .init(hex: 0xE88A8A))
    static let green = Color(light: .init(hex: 0x4FA875), dark: .init(hex: 0x7FC998))
    static let orange = Color(light: .init(hex: 0xC97D3F), dark: .init(hex: 0xE8A971))
    static let redFill = Color(light: .init(hex: 0xC9554F).opacity(0.82), dark: .init(hex: 0xC9554F).opacity(0.78))
    static let greenFill = Color(light: .init(hex: 0x4FA875).opacity(0.82), dark: .init(hex: 0x4FA875).opacity(0.78))
    static let redChipBg = Color(light: .init(hex: 0xC9554F).opacity(0.10), dark: .init(hex: 0xE88A8A).opacity(0.16))

    // MARK: - Separator
    static let separator = Color(light: .init(hex: 0x3C3746).opacity(0.12), dark: .init(hex: 0x78768C).opacity(0.30))

    // MARK: - Tab bar
    static let tabBarBg = Color(light: .init(hex: 0xFBFAF6).opacity(0.88), dark: .init(hex: 0x1F1E25).opacity(0.88))

    // MARK: - Radii
    static let cardRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 14

    // MARK: - Typography
    static let kanjiSize: CGFloat = 80
    static let readingSize: CGFloat = 20
    static let choiceSize: CGFloat = 20
}

// MARK: - Hex Color Helper

extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
