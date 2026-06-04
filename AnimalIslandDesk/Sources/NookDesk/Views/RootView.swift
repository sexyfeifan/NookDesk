import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedTab: MainTab = .writing

    private var isProjectConfigured: Bool {
        let path = viewModel.project.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty && path != FileManager.default.currentDirectoryPath
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
            NookSidebar(
                selectedTab: $selectedTab,
                statusText: viewModel.statusText,
                isBusy: viewModel.isBusy,
                lastPublishText: lastPublishDisplayText
            )

            Rectangle()
                .fill(Color(red: 0.847, green: 0.816, blue: 0.765))
                .frame(width: 1)

            VStack(spacing: 0) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomStatusBar
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .writing:
            WritingView(viewModel: viewModel)
        case .publish:
            PublishView(viewModel: viewModel)
        case .settings:
            SettingsView(viewModel: viewModel)
        }
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isBusy ? Color.aiWarning : Color.aiSuccess)
                    .frame(width: 8, height: 8)
                Text(viewModel.isBusy ? "处理中" : "就绪")
                    .font(.custom("Nunito-Medium", size: 11))
                    .foregroundColor(.aiTextSecondary)
            }

            Rectangle()
                .fill(Color.aiBorderLight)
                .frame(width: 1, height: 16)

            Text(viewModel.statusText)
                .font(.custom("Nunito-Regular", size: 11))
                .foregroundColor(.aiTextMuted)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if !lastPublishDisplayText.isEmpty {
                Text(lastPublishDisplayText)
                    .font(.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.aiTextMuted)
                    .lineLimit(1)
            }

            if viewModel.isBusy {
                ProgressView()
                    .controlSize(.mini)
            }

            Text("v\(AppVersion.current)")
                .font(.custom("Nunito-Regular", size: 10))
                .foregroundColor(.aiTextDisabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.aiSecondaryBg)
    }

    private var lastPublishDisplayText: String {
        if let last = viewModel.publishLogEntries.last(where: { $0.operation.contains("发布") || $0.operation.contains("推送") }) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "MM-dd HH:mm"
            return "上次发布：\(formatter.string(from: last.timestamp))"
        }
        return ""
    }
}
