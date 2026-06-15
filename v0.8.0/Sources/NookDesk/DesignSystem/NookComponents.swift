import SwiftUI

// MARK: - NookCard

struct NookCard<Content: View>: View {
    let color: NookColor
    let content: () -> Content

    @State private var isHovered = false

    init(color: NookColor = .nookDefault, @ViewBuilder content: @escaping () -> Content) {
        self.color = color
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(Color.aiContent)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(color.color.opacity(0.5), lineWidth: color == .nookDefault ? 0 : 2)
            )
            .offset(y: isHovered ? -2 : 0)
            .animation(NookAnimations.nookCardHover, value: isHovered)
            .onHover { hovering in isHovered = hovering }
    }
}

// MARK: - NookButton

enum NookButtonType {
    case primary, `default`, ghost, danger
}

enum NookButtonSize {
    case small, medium, large
}

struct NookButton: View {
    let type: NookButtonType
    let size: NookButtonSize
    let icon: String?
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ type: NookButtonType = .primary,
        size: NookButtonSize = .medium,
        icon: String? = nil,
        label: String,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.size = size
        self.icon = icon
        self.label = label
        self.action = action
    }

    private var foregroundColor: Color {
        switch type {
        case .primary:  return .white
        case .default:  return .aiTextBody
        case .ghost:    return .aiTextBody
        case .danger:   return .white
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .primary:  return .aiPrimary
        case .default:  return .aiContent
        case .ghost:    return .clear
        case .danger:   return .aiError
        }
    }

    private var shadowColor: Color {
        switch type {
        case .primary:  return .aiShadowBtn
        case .default:  return .aiShadowBtn
        case .ghost:    return .clear
        case .danger:   return .aiDangerShadow
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small:  return 6
        case .medium: return 10
        case .large:  return 14
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small:  return 14
        case .medium: return 20
        case .large:  return 28
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .small:  return 12
        case .medium: return 14
        case .large:  return 16
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(label)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .font(.system(size: fontSize, weight: .semibold))
                    .kerning(0.28)
            }
            .foregroundColor(foregroundColor)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 50, style: .continuous)
                            .strokeBorder(
                                type == .default ? Color.aiBorderLight : Color.clear,
                                lineWidth: 1
                            )
                    )
                    .shadow(color: shadowColor.opacity(type == .ghost ? 0 : 0.6), radius: 0, x: 0, y: isPressed ? 1 : 5)
            )
            .offset(y: isPressed ? 2 : 0)
        }
        .buttonStyle(.plain)
        .animation(NookAnimations.nookFast, value: isPressed)
        .onLongPressGesture(
            minimumDuration: .infinity,
            pressing: { pressing in isPressed = pressing },
            perform: {}
        )
    }
}

// MARK: - NookInput

enum NookInputStatus {
    case normal, success, warning, error
}

struct NookInput: View {
    let placeholder: String
    @Binding var text: String
    let status: NookInputStatus

    @FocusState private var isFocused: Bool

    init(_ placeholder: String, text: Binding<String>, status: NookInputStatus = .normal) {
        self.placeholder = placeholder
        self._text = text
        self.status = status
    }

    private var borderColor: Color {
        if isFocused { return .aiFocusYellow }
        switch status {
        case .normal:  return .aiBorderLight
        case .success: return .aiSuccess
        case .warning: return .aiWarning
        case .error:   return .aiError
        }
    }

    private var shadowRadius: CGFloat {
        isFocused ? 3 : 0
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.custom("Nunito-Medium", size: 14))
            .foregroundColor(.aiTextBody)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.aiInputBg)
            .clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .shadow(color: .aiFocusYellow.opacity(isFocused ? 0.3 : 0), radius: shadowRadius)
            .shadow(color: .aiShadowInput.opacity(isFocused ? 0 : 0.2), radius: 1, y: 1)
            .focused($isFocused)
            .animation(NookAnimations.nookEase, value: isFocused)
    }
}

// MARK: - NookSwitch

struct NookSwitch: View {
    @Binding var isOn: Bool

    private let width: CGFloat = 44
    private let height: CGFloat = 24
    private let handleSize: CGFloat = 18

