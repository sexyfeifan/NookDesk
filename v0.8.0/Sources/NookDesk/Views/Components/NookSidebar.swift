import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case writing
    case pages
    case publish
    case settings
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .writing:  return "写作"
        case .pages:    return "页面"
        case .publish:  return "发布"
        case .settings: return "设置"
        case .logs:     return "日志"
        }
    }

    var icon: NookIcon {
        switch self {
        case .writing:  return .pencil
        case .pages:    return .docText
        case .publish:  return .paperplane
        case .settings: return .gear
        case .logs:     return .listBullet
        }
    }
}

struct NookSidebar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("🏝️")
                    .font(.system(size: 22))
                Text("NookDesk")
                    .font(.custom("Nunito-Black", size: 18))
                    .foregroundColor(.aiTextHeader)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)

            VStack(spacing: 2) {
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

            Text("v\(AppVersion.current)")
                .font(.custom("Nunito-Regular", size: 10))
                .foregroundColor(.aiTextDisabled)
                .padding(.bottom, 16)
        }
        .frame(width: 180)
        .background(Color.aiSecondaryBg)
    }
}
