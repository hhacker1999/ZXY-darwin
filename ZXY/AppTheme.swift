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
//
//  MediaLibrary  — poster shelf + grid sizing / fonts (iPhone compact vs iPad/desktop)
//    AppTheme.MediaLibrary.rowPosterWidth / sectionHeaderFont / gridMinPosterWidth …
//  Layout  — horizontal insets for tabs + settings + MediaGrid (iOS tighter)
//    AppTheme.Layout.tabScreenHorizontalPadding / mediaGridScrollHorizontalPadding …
//  ─────────────────────────────────────────────────────────────────

import SwiftUI
#if os(iOS)
import UIKit
#endif

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

    /// Horizontal insets for tab roots (Discover, Search, Library) and Settings.
    enum Layout {
        private static var isIOS: Bool {
            #if os(iOS)
            true
            #else
            false
            #endif
        }

        private static var isCompactPhone: Bool {
            #if os(iOS)
            UIDevice.current.userInterfaceIdiom == .phone
            #else
            false
            #endif
        }

        /// Search / Library / Settings: outer leading/trailing for headers & main scroll (mac: `Spacing.xl`).
        static var tabScreenHorizontalPadding: CGFloat {
            if isIOS {
                return isCompactPhone ? 12 : 16
            }
            return Spacing.xl
        }

        /// Discover: outer `VStack` horizontal (mac keeps 16; iOS tighter).
        static var discoverOuterHorizontalPadding: CGFloat {
            if isIOS {
                return isCompactPhone ? 12 : 16
            }
            return Spacing.md
        }

        /// Extra wrapper on `MediaGrid` so its content lines up with tab headers (mac: `xl − md`; iOS: none).
        static var mediaGridOuterAlignmentPadding: CGFloat {
            if isIOS {
                return 0
            }
            return Spacing.xl - Spacing.md
        }

        /// LazyVGrid horizontal padding inside `MediaGrid`.
        static var mediaGridScrollHorizontalPadding: CGFloat {
            if isIOS {
                return tabScreenHorizontalPadding
            }
            return Spacing.md
        }
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

    /// Shared sizing and type for horizontal poster shelves (home discovery rows,
    /// “You may also like” / similar on movie & series, MediaRow) and home continue-watching.
    enum MediaLibrary {
        private static var isCompactPhone: Bool {
            #if os(iOS)
            UIDevice.current.userInterfaceIdiom == .phone
            #else
            false
            #endif
        }

        static let shelfTitleLineLimit = 2

        /// Single-line caption under shelf posters (grid keeps `shelfTitleLineLimit`).
        static let shelfRowTitleLineLimit = 1

        /// Brighter than `elementSubtle` for shelf row captions.
        static let shelfPosterTitleColor = Color.white.opacity(0.85)

        /// Subtle grey stroke around shelf row posters.
        static let shelfPosterBorderColor = Color.white.opacity(0.20)

        /// Horizontal gap between posters in a shelf row.
        static var shelfRowItemSpacing: CGFloat { Spacing.sm + 6 }

        // MARK: Horizontal shelf posters (~0.8× on iPhone)

        static var rowPosterWidth: CGFloat {
            if isCompactPhone { return 104 }
            #if os(macOS)
            return 145
            #else
            return 130
            #endif
        }

        static var rowPosterHeight: CGFloat {
            if isCompactPhone { return 156 }
            #if os(macOS)
            return 218
            #else
            return 195
            #endif
        }

        static var rowPosterCornerRadius: CGFloat { isCompactPhone ? 10 : 12 }

        /// Poster + spacing + title block for discovery shelf row height locking.
        static var shelfRowStableHeight: CGFloat {
            rowPosterHeight + Spacing.xs + 2 + shelfRowTitleBlockHeight
        }

        private static var shelfRowTitleBlockHeight: CGFloat { 18 }

        // MARK: Library / search / discover grid (`MediaGrid`)

        /// `true` for iPhone / iPad app; macOS & visionOS use desktop spacing.
        private static var isIOS: Bool {
            #if os(iOS)
            true
            #else
            false
            #endif
        }

        /// Minimum cell width for `LazyVGrid` adaptive columns — smaller on iOS for more columns.
        static var gridMinPosterWidth: CGFloat {
            if isIOS {
                return isCompactPhone ? 96 : 120
            }
            #if os(macOS)
            return 155
            #else
            return 140
            #endif
        }

        static var gridPosterCornerRadius: CGFloat {
            if isIOS {
                return isCompactPhone ? 8 : 10
            }
            return 12
        }

        /// Horizontal gap between grid columns (`GridItem` adaptive spacing).
        static var gridColumnSpacing: CGFloat {
            isIOS ? Spacing.sm + 2 : Spacing.md
        }

        /// Vertical gap between grid rows (`LazyVGrid` spacing).
        static var gridRowSpacing: CGFloat {
            isIOS ? Spacing.md : Spacing.lg
        }

        /// Under-poster title in grid (slightly tighter than shelf on iOS).
        static var gridPosterTitleFont: Font {
            #if os(iOS)
            isCompactPhone
                ? .system(size: 11, weight: .regular, design: .default)
                : .system(size: 12, weight: .regular, design: .default)
            #else
            Typography.bodySmall
            #endif
        }

        /// Fixed title block under poster (single line on desktop, two on iOS).
        static var gridTitleBlockHeight: CGFloat {
            if isIOS {
                return isCompactPhone ? 30 : 34
            }
            return shelfRowTitleBlockHeight
        }

        static var gridTypeBadgeFont: Font {
            #if os(iOS)
            .system(size: 10, weight: .bold, design: .default)
            #else
            .system(size: 11, weight: .bold, design: .default)
            #endif
        }

        static var gridTypeBadgePaddingH: CGFloat { isIOS ? 6 : 8 }
        static var gridTypeBadgePaddingV: CGFloat { isIOS ? 3 : 4 }
        static var gridTypeBadgeOuterPadding: CGFloat { isIOS ? 6 : 8 }

        // MARK: Continue watching (home)

        private static let cwPosterAspectRatio: CGFloat = 2.0 / 3.0

        static var cwPosterWidth: CGFloat {
            if isCompactPhone { return 80 }
            #if os(macOS)
            return 115
            #else
            return 100
            #endif
        }

        static var cwPosterHeight: CGFloat { cwPosterWidth / cwPosterAspectRatio }

        static var cwCardWidth: CGFloat {
            if isCompactPhone { return 248 }
            #if os(macOS)
            return 340
            #else
            return 300
            #endif
        }

        static var cwCardHeight: CGFloat { cwPosterHeight }

        static var cwCornerRadius: CGFloat {
            if isCompactPhone { return 9 }
            #if os(macOS)
            return 12
            #else
            return 10
            #endif
        }
        static let cwProgressBarHeight: CGFloat = 4
        static let cwProgressBarRadius: CGFloat = 2

        // MARK: Typography — section titles & poster captions

        static var sectionHeaderFont: Font {
            isCompactPhone ? Typography.headingSmall : Typography.headingMedium
        }

        static var posterTitleFont: Font {
            isCompactPhone
                ? .system(size: 12, weight: .regular, design: .default)
                : Typography.bodySmall
        }

        static var cwTitleFont: Font {
            isCompactPhone
                ? .system(size: 13, weight: .bold, design: .default)
                : .system(size: 15, weight: .bold, design: .default)
        }

        static var cwSubtitleFont: Font {
            isCompactPhone
                ? .system(size: 12, weight: .regular, design: .default)
                : .system(size: 13, weight: .regular, design: .default)
        }

        static var cwPercentFont: Font {
            isCompactPhone
                ? .system(size: 11, weight: .regular, design: .default)
                : .system(size: 12, weight: .regular, design: .default)
        }

        static var cwMenuIconFont: Font {
            isCompactPhone
                ? .system(size: 13, weight: .bold, design: .default)
                : .system(size: 14, weight: .bold, design: .default)
        }

        // MARK: Shimmer placeholders (approx. real layout)

        static var sectionTitleShimmerWidth: CGFloat { isCompactPhone ? 128 : 160 }
        static var sectionTitleShimmerHeight: CGFloat { isCompactPhone ? 16 : 18 }
        static var cwShimmerInnerTitleWidth: CGFloat { isCompactPhone ? 100 : 130 }
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