    var body: some View {
        Button {
            withAnimation(NookAnimations.nookSpring) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.aiSwitchOn : Color.aiBorderLight)
                    .frame(width: width, height: height)

                Circle()
                    .fill(Color.aiSwitchHandle)
                    .frame(width: handleSize, height: handleSize)
                    .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - NookSection

struct NookSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: () -> Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Nunito-Bold", size: 18))
                    .foregroundColor(.aiTextHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        }
    }
}

// MARK: - NookDivider

struct NookDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.aiDivider)
            .frame(height: 1)
    }
}

// MARK: - NookTag

struct NookTag: View {
    let text: String
    let color: NookColor

    init(_ text: String, color: NookColor = .nookDefault) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.custom("Nunito-SemiBold", size: 11))
            .foregroundColor(.aiTextBody)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.color.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - NookEmptyState

struct NookEmptyState: View {
    let icon: NookIcon
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: NookIcon,
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            icon.image
                .font(.system(size: 40))
                .foregroundColor(.aiTextMuted)

            Text(title)
                .font(.custom("Nunito-Bold", size: 16))
                .foregroundColor(.aiTextHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.aiTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                NookButton(.primary, size: .small, label: actionTitle, action: action)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }
}

// MARK: - NookSidebarItem

struct NookSidebarItem: View {
    let icon: NookIcon
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    init(icon: NookIcon, label: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    private var backgroundColor: Color {
        if isActive { return Color.aiSidebarActive }
        if isHovered { return Color.aiSidebarHover }
        return .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon.image
                    .font(.system(size: 16))
                    .foregroundColor(isActive ? .white : .aiTextBody)
                    .frame(width: 20)

                Text(label)
                    .font(.custom(isActive ? "Nunito-Bold" : "Nunito-Medium", size: 13))
                    .foregroundColor(isActive ? .white : .aiTextBody)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
        .animation(NookAnimations.nookFast, value: isHovered)
    }
}

// MARK: - NookFooter

enum NookFooterStyle {
    case sea
    case forest
}

struct NookFooter: View {
    let style: NookFooterStyle

    init(style: NookFooterStyle = .sea) {
        self.style = style
    }

    var body: some View {
        VStack(spacing: 0) {
            waveShape
                .frame(height: 40)
                .opacity(0.6)

            HStack {
                Spacer()
                Text("NookDesk")
                    .font(.custom("Nunito-Bold", size: 11))
                    .foregroundColor(.aiTextMuted)
                Spacer()
            }
            .padding(.vertical, 8)
            .background(footerBackgroundColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var waveShape: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height * 0.6))

            let waveCount = 3
            let waveWidth = size.width / CGFloat(waveCount)
            for i in 0..<waveCount {
                let startX = CGFloat(i) * waveWidth
                path.addCurve(
                    to: CGPoint(x: startX + waveWidth, y: size.height * 0.6),
                    control1: CGPoint(x: startX + waveWidth * 0.33, y: size.height * 0.2),
                    control2: CGPoint(x: startX + waveWidth * 0.66, y: size.height)
                )
            }

            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()

            context.fill(path, with: .color(waveColor))
        }
    }

    private var waveColor: Color {
        switch style {
        case .sea:
            return .aiSea
        case .forest:
            return .aiForest
        }
    }

    private var footerBackgroundColor: Color {
        switch style {
        case .sea:
            return Color.aiSea.opacity(0.15)
        case .forest:
            return Color.aiForest.opacity(0.15)
        }
    }
}

// MARK: - NookWaveDivider

struct NookWaveDivider: View {
    var body: some View {
        Canvas { context, size in
            let midY = size.height * 0.5
            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))

            let waveCount = 6
            let waveWidth = size.width / CGFloat(waveCount)
            for i in 0..<waveCount {
                let startX = CGFloat(i) * waveWidth
                path.addCurve(
                    to: CGPoint(x: startX + waveWidth, y: midY),
                    control1: CGPoint(x: startX + waveWidth * 0.33, y: midY - 4),
                    control2: CGPoint(x: startX + waveWidth * 0.66, y: midY + 4)
                )
            }

            context.stroke(path, with: .color(Color.aiDivider), lineWidth: 1.5)
        }
        .frame(height: 12)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - NookLoadingOverlay

struct NookLoadingOverlay: View {
    let message: String
    @State private var isRotating = false

    init(message: String = "加载中...") {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.aiBackground.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("\u{1F343}")
                    .font(.system(size: 48))
                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: isRotating
                    )

