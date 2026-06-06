import SwiftUI

enum StatusBadgeLevel {
    case ok
    case warning
    case error
    case info
}

struct StatusBadge: View {
    let text: String
    let level: StatusBadgeLevel

    private var color: Color {
        switch level {
        case .ok:      return .aiSuccess
        case .warning: return .aiWarning
        case .error:   return .aiError
        case .info:    return .aiPrimary
        }
    }

    private var icon: String {
        switch level {
        case .ok:      return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(text)
                .font(.custom("Nunito-SemiBold", size: 11))
                .foregroundColor(.aiTextBody)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
    }
}
