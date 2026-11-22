//
//  KilalaBrand.swift
//  Kilala
//
//  Official Kilala Brand Guidelines tokens: colors, verification states,
//  Atkinson Hyperlegible typography helpers, and the vector brand logo.
//

import SwiftUI
import UIKit

// MARK: - Brand Color Tokens

extension Color {
    /// Hex color initializer for exact Kilala brand tokens.
    init(kilalaHex hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    // Core Brand Palette
    /// Primary actions, headers, active accents, primary buttons (`#0E5B4A`).
    static let kilalaGreen = Color(kilalaHex: 0x0E5B4A)
    /// Accent highlights and checkmark accent (`#F4B740`). Always pair with `kilalaInk` when used as a fill.
    static let kilalaSunrise = Color(kilalaHex: 0xF4B740)
    /// Primary dark text, active tab icons/labels, primary dark surfaces (`#112018`).
    static let kilalaInk = Color(kilalaHex: 0x112018)
    /// Card backgrounds, elevated surfaces, subtle fills (`#E3EEE9`).
    static let kilalaMint = Color(kilalaHex: 0xE3EEE9)
    /// Main app canvas/background instead of pure `#FFFFFF` (`#F6F4EE`).
    static let kilalaPaper = Color(kilalaHex: 0xF6F4EE)

    // Verification State Colors
    /// Verified / Active state (`#1F7A4D`).
    static let kilalaStateValid = Color(kilalaHex: 0x1F7A4D)
    /// Expired / Renewal needed state (`#F4B740`), paired with `kilalaInk` (`#112018`) dark text.
    static let kilalaStateExpired = Color(kilalaHex: 0xF4B740)
    /// Not recognized / Suspended / Revoked state (`#B3261E`).
    static let kilalaStateInvalid = Color(kilalaHex: 0xB3261E)

    // Derived Ink & Surface Neutrals
    static let kilalaInkSecondary = Color(kilalaHex: 0x112018, opacity: 0.65)
    static let kilalaInkMuted = Color(kilalaHex: 0x112018, opacity: 0.42)
    static let kilalaBorder = Color(kilalaHex: 0x112018, opacity: 0.12)
    static let kilalaMintBorder = Color(kilalaHex: 0x0E5B4A, opacity: 0.16)
}

// MARK: - Brand Typography (Atkinson Hyperlegible)

enum KilalaTypography {
    /// Resolves the bundled Atkinson Hyperlegible PostScript name if present in the app bundle / `Info.plist` (`UIAppFonts`).
    /// Checked once at launch so there is no repeated lookup cost and zero risk of crashing if `.ttf` files are not yet added.
    private static let regularFontName: String? = resolveFontName(from: [
        "AtkinsonHyperlegible-Regular",
        "AtkinsonHyperlegibleNext-Regular"
    ])

    private static let boldFontName: String? = resolveFontName(from: [
        "AtkinsonHyperlegible-Bold",
        "AtkinsonHyperlegibleNext-Bold"
    ])

    private static func resolveFontName(from candidates: [String]) -> String? {
        candidates.first { UIFont(name: $0, size: 17) != nil }
    }

