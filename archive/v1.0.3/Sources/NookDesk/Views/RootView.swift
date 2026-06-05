import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedTab: MainTab = .writing

    private var isProjectConfigured: Bool {
        let path = viewModel.project.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return false }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        // 必须有有效的博客项目配置文件
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
            NookSidebar(
                selectedTab: $selectedTab
            )

            Rectangle()
                .fill(Color(red: 0.847, green: 0.816, blue: 0.765))
                .frame(width: 1)

            VStack(spacing: 0) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                NookFooter(style: .sea)

                bottomStatusBar
            }
        }
        .overlay {
            if viewModel.isBusy {
                NookLoadingOverlay(message: viewModel.statusText.isEmpty ? "处理中..." : viewModel.statusText)
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
        VStack(spacing: 4) {
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

            let recentEntries = Array(viewModel.publishLogEntries.suffix(3))
            if !recentEntries.isEmpty {
                HStack(spacing: 8) {
                    ForEach(recentEntries) { entry in
                        HStack(spacing: 4) {
                            Text(iconForLogLevel(entry.level))
                                .font(.caption2)
                            Text(entry.operation)
                                .font(.caption2)
                                .foregroundColor(.aiTextBody)
                                .lineLimit(1)
                            Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(.aiTextMuted)
                        }
                        if entry.id != recentEntries.last?.id {
                            Rectangle()
                                .fill(Color.aiBorderLight)
                                .frame(width: 1, height: 12)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 80)
        .background(Color.aiSecondaryBg)
    }

    private func iconForLogLevel(_ level: PublishLogEntry.Level) -> String {
        switch level {
        case .info:    return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error:   return "❌"
        }
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
