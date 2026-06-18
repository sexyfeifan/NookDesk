import AppKit
import SwiftUI

struct PublishView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var expandedLogIDs: Set<UUID> = []
    @State private var cachedPreflightChecks: [PreflightCheck] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                publishHeader
                preflightSection
                statusSection
                publishActionSection
                logSection
            }
            .padding(24)
        }
        .onAppear { cachedPreflightChecks = computePreflightChecks() }
        .onChange(of: viewModel.publishRemoteURL) { _ in cachedPreflightChecks = computePreflightChecks() }
        .onChange(of: viewModel.githubTokenUsageSummary) { _ in cachedPreflightChecks = computePreflightChecks() }
        .onChange(of: viewModel.posts.count) { _ in cachedPreflightChecks = computePreflightChecks() }
        .onChange(of: viewModel.posts.map(\.draft)) { _ in cachedPreflightChecks = computePreflightChecks() }
    }

    // MARK: - Preflight Check

    private var preflightSection: some View {
        let hasErrors = cachedPreflightChecks.contains { $0.level == .error }
        let color: NookColor = hasErrors ? .appRed : .appGreen

        return NookCard(color: color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("发布前检查")
                        .font(.custom("Nunito-Bold", size: 15))
                        .foregroundColor(.aiTextHeader)
                    Spacer()
                    if !hasErrors {
                        StatusBadge(text: "全部通过", level: .ok)
                    } else {
                        StatusBadge(text: "存在问题", level: .error)
                    }
                }
                NookDivider()

                ForEach(cachedPreflightChecks) { check in
                    HStack(spacing: 8) {
                        Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(check.passed ? .aiSuccess : (check.level == .warning ? .aiWarning : .aiError))
                            .font(.system(size: 12))
                        Text(check.name)
                            .font(.custom("Nunito-Medium", size: 12))
                            .foregroundColor(.aiTextBody)
                        Spacer()
                        Text(check.passed ? "通过" : check.message)
                            .font(.custom("Nunito-Regular", size: 11))
                            .foregroundColor(check.passed ? .aiTextMuted : .aiError)
                    }
                }

                // Change summary
                NookDivider()
                let draftCount = viewModel.posts.filter(\.draft).count
                let publishedCount = viewModel.posts.count - draftCount
                HStack(spacing: 16) {
                    changeSummaryBadge(icon: "doc.text", label: "文章总数", value: "\(viewModel.posts.count)")
                    changeSummaryBadge(icon: "checkmark.circle", label: "已发布", value: "\(publishedCount)")
                    changeSummaryBadge(icon: "pencil.circle", label: "草稿", value: "\(draftCount)")
                }
            }
        }
    }

    private func changeSummaryBadge(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.aiTextMuted)
            Text("\(label): ")
                .font(.custom("Nunito-Regular", size: 11))
                .foregroundColor(.aiTextMuted)
            Text(value)
                .font(.custom("Nunito-Bold", size: 11))
                .foregroundColor(.aiTextBody)
        }
    }

    private struct PreflightCheck: Identifiable {
        let id = UUID()
        let name: String
        let passed: Bool
        let message: String
        let level: PublishLogEntry.Level
    }

    private func computePreflightChecks() -> [PreflightCheck] {
        var checks: [PreflightCheck] = []

        let hasRemote = !viewModel.publishRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        checks.append(PreflightCheck(name: "远程仓库", passed: hasRemote, message: "未配置", level: .error))

        let hasToken = !viewModel.githubTokenUsageSummary.contains("未配置")
        checks.append(PreflightCheck(name: "GitHub Token", passed: hasToken, message: "未配置", level: .error))

        let isGitRepo = FileManager.default.fileExists(atPath: viewModel.project.rootURL.appendingPathComponent(".git").path)
        checks.append(PreflightCheck(name: "Git 仓库", passed: isGitRepo, message: "不是 Git 仓库", level: .error))

        let hasWorkflow = viewModel.hasGitHubPagesWorkflow
        checks.append(PreflightCheck(name: "Pages Workflow", passed: hasWorkflow, message: "未检测到", level: .warning))

        let draftCount = viewModel.posts.filter(\.draft).count
        if draftCount > 0 {
            checks.append(PreflightCheck(name: "草稿文章", passed: false, message: "有 \(draftCount) 篇草稿", level: .info))
        } else {
            checks.append(PreflightCheck(name: "草稿文章", passed: true, message: "", level: .info))
        }

        return checks
    }

    // MARK: - Header

    private var publishHeader: some View {
        HStack(spacing: 10) {
            Text("🚀")
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text("发布博客")
                    .font(.custom("Nunito-Black", size: 22))
                    .foregroundColor(.aiTextHeader)
                Text("检查配置 → 提交推送 → 等待部署完成")
                    .font(.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.aiTextSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        NookCard(color: .appGreen) {
            VStack(alignment: .leading, spacing: 12) {
                Text("环境状态")
                    .font(.custom("Nunito-Bold", size: 15))
                    .foregroundColor(.aiTextHeader)

                NookDivider()

                statusRow("项目路径", viewModel.project.rootPath, icon: "folder.fill")
                statusRow("后端类型", viewModel.project.backendName, icon: "cube.fill")
                statusRow("远程仓库", viewModel.publishRemoteURL.isEmpty ? "未配置" : viewModel.publishRemoteURL, icon: "network")
                statusRow("GitHub Token", viewModel.githubTokenUsageSummary, icon: "key.fill")

                if let run = viewModel.latestWorkflowStatus {
                    NookDivider()
                    statusRow("Actions 状态", run.statusText, icon: "bolt.fill")
                    if let url = URL(string: run.htmlURL) {
                        Link("查看部署详情 →", destination: url)
                            .font(.custom("Nunito-SemiBold", size: 12))
                            .foregroundColor(.aiPrimary)
                    }
                }

                HStack(spacing: 8) {
                    NookButton(.default, size: .small, label: "刷新状态") {
                        viewModel.refreshActionsStatus()
                        viewModel.refreshPagesSourceStatus()
                    }
                    NookButton(.default, size: .small, label: "环境诊断") {
                        viewModel.runEnvironmentDiagnostics()
                    }
                    Spacer()
                }
            }
        }
    }

    private func statusRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.aiPrimary)
                .frame(width: 16)
            Text(label)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.custom("Nunito-Regular", size: 12))
                .foregroundColor(.aiTextBody)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
    }

    // MARK: - Publish Action

    private var publishActionSection: some View {
        NookCard(color: .appBlue) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Text("提交信息")
                        .font(.custom("Nunito-SemiBold", size: 13))
                        .foregroundColor(.aiTextSecondary)
                    TextField("通过 NookDesk 发布博客更新", text: $viewModel.publishMessage)
                        .textFieldStyle(.roundedBorder)
                        .font(.custom("Nunito-Regular", size: 13))
                }

                NookButton(.primary, size: .large, icon: "paperplane.fill", label: "一键发布") {
                    viewModel.runGuidedPublishWorkflow()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isBusy)

                if viewModel.isBusy {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(viewModel.statusText)
                            .font(.custom("Nunito-Medium", size: 13))
                            .foregroundColor(.aiTextSecondary)
                    }
                }

                NookDivider()

                HStack(spacing: 8) {
                    NookButton(.default, size: .small, label: "同步远端") {
                        viewModel.runSyncWithRemote()
                    }
                    NookButton(.default, size: .small, label: "仅提交推送") {
                        viewModel.runPublish()
                    }
                    NookButton(.default, size: .small, label: "生成 Workflow") {
                        viewModel.bootstrapGitHubPagesWorkflow()
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Log Section

    private var logSection: some View {
        NookCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("发布日志")
                        .font(.custom("Nunito-Bold", size: 15))
                        .foregroundColor(.aiTextHeader)
                    Spacer()
                    Text("\(viewModel.publishLogEntries.count) 条")
                        .font(.custom("Nunito-Regular", size: 11))
                        .foregroundColor(.aiTextMuted)
                    NookButton(.default, size: .small, label: "清空") {
                        viewModel.clearPublishLogs()
                        expandedLogIDs.removeAll()
                    }
                    NookButton(.default, size: .small, label: "复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.publishLog, forType: .string)
                    }
                }

                if viewModel.publishLogEntries.isEmpty {
                    Text("暂无日志。点击「一键发布」后会在这里显示。")
                        .font(.custom("Nunito-Regular", size: 13))
                        .foregroundColor(.aiTextMuted)
                        .padding(.vertical, 12)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(viewModel.publishLogEntries.reversed()) { entry in
                                DisclosureGroup(isExpanded: bindingForLog(id: entry.id)) {
                                    ScrollView(.horizontal) {
                                        Text(entry.details.isEmpty ? "无详细输出" : entry.details)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.top, 4)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: logIcon(for: entry.level))
                                            .foregroundColor(logColor(for: entry.level))
                                            .font(.system(size: 11))
                                        Text(entry.operation)
                                            .font(.custom("Nunito-SemiBold", size: 12))
                                            .foregroundColor(.aiTextHeader)
                                        Text(entry.summary)
                                            .font(.custom("Nunito-Regular", size: 11))
                                            .foregroundColor(.aiTextSecondary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                            .font(.custom("Nunito-Regular", size: 10))
                                            .foregroundColor(.aiTextMuted)
                                    }
                                }
                                .padding(8)
                                .background(Color.aiBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
    }

    // MARK: - Helpers

    private func logIcon(for level: PublishLogEntry.Level) -> String {
        switch level {
        case .info:    return "info.circle"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error:   return "xmark.octagon.fill"
        }
    }

    private func logColor(for level: PublishLogEntry.Level) -> Color {
        switch level {
        case .info:    return .aiPrimary
        case .success: return .aiSuccess
        case .warning: return .aiWarning
        case .error:   return .aiError
        }
    }

    private func bindingForLog(id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedLogIDs.contains(id) },
            set: { isExpanded in
                if isExpanded { expandedLogIDs.insert(id) }
                else { expandedLogIDs.remove(id) }
            }
        )
    }
}
