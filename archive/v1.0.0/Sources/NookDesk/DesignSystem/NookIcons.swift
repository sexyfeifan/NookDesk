import SwiftUI

enum NookIcon: String, CaseIterable, Identifiable {
    case miles
    case camera
    case chat
    case critterpedia
    case design
    case diy
    case helicopter
    case map
    case shopping
    case variant

    var id: String { rawValue }

    private var systemImage: String {
        switch self {
        case .miles:       return "flag.fill"
        case .camera:      return "camera.fill"
        case .chat:        return "bubble.left.fill"
        case .critterpedia:return "ant.fill"
        case .design:      return "paintbrush.fill"
        case .diy:         return "hammer.fill"
        case .helicopter:  return "airplane"
        case .map:         return "map.fill"
        case .shopping:    return "cart.fill"
        case .variant:     return "sparkles"
        }
    }

    @ViewBuilder
    var image: some View {
        Image(systemName: systemImage)
    }
}
