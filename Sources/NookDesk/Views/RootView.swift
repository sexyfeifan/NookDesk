import SwiftUI

extension Notification.Name {
    static let switchToWritingTab = Notification.Name("switchToWritingTab")
}

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedTab: MainTab = .writing

    private var isProjectConfigured: Bool {
        let path = viewModel.project.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return false }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return BackendRegistry.shared.detectBackend(in: url) != nil
    }

    var body: some View {
        ZStack {
            Color.aiBackground.ignoresSafeArea()

            if isProjectConfigured {
                mainLayout
            } else {
                WizardView(viewModel: viewModel)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToWritingTab)) { _ in
            withAnimation(NookAnimations.nookEase) {
                selectedTab = .writing
            }
        }
        .alert(item: $viewModel.activeAlert) { item in
            Alert(
                title: Text(item.title),
                message: Text(item.message),
                dismissButton: .default(Text("我知道了"))
            )
        }
    }

    private var mainLayout: some View {
        HStack(spacing: 0) {
            NookSidebar(selectedTab: $selectedTab)

            Rectangle()
                .fill(Color.aiDivider)
                .frame(width: 1)

            VStack(spacing: 0) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomStatusBar
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isBusy {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(viewModel.statusText.isEmpty ? "处理中..." : viewModel.statusText)
                            .font(.custom("Nunito-Medium", size: 12))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.aiPrimary.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(NookAnimations.nookEase, value: viewModel.isBusy)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .writing:
            WritingView(viewModel: viewModel)
        case .pages:
            PageEditorView(viewModel: viewModel)
        case .publish:
            PublishView(viewModel: viewModel)
        case .settings:
            SettingsView(viewModel: viewModel)
        case .logs:
            LogsView(viewModel: viewModel)
        }
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(viewModel.isBusy ? Color.aiWarning : Color.aiSuccess)
                .frame(width: 7, height: 7)

            Text(viewModel.isBusy ? "处理中" : "就绪")
                .font(.custom("Nunito-Medium", size: 11))
                .foregroundColor(.aiTextSecondary)

            Rectangle()
                .fill(Color.aiBorderLight)
                .frame(width: 1, height: 14)

            Text(viewModel.statusText)
                .font(.custom("Nunito-Regular", size: 11))
                .foregroundColor(.aiTextMuted)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if viewModel.isBusy {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.aiSecondaryBg)
    }
}
