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
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ type: NookButtonType = .primary,
        size: NookButtonSize = .medium,
        label: String,
        action: @escaping () -> Void
    ) {
        self.type = type
        self.size = size
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
        case .danger:   return Color(red: 0.7, green: 0.25, blue: 0.25)
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
            Text(label)
                .font(.custom("Nunito-SemiBold", size: fontSize))
                .kerning(0.28)
                .foregroundColor(foregroundColor)
                .padding(.vertical, verticalPadding)
                .padding(.horizontal, horizontalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 50, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 50, style: .continuous)
                        .strokeBorder(
                            type == .default ? Color.aiBorderLight : Color.clear,
                            lineWidth: 1
                        )
                )
                .shadow(color: shadowColor.opacity(type == .ghost ? 0 : 0.6), radius: 0, x: 0, y: isPressed ? 1 : 5)
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
            .background(Color.white)
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
                    .fill(isOn ? Color(red: 0.525, green: 0.839, blue: 0.478) : Color.aiBorderLight)
                    .frame(width: width, height: height)

                Circle()
                    .fill(Color.white)
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
            .fill(Color(red: 0.847, green: 0.816, blue: 0.765))
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
        if isActive { return Color(red: 0.718, green: 0.776, blue: 0.898) }
        if isHovered { return Color(red: 0.839, green: 0.875, blue: 0.941) }
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
