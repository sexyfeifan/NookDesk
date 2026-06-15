import AppKit
import SwiftUI

struct PublishView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showPublishProgress = false
    @State private var stepResults: [Int: StepResult] = [:]
    @State private var runningStep: Int?
    @State private var showAdvanced = false
    @State private var expandedLogIDs: Set<UUID> = []
    @State private var showRawLog = false

    enum StepStatus {
        case pending, running, success, failed
    }

    struct StepResult {
        var status: StepStatus
        var message: String
    }

    private let steps: [(name: String, description: String)] = [
        ("检查项目状态", "验证博客项目配置是否完整"),
        ("提交并推送", "将所有修改推送到 GitHub"),
        ("等待部署", "GitHub Actions 自动构建并部署"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                guideHeader

                NookWaveDivider()

                stepCardsSection

                NookWaveDivider()

                publishButtonSection

                NookWaveDivider()

                advancedSection

                NookWaveDivider()

                logSection
            }
            .padding()
        }
        .sheet(isPresented: $showPublishProgress) {
            PublishProgressSheet(
                entries: viewModel.publishLogEntries,
                publishLog: viewModel.publishLog,
                onClose: { showPublishProgress = false }
            )
        }
    }

    // MARK: - Guide Header

    private var guideHeader: some View {
        NookCard(color: .appGreen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("📝")
                        .font(.system(size: 24))
                    Text("发布指南")
                        .font(.custom("Nunito-Black", size: 22))
                        .foregroundColor(.aiTextHeader)
                }

                Text("发布文章到你的博客需要以下步骤：")
                    .font(.custom("Nunito-Medium", size: 14))
                    .foregroundColor(.aiTextSecondary)
            }
        }
    }

    // MARK: - Step Cards

    private var stepCardsSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                stepCard(index: index, name: step.name, description: step.description)
            }
        }
    }

    private func stepCard(index: Int, name: String, description: String) -> some View {
        let result = stepResults[index]
        let status = result?.status ?? .pending

        return NookCard(color: colorForStepStatus(status)) {
            HStack(spacing: 12) {
                Text(stepNumberEmoji(index))
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Step \(index + 1): \(name)")
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(.aiTextHeader)
                    Text("→ \(description)")
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextSecondary)
                    if let msg = result?.message, !msg.isEmpty {
                        Text(msg)
                            .font(.custom("Nunito-Regular", size: 11))
                            .foregroundColor(status == .failed ? .aiError : .aiTextMuted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                stepStatusIcon(status)

                NookButton(.default, size: .small, label: "检查") {
                    runStep(index)
                }
                .disabled(runningStep != nil || viewModel.isBusy)
            }
        }
    }

    private func stepNumberEmoji(_ index: Int) -> String {
        switch index {
        case 0: return "📋"
        case 1: return "🚀"
        case 2: return "⏳"
        default: return "📌"
        }
    }

    @ViewBuilder
    private func stepStatusIcon(_ status: StepStatus) -> some View {
        switch status {
        case .pending:
            Text("⏳")
                .font(.system(size: 16))
        case .running:
            ProgressView()
                .controlSize(.small)
        case .success:
            Text("✅")
                .font(.system(size: 16))
        case .failed:
            Text("❌")
                .font(.system(size: 16))
        }
    }

    private func colorForStepStatus(_ status: StepStatus) -> NookColor {
        switch status {
        case .pending: return .nookDefault
        case .running: return .appBlue
        case .success: return .appGreen
        case .failed:  return .appRed
        }
    }

    // MARK: - Publish Button

    private var publishButtonSection: some View {
        NookCard(color: .appGreen) {
            VStack(spacing: 12) {
                Text("一键发布将依次执行以上所有步骤。")
                    .font(.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.aiTextSecondary)

                TextField("提交信息", text: $viewModel.publishMessage)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 600)

                NookButton(.primary, size: .large, icon: "paperplane.fill", label: "一键发布") {
                    showPublishProgress = true
                    viewModel.runGuidedPublishWorkflow()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.isBusy)

                if viewModel.isBusy {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("发布中...")
                            .font(.custom("Nunito-Medium", size: 13))
                            .foregroundColor(.aiTextSecondary)
                    }
                }

                if let run = viewModel.latestWorkflowStatus {
                    VStack(spacing: 6) {
                        Text("已推送到 GitHub")
                            .font(.custom("Nunito-Bold", size: 14))
                            .foregroundColor(.aiSuccess)
                        Text("GitHub Actions 正在部署...")
                            .font(.custom("Nunito-Medium", size: 12))
                            .foregroundColor(.aiTextSecondary)
                        if let url = URL(string: run.htmlURL) {
                            Link("查看 Actions 部署状态", destination: url)
                                .font(.custom("Nunito-SemiBold", size: 12))
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        NookCard(color: .appOrange) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(NookAnimations.nookEase) {
                        showAdvanced.toggle()
                    }
                } label: {
                    HStack {
                        Text("高级选项")
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(.aiTextHeader)
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.aiTextSecondary)
                    }
                }
                .buttonStyle(.plain)

                if showAdvanced {
                    NookDivider()
                    advancedContent
                }
            }
        }
    }

    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            advancedSubSection("同步远端") {
                HStack(spacing: 10) {
                    NookButton(.default, size: .small, label: "同步远端") {
                        viewModel.runSyncWithRemote()
                    }
                    NookButton(.default, size: .small, label: "提交并推送") {
                        viewModel.runPublish()
                    }
                    NookButton(.default, size: .small, label: "部署状态") {
                        viewModel.refreshActionsStatus()
                    }
                    Spacer()
                }
            }

            advancedSubSection("Workflow 管理") {
                HStack(spacing: 10) {
                    NookButton(.default, size: .small, label: "生成 Workflow") {
                        viewModel.bootstrapGitHubPagesWorkflow()
                    }
                    NookButton(.default, size: .small, label: "检查 Pages 来源") {
                        viewModel.refreshPagesSourceStatus()
                    }
                    NookButton(.default, size: .small, label: "修复 Pages 来源") {
                        viewModel.repairPagesSourceToWorkflow()
                    }
                    Spacer()
                }
            }

            advancedSubSection("环境诊断") {
                HStack(spacing: 10) {
                    NookButton(.default, size: .small, label: "一键检测推送能力") {
                        viewModel.runEnvironmentDiagnostics()
                    }
                    Spacer()
                }
            }

            if let run = viewModel.latestWorkflowStatus {
                advancedSubSection("最新 Actions 运行") {
                    VStack(alignment: .leading, spacing: 6) {
                        statusRow("Workflow", run.name)
                        statusRow("分支", run.branch)
                        statusRow("提交", String(run.sha.prefix(10)))
                        statusRow("状态", run.statusText)
                        statusRow("创建时间", run.createdAtLocalText)
                        statusRow("更新时间", run.updatedAtLocalText)
                        if let url = URL(string: run.htmlURL) {
                            Link("打开运行详情", destination: url)
                                .font(.custom("Nunito-SemiBold", size: 12))
                        }
                    }
                }
            }

            if let site = viewModel.pagesSiteStatus {
                advancedSubSection("Pages 构建来源") {
                    VStack(alignment: .leading, spacing: 6) {
                        statusRow("build_type", site.buildType)
                        statusRow("source", site.sourceDescription)
                        statusRow("地址", site.htmlURL)
                        if site.buildType.lowercased() != "workflow" {
                            StatusBadge(text: "非 workflow 模式", level: .warning)
                        } else {
                            StatusBadge(text: "workflow 模式", level: .ok)
                        }
                    }
                }
            }
        }
    }

    private func advancedSubSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Nunito-SemiBold", size: 14))
                .foregroundColor(.aiTextHeader)
            content()
        }
    }

    private func statusRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.custom("Nunito-Medium", size: 12))
                .foregroundColor(.aiTextSecondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.custom("Nunito-Medium", size: 12))
                .foregroundColor(.aiTextBody)
                .textSelection(.enabled)
        }
    }

    // MARK: - Log Section

    private var logSection: some View {
        NookCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("日志输出")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)
                    Spacer()
                    NookButton(.default, size: .small, label: "清空") {
                        viewModel.clearPublishLogs()
                        expandedLogIDs.removeAll()
                    }
                    NookButton(.default, size: .small, label: "复制") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(viewModel.publishLog, forType: .string)
                    }
                    Text("共 \(viewModel.publishLogEntries.count) 条")
                        .font(.custom("Nunito-Regular", size: 11))
                        .foregroundColor(.aiTextMuted)
                }

                if viewModel.publishLogEntries.isEmpty {
                    Text("暂无日志。执行发布操作后会在这里显示。")
                        .font(.custom("Nunito-Regular", size: 13))
                        .foregroundColor(.aiTextMuted)
                } else {
                    DisclosureGroup("完整原始日志", isExpanded: $showRawLog) {
                        ScrollView([.vertical, .horizontal]) {
                            Text(viewModel.publishLog.isEmpty ? "暂无输出" : viewModel.publishLog)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                        }
                        .frame(minHeight: 100, maxHeight: 180)
                        .background(Color.aiBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(viewModel.publishLogEntries.reversed())) { entry in
                                DisclosureGroup(isExpanded: bindingForLog(id: entry.id)) {
                                    ScrollView(.horizontal) {
                                        Text(entry.details.isEmpty ? "无详细输出" : entry.details)
                                            .font(.system(.caption, design: .monospaced))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.top, 6)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: logIcon(for: entry.level))
                                            .foregroundColor(logColor(for: entry.level))
                                        Text("[\(entry.timestamp.formatted(date: .omitted, time: .standard))]")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.aiPrimary)
                                        Text(entry.operation)
                                            .font(.custom("Nunito-SemiBold", size: 12))
                                            .foregroundColor(.aiTextHeader)
                                        Text(entry.summary)
                                            .font(.custom("Nunito-Regular", size: 12))
                                            .foregroundColor(.aiTextSecondary)
                                        Spacer()
                                    }
                                }
                                .padding(8)
                                .background(Color.aiBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(minHeight: 200, maxHeight: 360)
                }
            }
        }
    }

    // MARK: - Step Execution

    private func runStep(_ index: Int) {
        runningStep = index
        stepResults[index] = StepResult(status: .running, message: "检查中...")

        Task {
            defer { runningStep = nil }

            do {
                let result = try await executeStep(index)
                stepResults[index] = StepResult(status: .success, message: result)
            } catch {
                stepResults[index] = StepResult(status: .failed, message: error.localizedDescription)
            }
        }
    }

    @MainActor
    private func executeStep(_ index: Int) async throws -> String {
        switch index {
        case 0:
            let report = viewModel.preflightChecks()
            let critical = report.filter { $0.level == .error }
            if critical.isEmpty {
                let okCount = report.filter { $0.level == .ok }.count
                return "项目配置正常（\(okCount)/\(report.count) 项通过）。"
            } else {
                let failed = critical.map { $0.title }.joined(separator: ", ")
                throw NSError(domain: "PublishStep", code: 0, userInfo: [NSLocalizedDescriptionKey: "缺少：\(failed)"])
            }

        case 1:
            viewModel.runPublish()
            return "提交并推送操作已启动。"

        case 2:
            viewModel.refreshActionsStatus()
            if let run = viewModel.latestWorkflowStatus {
                return "最新状态：\(run.statusText)"
            }
            return "正在查询 Actions 状态..."

        default:
            throw NSError(domain: "PublishStep", code: 99, userInfo: [NSLocalizedDescriptionKey: "未知步骤"])
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

// MARK: - Publish Progress Sheet

private struct PublishProgressSheet: View {
    let entries: [PublishLogEntry]
    let publishLog: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("发布进度")
                    .font(.custom("Nunito-Bold", size: 18))
                    .foregroundColor(.aiTextHeader)
                Spacer()
                NookButton(.default, size: .small, label: "复制全部日志") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(publishLog, forType: .string)
                }
                NookButton(.default, size: .small, label: "关闭") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }

            if entries.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在准备发布...")
                        .font(.custom("Nunito-Medium", size: 13))
                        .foregroundColor(.aiTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { entry in
                            HStack(spacing: 8) {
                                Text(iconForLevel(entry.level))
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.operation)
                                        .font(.custom("Nunito-SemiBold", size: 12))
                                        .foregroundColor(.aiTextHeader)
                                    Text(entry.summary)
                                        .font(.custom("Nunito-Regular", size: 11))
                                        .foregroundColor(.aiTextSecondary)
                                }
                                Spacer()
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.custom("Nunito-Regular", size: 10))
                                    .foregroundColor(.aiTextMuted)
                            }
                            .padding(8)
                            .background(Color.aiBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 340)
    }

    private func iconForLevel(_ level: PublishLogEntry.Level) -> String {
        switch level {
        case .info:    return "ℹ️"
        case .success: return "✅"
        case .warning: return "⚠️"
        case .error:   return "❌"
        }
    }
}
