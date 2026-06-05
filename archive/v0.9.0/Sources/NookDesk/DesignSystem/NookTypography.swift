import SwiftUI

private let nookFontStack: [String] = [
    "Nunito",
    "LXGW WenKai",
    "PingFang SC",
    "Hiragino Sans GB",
    "M PLUS Rounded 1c",
]

private func nookFont(_ weight: String, size: CGFloat) -> Font {
    let fullName = "Nunito-\(weight)"
    return .custom(fullName, size: size)
}

struct NookLargeTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(nookFont("Black", size: 28))
            .foregroundColor(.aiTextHeader)
    }
}

struct NookTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(nookFont("ExtraBold", size: 22))
            .foregroundColor(.aiTextHeader)
    }
}

struct NookSubtitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(nookFont("Bold", size: 18))
            .foregroundColor(.aiTextHeader)
    }
}

struct NookBody: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(nookFont("Medium", size: 14))
            .foregroundColor(.aiTextBody)
    }
}

struct NookCaption: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(nookFont("Regular", size: 12))
            .foregroundColor(.aiTextSecondary)
    }
}

struct NookButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .semibold))
            .kerning(0.28)
    }
}

struct NookMono: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundColor(.aiTextBody)
    }
}

extension View {
    func nookLargeTitle() -> some View {
        modifier(NookLargeTitle())
    }

    func nookTitle() -> some View {
        modifier(NookTitle())
    }

    func nookSubtitle() -> some View {
        modifier(NookSubtitle())
    }

    func nookBody() -> some View {
        modifier(NookBody())
    }

    func nookCaption() -> some View {
        modifier(NookCaption())
    }

    func nookButtonText() -> some View {
        modifier(NookButtonStyle())
    }

    func nookMono() -> some View {
        modifier(NookMono())
    }
}

// MARK: - Text Initializers

extension Text {
    static func nookLargeTitle(_ string: String) -> Text {
        Text(string)
            .font(nookFont("Black", size: 28))
            .foregroundColor(.aiTextHeader)
    }

    static func nookTitle(_ string: String) -> Text {
        Text(string)
            .font(nookFont("ExtraBold", size: 22))
            .foregroundColor(.aiTextHeader)
    }

    static func nookSubtitle(_ string: String) -> Text {
        Text(string)
            .font(nookFont("Bold", size: 18))
            .foregroundColor(.aiTextHeader)
    }

    static func nookBody(_ string: String) -> Text {
        Text(string)
            .font(nookFont("Medium", size: 14))
            .foregroundColor(.aiTextBody)
    }

    static func nookCaption(_ string: String) -> Text {
        Text(string)
            .font(nookFont("Regular", size: 12))
            .foregroundColor(.aiTextSecondary)
    }

    static func nookMono(_ string: String) -> Text {
        Text(string)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundColor(.aiTextBody)
    }
}
