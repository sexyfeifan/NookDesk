import SwiftUI

struct NookLargeTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Nunito-Black", size: 28))
            .foregroundColor(.aiTextHeader)
    }
}

struct NookTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Nunito-ExtraBold", size: 22))
            .foregroundColor(.aiTextHeader)
    }
}

struct NookSubtitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Nunito-Bold", size: 18))
            .foregroundColor(.aiTextHeader)
    }
}

struct NookBody: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Nunito-Medium", size: 14))
            .foregroundColor(.aiTextBody)
    }
}

struct NookCaption: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Nunito-Regular", size: 12))
            .foregroundColor(.aiTextSecondary)
    }
}

struct NookButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("Nunito-SemiBold", size: 14))
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
            .font(.custom("Nunito-Black", size: 28))
            .foregroundColor(.aiTextHeader)
    }

    static func nookTitle(_ string: String) -> Text {
        Text(string)
            .font(.custom("Nunito-ExtraBold", size: 22))
            .foregroundColor(.aiTextHeader)
    }

    static func nookSubtitle(_ string: String) -> Text {
        Text(string)
            .font(.custom("Nunito-Bold", size: 18))
            .foregroundColor(.aiTextHeader)
    }

    static func nookBody(_ string: String) -> Text {
        Text(string)
            .font(.custom("Nunito-Medium", size: 14))
            .foregroundColor(.aiTextBody)
    }

    static func nookCaption(_ string: String) -> Text {
        Text(string)
            .font(.custom("Nunito-Regular", size: 12))
            .foregroundColor(.aiTextSecondary)
    }

    static func nookMono(_ string: String) -> Text {
        Text(string)
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundColor(.aiTextBody)
    }
}
