import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case writing
    case pages
    case publish
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .writing:  return "写作"
        case .pages:    return "页面"
        case .publish:  return "发布"
        case .settings: return "设置"
        }
    }

    var icon: NookIcon {
        switch self {
        case .writing:  return .design
        case .pages:    return .map
        case .publish:  return .helicopter
        case .settings: return .variant
        }
    }
}

struct NookSidebar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    NookIcon.variant.image
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.aiPrimary)
                    Text("NookDesk")
                        .font(.custom("Nunito-Black", size: 18))
                        .foregroundColor(.aiTextHeader)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 8)

                Text("v\(AppVersion.current)")
                    .font(.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.aiTextMuted)
            }
            .padding(.bottom, 20)

            VStack(spacing: 4) {
                ForEach(MainTab.allCases) { tab in
                    NookSidebarItem(
                        icon: tab.icon,
                        label: tab.title,
                        isActive: selectedTab == tab
                    ) {
                        withAnimation(NookAnimations.nookEase) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(width: 200)
        .background(Color.aiSecondaryBg)
    }
}