                Text(message)
                    .font(.custom("Nunito-SemiBold", size: 14))
                    .foregroundColor(.aiTextBody)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.aiContent)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)
            )
        }
        .onAppear {
            isRotating = true
        }
    }
}

// MARK: - NookTypewriterText

struct NookTypewriterText: View {
    let text: String
    let typingSpeed: TimeInterval
    @State private var displayedText = ""
    @State private var showCursor = true
    @State private var animationTask: Task<Void, Never>?

    init(_ text: String, typingSpeed: TimeInterval = 0.06) {
        self.text = text
        self.typingSpeed = typingSpeed
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(displayedText)
                .font(.custom("Nunito-Bold", size: 28))
                .foregroundColor(.aiTextHeader)

            Rectangle()
                .fill(Color.aiPrimary)
                .frame(width: 2, height: 28)
                .opacity(showCursor ? 1 : 0)
                .animation(
                    Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                    value: showCursor
                )
        }
        .onAppear {
            showCursor = true
            displayedText = ""
            animationTask?.cancel()
            animationTask = Task { @MainActor in
                for (index, char) in text.enumerated() {
                    guard !Task.isCancelled else { break }
                    try? await Task.sleep(nanoseconds: UInt64(typingSpeed * 1_000_000_000) * UInt64(index == 0 ? 0 : 1))
                    guard !Task.isCancelled else { break }
                    displayedText.append(char)
                }
            }
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }
}

// MARK: - NookLeafIcon

struct NookLeafIcon: View {
    let size: CGFloat

    init(size: CGFloat = 24) {
        self.size = size
    }

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            var leaf = Path()
            leaf.move(to: CGPoint(x: w * 0.5, y: h * 0.1))
            leaf.addCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.55),
                control1: CGPoint(x: w * 0.1, y: h * 0.15),
                control2: CGPoint(x: w * 0.05, y: h * 0.4)
            )
            leaf.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.9),
                control1: CGPoint(x: w * 0.2, y: h * 0.7),
                control2: CGPoint(x: w * 0.35, y: h * 0.85)
            )
            leaf.addCurve(
                to: CGPoint(x: w * 0.85, y: h * 0.55),
                control1: CGPoint(x: w * 0.65, y: h * 0.85),
                control2: CGPoint(x: w * 0.8, y: h * 0.7)
            )
            leaf.addCurve(
                to: CGPoint(x: w * 0.5, y: h * 0.1),
                control1: CGPoint(x: w * 0.95, y: h * 0.4),
                control2: CGPoint(x: w * 0.9, y: h * 0.15)
            )
            leaf.closeSubpath()

            context.fill(leaf, with: .color(Color.aiLeafFill))

            var stem = Path()
            stem.move(to: CGPoint(x: w * 0.5, y: h * 0.45))
            stem.addLine(to: CGPoint(x: w * 0.5, y: h * 0.95))
            context.stroke(stem, with: .color(Color.aiLeafStem), lineWidth: 2)

            var vein = Path()
            vein.move(to: CGPoint(x: w * 0.5, y: h * 0.45))
            vein.addLine(to: CGPoint(x: w * 0.3, y: h * 0.35))
            vein.move(to: CGPoint(x: w * 0.5, y: h * 0.55))
            vein.addLine(to: CGPoint(x: w * 0.7, y: h * 0.45))
            vein.move(to: CGPoint(x: w * 0.5, y: h * 0.65))
            vein.addLine(to: CGPoint(x: w * 0.35, y: h * 0.58))
            context.stroke(vein, with: .color(Color.aiLeafStem.opacity(0.5)), lineWidth: 1)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - NookDropdown

struct NookDropdown<Label: View, Content: View>: View {
    let label: () -> Label
    let content: () -> Content

    @State private var isOpen = false
    @State private var isHovered = false

    init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.content = content
    }

    var body: some View {
        Menu {
            content()
        } label: {
            label()
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundColor(.aiTextBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isHovered ? Color.aiSecondaryBg : Color.aiContent)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.aiBorderLight, lineWidth: 1.5)
                        )
                )
                .shadow(color: .aiShadowBtn.opacity(0.3), radius: 0, x: 0, y: 3)
                .offset(y: isHovered ? -1 : 0)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .onHover { hovering in
            withAnimation(NookAnimations.nookFast) {
                isHovered = hovering
            }
        }
    }
}

extension NookDropdown where Label == Text {
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(label: { Text(title) }, content: content)
    }
}
