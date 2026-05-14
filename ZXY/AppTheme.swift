//
//  AppTheme.swift
//
//  Created by Harsh Kumar on 29/03/26.
//
//  ─────────────────────────────────────────────────────────────────
//  USAGE CHEATSHEET  (Apple TV-style dark theme, white UI elements)
//
//  Backgrounds  (very dark)
//    AppTheme.Colors.background          ← true black canvas   #080808
//    AppTheme.Colors.backgroundSecondary ← elevated dark       #111111
//    AppTheme.Colors.backgroundTertiary  ← card / sheet bg     #1C1C1E
//    AppTheme.Colors.surface             ← input / control bg  white 8%
//    AppTheme.Colors.surfaceHovered      ← hovered control     white 12%
//
//  White / Light UI Elements
//    AppTheme.Colors.elementWhite        ← pure white
//    AppTheme.Colors.elementSubtle       ← white 60% – secondary labels
//    AppTheme.Colors.elementMuted        ← white 35% – tertiary labels
//    AppTheme.Colors.elementPlaceholder  ← white 22% – placeholder text
//    AppTheme.Colors.elementDim          ← white 10% – hairline dividers
//
//  Brand Accent  (used sparingly – buttons, links, focus rings)
//    AppTheme.Colors.accent              ← pure white (ATV style)
//    AppTheme.Colors.accentBlue          ← #3B82F6 – optional tint
//
//  Borders
//    AppTheme.Colors.border              ← white 12% – default field border
//    AppTheme.Colors.borderFocused       ← white 70% – focused field border
//    AppTheme.Colors.borderStrong        ← white 25% – cards / sections
//    AppTheme.Colors.divider             ← white 8%  – section dividers
//
//  Semantic / Status
//    AppTheme.Colors.success / error / warning / info
//
//  Shadows
//    AppTheme.Shadows.card               ← black 40%
//    AppTheme.Shadows.deep               ← black 65%
//    AppTheme.Shadows.accent             ← white  8% glow
//
//  Radius / Spacing / Typography   – same API as before
//  ─────────────────────────────────────────────────────────────────

import SwiftUI


enum AppTheme {

    enum Colors {

        // ── Canvas / Backgrounds ───────────────────────────────────
        /// True black – main screen canvas (Apple TV style)
        static let background           = Color(hex: "#080808")
        /// Slightly lifted dark – navigation bars, tab bars
        static let backgroundSecondary  = Color(hex: "#111111")
        /// Card / sheet / popover background
        static let backgroundTertiary   = Color(hex: "#1C1C1E")

        // ── Surface (UI element fills – white glass) ───────────────
        /// Input field, chip, control surface
        static let surface              = Color.white.opacity(0.08)
        /// Hovered/active surface state
        static let surfaceHovered       = Color.white.opacity(0.13)
        /// Pressed surface state
        static let surfacePressed       = Color.white.opacity(0.05)

        // ── White / Light UI Elements ──────────────────────────────
        /// Pure white – primary labels, icons, button text
        static let elementWhite         = Color.white
        /// White 60% – secondary labels, subtitles
        static let elementSubtle        = Color.white.opacity(0.60)
        /// White 35% – tertiary / supporting labels
        static let elementMuted         = Color.white.opacity(0.35)
        /// White 22% – placeholder text
        static let elementPlaceholder   = Color.white.opacity(0.22)
        /// White 10% – fine hairlines, dim fills
        static let elementDim           = Color.white.opacity(0.10)

        // ── Accent ─────────────────────────────────────────────────
        /// Primary CTA accent – white (full Apple TV style)
        static let accent               = Color.white
        /// Optional blue tint accent (like tvOS focus ring)
        static let accentBlue           = Color(hex: "#3B82F6")

        // ── Borders ────────────────────────────────────────────────
        /// Default field / card border
        static let border               = Color.white.opacity(0.12)
        /// Focused field border – bright white
        static let borderFocused        = Color.white.opacity(0.70)
        /// Stronger card / sheet border
        static let borderStrong         = Color.white.opacity(0.25)
        /// Divider between sections
        static let divider              = Color.white.opacity(0.08)

        // ── Primary Button ─────────────────────────────────────────
        /// White fill – primary button background
        static let buttonPrimary        = Color.white
        /// Dark text on white button
        static let buttonPrimaryLabel   = Color(hex: "#080808")
        /// Subtle white-glass secondary button
        static let buttonSecondary      = Color.white.opacity(0.10)
        /// White text on secondary button
        static let buttonSecondaryLabel = Color.white

        // ── Semantic / Status ──────────────────────────────────────
        static let success              = Color(hex: "#34D399")
        static let successSurface       = Color.white.opacity(0.06)
        static let warning              = Color(hex: "#FBBF24")
        static let warningSurface       = Color.white.opacity(0.06)
        static let error                = Color(hex: "#F87171")
        static let errorSurface         = Color.white.opacity(0.06)
        static let info                 = Color(hex: "#60A5FA")
        static let infoSurface          = Color.white.opacity(0.06)
    }

    enum Gradients {
        /// Subtle dark gradient for the main background
        static let background = LinearGradient(
            colors: [Color(hex: "#0A0A0A"), Color(hex: "#080808")],
            startPoint: .top,
            endPoint: .bottom
        )
        /// White button gradient (very gentle sheen)
        static let primaryButton = LinearGradient(
            colors: [Color.white, Color(hex: "#D4D4D4")],
            startPoint: .top,
            endPoint: .bottom
        )
        /// Crisp white → off-white for elevated cards
        static let surfaceCard = LinearGradient(
            colors: [Color.white.opacity(0.10), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        /// Accent blue glow – optional highlight
        static let accentGlow = LinearGradient(
            colors: [Color(hex: "#60A5FA"), Color(hex: "#3B82F6")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    enum Shadows {
        /// Soft card shadow
        static let card   = Color.black.opacity(0.40)
        /// Deep modal / sheet shadow
        static let deep   = Color.black.opacity(0.65)
        /// Subtle white glow on focused elements
        static let accent = Color.white.opacity(0.1)
        /// Error glow
        static let error  = Color(hex: "#F87171").opacity(0.25)
    }

    enum Radius {
        static let xs:   CGFloat = 6
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 14
        static let lg:   CGFloat = 18
        static let xl:   CGFloat = 24
        static let xxl:  CGFloat = 32
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Typography {
        static let displayLarge  = Font.system(size: 36, weight: .bold,     design: .default)
        static let displayMedium = Font.system(size: 28, weight: .bold,     design: .default)
        static let headingLarge  = Font.system(size: 24, weight: .bold,     design: .default)
        static let headingMedium = Font.system(size: 20, weight: .semibold, design: .default)
        static let headingSmall  = Font.system(size: 17, weight: .semibold, design: .default)
        static let bodyLarge     = Font.system(size: 16, weight: .regular,  design: .default)
        static let bodyMedium    = Font.system(size: 14, weight: .regular,  design: .default)
        static let bodySmall     = Font.system(size: 13, weight: .regular,  design: .default)
        static let labelLarge    = Font.system(size: 15, weight: .semibold, design: .default)
        static let labelMedium   = Font.system(size: 13, weight: .semibold, design: .default)
        static let labelSmall    = Font.system(size: 11, weight: .semibold, design: .default)
        static let caption       = Font.system(size: 11, weight: .regular,  design: .default)
    }
}


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
