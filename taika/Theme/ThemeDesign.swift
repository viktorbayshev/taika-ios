import SwiftUI

enum Theme {

    // MARK: - Colors
    struct Colors {
        // Base surfaces
        static let background = Color(red: 0.06, green: 0.06, blue: 0.07)     // app background
        static let card       = Color(red: 0.10, green: 0.10, blue: 0.11)     // cards / lists
        static let elevated   = Color(red: 0.13, green: 0.13, blue: 0.15)     // elevated overlays

        // Content
        static let textPrimary   = Color.white.opacity(0.92)
        static let textSecondary = Color.white.opacity(0.60)

        // Decorations
        static let stroke   = Color.white.opacity(0.08)                       // borders / dividers
        static let accent   = Color(red: 0.62, green: 0.58, blue: 0.99)       // lavender accent for actions
    }

    // MARK: - Typography
    struct Fonts {
        /// Branded logo typeface (only for the app name / logo)
        static func appTitle(_ size: CGFloat) -> Font {
            // PostScript name should match Info.plist "Fonts provided by application"
            Font.custom("OnmarkTRIAL", size: size)
        }

        /// Unified UI typeface (rounded San Francisco)
        static let heading = Font.system(size: 24, weight: .bold, design: .rounded)
        static let body    = Font.system(size: 17, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 13, weight: .regular, design: .rounded)
        static let label   = Font.system(size: 15, weight: .medium, design: .rounded)
    }

    // MARK: - Brand Font Alias
    struct BrandFont {
        static func logo(_ size: CGFloat) -> Font {
            Theme.Fonts.appTitle(size)
        }
    }

    // MARK: - Geometry
    struct Radii {
        static let card: CGFloat  = 20
        static let chip: CGFloat  = 18
        static let pill: CGFloat  = 24
    }

    struct Stroke {
        static let hair: CGFloat     = 0.5
        static let regular: CGFloat  = 1.0
    }

    struct Spacing {
        static let outer: CGFloat   = 16     // default horizontal page inset
        static let inner: CGFloat   = 12     // inside cards
        static let section: CGFloat = 20     // between blocks/sections
        static let row: CGFloat     = 10     // between rows in stacks
    }

    // MARK: - States
    struct States {
        static let selectedBg = Colors.accent.opacity(0.14)
        static let pressedBg  = Color.white.opacity(0.08)
        static let disabledOpacity: CGFloat = 0.4
    }

    // MARK: - Shadows / Glows
    struct Shadows {
        static let glow = Colors.accent.opacity(0.45)
    }

    // MARK: - Header Tokens (shared across screens)
    struct Header {
        // Layout
        static let paddingH: CGFloat = Spacing.outer        // horizontal inset of card
        static let paddingV: CGFloat = 18                   // vertical padding inside card
        static let contentSpacing: CGFloat = 10             // spacing between title/subtitle/cta
        static let cardRadius: CGFloat = Radii.card

        // Sizes
        static let logoSize: CGFloat   = 26                 // taikA logo font size
        static let mascotSize: CGFloat = 84                 // mascot drawing box size

        // Typography
        static let titleFont: Font    = Font.system(size: 24, weight: .bold, design: .rounded)
        static let subtitleFont: Font = Font.system(size: 15, weight: .regular, design: .rounded)

        // CTA (chip-like button)
        static let ctaHeight: CGFloat = 36
        static let ctaRadius: CGFloat = 18
        static let ctaStroke: CGFloat = Stroke.regular
    }
}
