import SwiftUI

/// The whole app reads in "초록우산어린이체" (Yoon Childfundkorea) — a
/// children's-charity handwriting font family — instead of the system font.
/// Three unweighted styles ship (DaeHan/ManSeh/MinGuk, thin → medium →
/// thick), mapped to the app's three actual weight values: regular, medium,
/// and semibold-or-heavier.
extension Font {
    static func manana(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(mananaFontName(for: weight), size: mananaBaseSize(for: style), relativeTo: style)
    }

    static func manana(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(mananaFontName(for: weight), fixedSize: size)
    }

    /// A custom base size that still scales with Dynamic Type (unlike the
    /// `fixedSize` overload above) — for cases like a widget's quote text
    /// where none of the built-in `TextStyle` base sizes match what's wanted.
    static func manana(size: CGFloat, relativeTo textStyle: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .custom(mananaFontName(for: weight), size: size, relativeTo: textStyle)
    }

    /// Serif-quote replacement — matches the old `.system(_, design: .serif).italic()`
    /// call sites so quote text still reads as a "borrowed sentence".
    static func mananaQuote(_ style: Font.TextStyle) -> Font {
        manana(style).italic()
    }

    private static func mananaFontName(for weight: Font.Weight) -> String {
        switch weight {
        case .semibold, .bold, .heavy, .black:
            return "YoonChildfundkoreaMinGuk"
        case .medium:
            return "YoonChildfundkoreaManSeh"
        default:
            return "YoonChildfundkoreaDaeHan"
        }
    }

    private static func mananaBaseSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        default: return 17
        }
    }
}
