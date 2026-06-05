import AppKit
import SwiftUI

struct PublishView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showAdvanced = false
    @State private var expandedLogIDs: Set<UUID> = []
    @State private var selectedPreflightCheck: PublishCheck?
    @State private var showRawLog = false
    @State private var showPublishProgress = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                publishHeroCard

                NookWaveDivider()

                statusCardsRow

                NookWaveDivider()

                preflightSection

                NookWaveDivider()

                advancedSection

                NookWaveDivider()

                logSection
            }
            .padding()
        }
        .sheet(item: $selectedPreflightCheck) { check in
            PreflightDetailSheet(check: check)
        }
        .sheet(isPresented: $showPublishProgress) {
            PublishProgressSheet(
                entries: viewModel.publishLogEntries,
                publishLog: viewModel.publishLog,
                onClose: { showPublishProgress = false }
            )
        }
    }

    // MARK: - Hero Publish Button

    private var publishHeroCard: some View {
        NookCard(color: .appGreen) {
            VStack(spacing: 16) {
                NookIcon.helicopter.image
                    .font(.system(size: 36))
                    .foregroundColor(.aiPrimary)

                Text("一键发布")
                    .font(.custom("Nunito-Black", size: 22))
                    .foregroundColor(.aiTextHeader)

                Text("自动执行：结构检查 → 保存内容 → Workflow/Pages → 暂存 → 提交推送 → 部署状态")
                    .font(.custom("Nunito-Medium", size: 13))
                    .foregroundColor(.aiTextSecondary)
                    .multilineTextAlignment(.center)

                TextField("提交信息", text: $viewModel.publishMessage)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)

                NookButton(.primary, size: .large, label: "发布") {
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
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status Cards

    private var statusCardsRow: some View {
        HStack(spacing: 12) {
            statusCard(
                title: "最近构建",
                value: viewModel.lastStructureReport?.hasMissingItems == false ? "结构正常" : "未检测",
                level: viewModel.lastStructureReport?.hasMissingItems == false ? .ok : .info,
                icon: "hammer.fill"
            )

            statusCard(
                title: "推送状态",
                value: publishStatusText,
                level: publishStatusLevel,
                icon: "arrow.up.circle.fill"
            )

            statusCard(
                title: "Actions",
                value: actionsStatusText,
                level: actionsStatusLevel,
                icon: "gearshape.2.fill"
            )

            statusCard(
                title: "Pages 来源",
                value: pagesStatusText,
                level: pagesStatusLevel,
                icon: "doc.text.fill"
            )
        }
    }

    private func statusCard(title: String, value: String, level: StatusBadgeLevel, icon: String) -> some View {
        NookCard(color: nookColorForLevel(level)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(colorForLevel(level))
                    Text(title)
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundColor(.aiTextSecondary)
                }
                Text(value)
                    .font(.custom("Nunito-Bold", size: 14))
                    .foregroundColor(.aiTextHeader)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Preflight Section

    private var preflightSection: some View {
        NookCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("发布前检查")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(.aiTextHeader)

                LazyVGrid(columns: [
                    GridItem(.flexible(minimum: 160), spacing: 8),
                    GridItem(.flexible(minimum: 160), spacing: 8)
                ], alignment: .leading, spacing: 8) {
                    ForEach(viewModel.preflightChecks()) { check in
                        Button {
                            selectedPreflightCheck = check
                        } label: {
                            HStack(spacing: 8) {
                                StatusBadge(text: check.title, level: statusLevelForCheck(check))
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.aiBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
            advancedSection("同步远端") {
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

            advancedSection("Workflow 管理") {
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

            advancedSection("环境诊断") {
                HStack(spacing: 10) {
                    NookButton(.default, size: .small, label: "一键检测推送能力") {
                        viewModel.runEnvironmentDiagnostics()
                    }
                    Spacer()
                }
            }

            if let run = viewModel.latestWorkflowStatus {
                advancedSection("最新 Actions 运行") {
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
                advancedSection("Pages 构建来源") {
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

    private func advancedSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    // MARK: - Helpers

    private var publishStatusText: String {
        if viewModel.isBusy { return "发布中..." }
        if let last = viewModel.publishLogEntries.last(where: { $0.operation.contains("发布") || $0.operation.contains("推送") }) {
            return last.summary
        }
        return "未发布"
    }

    private var publishStatusLevel: StatusBadgeLevel {
        if viewModel.isBusy { return .info }
        if let last = viewModel.publishLogEntries.last(where: { $0.operation.contains("发布") || $0.operation.contains("推送") }) {
            switch last.level {
            case .success: return .ok
            case .warning: return .warning
            case .error:   return .error
            case .info:    return .info
            }
        }
        return .info
    }

    private var actionsStatusText: String {
        if let run = viewModel.latestWorkflowStatus {
            return run.statusText
        }
        if !viewModel.latestWorkflowError.isEmpty {
            return "查询失败"
        }
        return "未查询"
    }

    private var actionsStatusLevel: StatusBadgeLevel {
        guard let run = viewModel.latestWorkflowStatus else {
            return viewModel.latestWorkflowError.isEmpty ? .info : .error
        }
        if run.statusText.lowercased().contains("success") || run.statusText.lowercased().contains("completed") {
            return .ok
        }
        if run.statusText.lowercased().contains("fail") {
            return .error
        }
        return .warning
    }

    private var pagesStatusText: String {
        if let site = viewModel.pagesSiteStatus {
            return site.buildType.lowercased() == "workflow" ? "workflow" : site.buildType
        }
        if !viewModel.pagesSiteError.isEmpty { return "检测失败" }
        return "未检测"
    }

    private var pagesStatusLevel: StatusBadgeLevel {
        guard let site = viewModel.pagesSiteStatus else {
            return viewModel.pagesSiteError.isEmpty ? .info : .warning
        }
        return site.buildType.lowercased() == "workflow" ? .ok : .warning
    }

    private func nookColorForLevel(_ level: StatusBadgeLevel) -> NookColor {
        switch level {
        case .ok:      return .appGreen
        case .warning: return .appYellow
        case .error:   return .appRed
        case .info:    return .appBlue
        }
    }

    private func colorForLevel(_ level: StatusBadgeLevel) -> Color {
        switch level {
        case .ok:      return .aiSuccess
        case .warning: return .aiWarning
        case .error:   return .aiError
        case .info:    return .aiPrimary
        }
    }

    private func statusLevelForCheck(_ check: PublishCheck) -> StatusBadgeLevel {
        switch check.level {
        case .ok:      return .ok
        case .warning: return .warning
        case .error:   return .error
        }
    }

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

// MARK: - Preflight Detail Sheet

private struct PreflightDetailSheet: View {
    let check: PublishCheck
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(text: check.title, level: statusLevel)
                Spacer()
                Text(statusText)
                    .font(.custom("Nunito-SemiBold", size: 12))
                    .foregroundColor(statusColor)
            }

            ScrollView {
                Text(check.detail)
                    .font(.custom("Nunito-Medium", size: 13))
                    .foregroundColor(.aiTextBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(Color.aiBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Spacer()
                NookButton(.default, size: .medium, label: "关闭") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 260)
    }

    private var statusLevel: StatusBadgeLevel {
        switch check.level {
        case .ok:      return .ok
        case .warning: return .warning
        case .error:   return .error
        }
    }

    private var statusText: String {
        switch check.level {
        case .ok:      return "正常"
        case .warning: return "需要关注"
        case .error:   return "存在问题"
        }
    }

    private var statusColor: Color {
        switch check.level {
        case .ok:      return .aiSuccess
        case .warning: return .aiWarning
        case .error:   return .aiError
        }
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
