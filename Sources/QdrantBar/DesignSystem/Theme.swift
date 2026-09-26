import SwiftUI
import AppKit

private extension NSColor {
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua,
                .darkAqua,
                .vibrantLight,
                .vibrantDark
            ])
            if match == .darkAqua || match == .vibrantDark {
                return dark
            }
            return light
        }
    }
}

public enum AppThemeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .system: return "circle.righthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }
}

public enum Theme {
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
    }

    public enum Layout {
        public static let popoverWidth: CGFloat = 360
        public static let popoverHeight: CGFloat = 560
        public static let gutter: CGFloat = 16
    }

    public enum Radius {
        public static let sm: CGFloat = 4
        public static let md: CGFloat = 8
        public static let lg: CGFloat = 12
        public static let card: CGFloat = 14
        public static let pill: CGFloat = 999
    }

    public enum Colors {
        // Dynamic backgrounds supporting both Light and Dark mode
        public static let background = Color(nsColor: .dynamic(
            light: NSColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1.0),
            dark: NSColor(red: 0.110, green: 0.114, blue: 0.133, alpha: 1.0)
        ))

        public static let cardBackground = Color(nsColor: .dynamic(
            light: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            dark: NSColor(red: 0.145, green: 0.149, blue: 0.173, alpha: 1.0)
        ))

        public static let cardHover = Color(nsColor: .dynamic(
            light: NSColor(red: 0.92, green: 0.92, blue: 0.93, alpha: 1.0),
            dark: NSColor(red: 0.180, green: 0.184, blue: 0.212, alpha: 1.0)
        ))

        public static let cardSecondary = Color(nsColor: .dynamic(
            light: NSColor(red: 0.92, green: 0.92, blue: 0.93, alpha: 1.0),
            dark: NSColor(red: 0.125, green: 0.129, blue: 0.153, alpha: 1.0)
        ))

        public static let secondaryCardBackground = cardSecondary

        public static let pillBackground = Color(nsColor: .dynamic(
            light: NSColor(red: 0.89, green: 0.89, blue: 0.90, alpha: 1.0),
            dark: NSColor(red: 0.180, green: 0.184, blue: 0.212, alpha: 1.0)
        ))

        public static let badgeBackground = pillBackground

        // Dynamic borders
        public static let border = Color(nsColor: .dynamic(
            light: NSColor(red: 0.84, green: 0.84, blue: 0.86, alpha: 1.0),
            dark: NSColor(white: 1.0, alpha: 0.08)
        ))

        public static let subtleBorder = Color(nsColor: .dynamic(
            light: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.06),
            dark: NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.06)
        ))

        // Accent Colors (Calibrated for high contrast in both themes)
        /// The single brand accent: primary buttons, selection, charts.
        public static let accent = Color(nsColor: .dynamic(
            light: NSColor(red: 0.310, green: 0.275, blue: 0.898, alpha: 1.0),
            dark: NSColor(red: 0.388, green: 0.400, blue: 0.945, alpha: 1.0)
        ))

        public static let accentSoft = Color(nsColor: .dynamic(
            light: NSColor(red: 0.494, green: 0.510, blue: 0.960, alpha: 1.0),
            dark: NSColor(red: 0.612, green: 0.624, blue: 0.969, alpha: 1.0)
        ))

        public static let onAccent = Color.white

        public static let amberGold = Color(nsColor: .dynamic(
            light: NSColor(red: 0.82, green: 0.52, blue: 0.08, alpha: 1.0),
            dark: NSColor(red: 0.92, green: 0.68, blue: 0.24, alpha: 1.0)
        ))

        public static let metricCyan = Color(nsColor: .dynamic(
            light: NSColor(red: 0.10, green: 0.52, blue: 0.88, alpha: 1.0),
            dark: NSColor(red: 0.28, green: 0.68, blue: 0.98, alpha: 1.0)
        ))

        public static let metricOrange = Color(nsColor: .dynamic(
            light: NSColor(red: 0.88, green: 0.38, blue: 0.10, alpha: 1.0),
            dark: NSColor(red: 0.95, green: 0.50, blue: 0.20, alpha: 1.0)
        ))

        public static let metricPurple = Color(nsColor: .dynamic(
            light: NSColor(red: 0.58, green: 0.30, blue: 0.85, alpha: 1.0),
            dark: NSColor(red: 0.72, green: 0.48, blue: 0.96, alpha: 1.0)
        ))

        // Brand
        public static let brand = Color(red: 0.388, green: 0.400, blue: 0.945)
        public static let brandGradient = LinearGradient(
            colors: [Color(red: 0.388, green: 0.400, blue: 0.945), Color(red: 0.545, green: 0.561, blue: 1.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Status
        public static let statusGreen = Color(nsColor: .dynamic(
            light: NSColor(red: 0.20, green: 0.68, blue: 0.30, alpha: 1.0),
            dark: NSColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1.0)
        ))

        public static let statusYellow = Color(nsColor: .dynamic(
            light: NSColor(red: 0.85, green: 0.60, blue: 0.10, alpha: 1.0),
            dark: NSColor(red: 0.961, green: 0.722, blue: 0.239, alpha: 1.0)
        ))

        public static let statusOrange = Color(nsColor: .dynamic(
            light: NSColor(red: 0.88, green: 0.44, blue: 0.12, alpha: 1.0),
            dark: NSColor(red: 0.95, green: 0.55, blue: 0.20, alpha: 1.0)
        ))

        public static let statusRed = Color(nsColor: .dynamic(
            light: NSColor(red: 0.88, green: 0.20, blue: 0.18, alpha: 1.0),
            dark: NSColor(red: 1.0, green: 0.353, blue: 0.322, alpha: 1.0)
        ))

        public static let statusGray = Color(nsColor: .dynamic(
            light: NSColor.secondaryLabelColor,
            dark: NSColor.tertiaryLabelColor
        ))

        // Typography Colors
        public static let textPrimary = Color(nsColor: .dynamic(
            light: NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0),
            dark: NSColor(red: 0.949, green: 0.949, blue: 0.961, alpha: 1.0)
        ))

        public static let textSecondary = Color(nsColor: .dynamic(
            light: NSColor(red: 0.40, green: 0.40, blue: 0.44, alpha: 1.0),
            dark: NSColor(red: 0.651, green: 0.655, blue: 0.690, alpha: 1.0)
        ))

        public static let textMuted = Color(nsColor: .dynamic(
            light: NSColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 1.0),
            dark: NSColor(red: 0.545, green: 0.549, blue: 0.588, alpha: 1.0)
        ))
    }

    public enum Typography {
        public static let heroNumber = Font.system(size: 38, weight: .light, design: .rounded)
        public static let statValue = Font.system(size: 18, weight: .light, design: .rounded)
        public static let cardValue = Font.system(size: 20, weight: .bold, design: .rounded)
        public static let title = Font.system(size: 13, weight: .bold, design: .rounded)
        public static let headline = Font.system(size: 12, weight: .semibold, design: .default)
        public static let body = Font.system(size: 12, weight: .regular, design: .default)
        public static let bodyBold = Font.system(size: 12, weight: .semibold, design: .default)
        public static let caption = Font.system(size: 11, weight: .medium, design: .default)
        public static let captionBold = Font.system(size: 11, weight: .bold, design: .default)
        public static let micro = Font.system(size: 10, weight: .semibold, design: .default)
        public static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)
        public static let monoBold = Font.system(size: 11, weight: .bold, design: .monospaced)
    }
}