    static func font(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        let prefersBold = weight == .semibold || weight == .bold || weight == .heavy || weight == .black
        if let fontName = prefersBold ? (boldFontName ?? regularFontName) : regularFontName {
            return .custom(fontName, size: size, relativeTo: textStyle)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    static func font(_ textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        font(size: defaultPointSize(for: textStyle), weight: weight, relativeTo: textStyle)
    }

    static func monospaced(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func monospaced(_ textStyle: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(textStyle, design: .monospaced).weight(weight)
    }

    private static func defaultPointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .subheadline: return 15
        case .body: return 17
        case .callout: return 16
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }
}

extension Font {
    static func kilala(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        KilalaTypography.font(style, weight: weight)
    }

    static func kilala(size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        KilalaTypography.font(size: size, weight: weight, relativeTo: textStyle)
    }

    static func kilalaMono(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        KilalaTypography.monospaced(style, weight: weight)
    }

    static func kilalaMono(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        KilalaTypography.monospaced(size: size, weight: weight)
    }
}

// MARK: - Kilala Vector Brand Logo

/// Crisp SwiftUI vector logo mark matching the Kilala Brand Guidelines:
/// scan-bracket frame in Kilala Green (`#0E5B4A`) with a Sunrise (`#F4B740`) checkmark,
/// paired with the lowercase bold `kilala` wordmark in Ink (`#112018`).
struct KilalaBrandLogo: View {
    var iconSize: CGFloat = 22
    var wordmarkSize: CGFloat = 19
    var showWordmark: Bool = true
    var reversed: Bool = false

    var body: some View {
        HStack(spacing: 6.5) {
            KilalaScanMark(
                bracketColor: reversed ? .white : .kilalaGreen,
                checkColor: .kilalaSunrise
            )
            .frame(width: iconSize, height: iconSize)

            if showWordmark {
                Text("Kilala")
                    .font(.kilala(size: wordmarkSize, weight: .bold, relativeTo: .headline))
                    .tracking(-0.4)
                    .foregroundColor(reversed ? .white : .kilalaInk)
                    .lineLimit(1)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kilala")
    }
}

/// Stacked mobile editorial header rendered directly on the Paper (`#F6F4EE`) canvas:
/// static untruncated `KilalaBrandLogo` on top, followed by a bold 30pt heading and optional subtitle.
struct BusinessPortalHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            KilalaBrandLogo(iconSize: 22, wordmarkSize: 19)
                .fixedSize()
                .accessibilityAddTraits(.isStaticText)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.kilala(size: 30, weight: .bold, relativeTo: .largeTitle))
                    .foregroundColor(.kilalaInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.kilala(.callout))
                        .foregroundColor(.kilalaInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Accessible status badge pairing an SF Symbol icon with a text label (never color alone).
struct KilalaStatusBadge: View {
    let icon: String
    let label: String
    let foreground: Color
    let background: Color
    var cornerRadius: CGFloat = 8

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .accessibilityHidden(true)

            Text(label)
                .font(.kilala(.caption, weight: .bold))
                .lineLimit(1)
        }
        .foregroundColor(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Vector scan-bracket frame with Sunrise checkmark (24x24 normalized coordinate space).
struct KilalaScanMark: View {
    var bracketColor: Color = .kilalaGreen
    var checkColor: Color = .kilalaSunrise

    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / 24.0
            let scaleY = size.height / 24.0
            let scale = min(scaleX, scaleY)

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * scaleX, y: y * scaleY)
            }

            let bracketStroke = StrokeStyle(
                lineWidth: 2.2 * scale,
                lineCap: .round,
                lineJoin: .round
            )

            // Four rounded corner scan brackets
            var brackets = Path()
            // Top-left: M4 8 V6 Q4 4 6 4 H8
            brackets.move(to: pt(4, 8))
            brackets.addLine(to: pt(4, 6))
            brackets.addQuadCurve(to: pt(6, 4), control: pt(4, 4))
            brackets.addLine(to: pt(8, 4))

            // Top-right: M16 4 H18 Q20 4 20 6 V8
            brackets.move(to: pt(16, 4))
            brackets.addLine(to: pt(18, 4))
            brackets.addQuadCurve(to: pt(20, 6), control: pt(20, 4))
            brackets.addLine(to: pt(20, 8))

            // Bottom-right: M20 16 V18 Q20 20 18 20 H16
            brackets.move(to: pt(20, 16))
            brackets.addLine(to: pt(20, 18))
            brackets.addQuadCurve(to: pt(18, 20), control: pt(20, 20))
            brackets.addLine(to: pt(16, 20))

            // Bottom-left: M8 20 H6 Q4 20 4 18 V16
            brackets.move(to: pt(8, 20))
            brackets.addLine(to: pt(6, 20))
            brackets.addQuadCurve(to: pt(4, 18), control: pt(4, 20))
            brackets.addLine(to: pt(4, 16))

            context.stroke(brackets, with: .color(bracketColor), style: bracketStroke)

            // Sunrise checkmark: M8.4 12.3 L10.8 14.7 L15.6 9.7
            var checkmark = Path()
            checkmark.move(to: pt(8.4, 12.3))
            checkmark.addLine(to: pt(10.8, 14.7))
            checkmark.addLine(to: pt(15.6, 9.7))

            let checkStroke = StrokeStyle(
                lineWidth: 2.6 * scale,
                lineCap: .round,
                lineJoin: .round
            )
            context.stroke(checkmark, with: .color(checkColor), style: checkStroke)
        }
    }
}
