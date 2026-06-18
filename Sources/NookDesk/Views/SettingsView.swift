import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var expandedSections: Set<String> = ["project", "github"]
    @State private var customCSSInput = ""
    @State private var customJSInput = ""
    @State private var aiTestResponseTime: String?
    @State private var scaffoldRemoteURL = ProjectScaffoldingService.defaultTemplateURL
    @State private var scaffoldInProgress = false
    @State private var scaffoldResult: String?
    @State private var scaffoldLog: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NookCard(color: .appGreen) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("版本与更新")
                            .font(.custom("Nunito-Bold", size: 18))
                            .foregroundColor(.aiTextHeader)
                        NookDivider()

                        HStack(spacing: 8) {
                            Text("当前版本：")
                                .font(.custom("Nunito-SemiBold", size: 13))
                                .foregroundColor(.aiTextSecondary)
                            Text("v\(AppVersion.current)")
                                .font(.custom("Nunito-Bold", size: 16))
                                .foregroundColor(.aiPrimary)
                        }

                        HStack(spacing: 10) {
                            NookButton(.default, size: .small, label: "检查更新") {
                                Task { await viewModel.checkForUpdates() }
                            }
                            .disabled(viewModel.isCheckingUpdate)

                            if viewModel.isCheckingUpdate {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            if let update = viewModel.updateInfo {
                                NookButton(.primary, size: .small, label: "一键更新 v\(update.version)") {
                                    Task { await viewModel.downloadUpdate() }
                                }
                            }

                            Spacer()
                        }

                        if let update = viewModel.updateInfo {
                            StatusBadge(
                                text: "发现新版本 v\(update.version)",
                                level: .info
                            )
                        } else if !viewModel.isCheckingUpdate && viewModel.statusText.contains("最新版本") {
                            StatusBadge(text: "已是最新版本", level: .ok)
                        }
                    }
                }

                NookWaveDivider()

                sectionCard(
                    id: "project",
                    title: "项目设置",
                    color: .appBlue
                ) {
                    projectSection
                }

                NookWaveDivider()

                sectionCard(
                    id: "github",
                    title: "GitHub 设置",
                    color: .purple
                ) {
                    githubSection
                }

                NookWaveDivider()

                sectionCard(
                    id: "ai",
                    title: "AI 设置",
                    color: .appTeal
                ) {
                    aiSection
                }

                NookWaveDivider()

                sectionCard(
                    id: "theme",
                    title: "主题与站点",
                    color: .appPink
                ) {
                    themeSection
                }

                NookWaveDivider()

                sectionCard(
                    id: "advanced",
                    title: "高级",
                    color: .appOrange
                ) {
                    advancedSection
                }
            }
            .padding()
        }
        .onAppear {
            syncTextInputs()
        }
    }

    // MARK: - Collapsible Section Card

    private func sectionCard<Content: View>(
        id: String,
        title: String,
        color: NookColor,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        NookCard(color: color) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(NookAnimations.nookEase) {
                        if expandedSections.contains(id) {
                            expandedSections.remove(id)
                        } else {
                            expandedSections.insert(id)
                        }
                    }
                } label: {
                    HStack {
                        Text(title)
                            .font(.custom("Nunito-Bold", size: 18))
                            .foregroundColor(.aiTextHeader)
                        Spacer()
                        Image(systemName: expandedSections.contains(id) ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.aiTextSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expandedSections.contains(id) {
                    NookDivider()
                    content()
                }
            }
        }
    }

    // MARK: - Project Section

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsRow("博客根目录") {
                HStack(spacing: 8) {
                    NookInput("项目路径", text: $viewModel.project.rootPath)
                    NookButton(.default, size: .small, label: "选择") {
                        if let path = pickDirectory() {
                            viewModel.setProjectRootPath(path)
                        }
                    }
                    NookButton(.primary, size: .small, label: "应用") {
                        viewModel.setProjectRootPath(viewModel.project.rootPath)
                    }
                }
            }

            settingsRow("构建工具") {
                HStack(spacing: 8) {
                    Text(viewModel.project.backend.displayName)
                        .font(.custom("Nunito-SemiBold", size: 14))
                        .foregroundColor(.aiPrimary)
                }
            }

            settingsRow("文章目录") {
                NookInput("src/pages/Home", text: $viewModel.project.contentSubpath)
            }

            settingsRow("远程名称") {
                NookInput("origin", text: $viewModel.project.gitRemote)
            }

            settingsRow("发布分支") {
                NookInput("main", text: $viewModel.project.publishBranch)
            }

            HStack {
                NookButton(.default, size: .small, label: "重新加载项目") {
                    viewModel.loadAll()
                }
                Spacer()
                Text(viewModel.localConfigBundlePath)
                    .font(.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.aiTextMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - GitHub Section

    private var githubSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsRow("推送仓库地址") {
                NookInput("https://github.com/you/repo.git", text: $viewModel.publishRemoteURL)
            }

            settingsRow("Fine-grained Token") {
                SecureField("github_pat_xxx", text: $viewModel.githubFineGrainedToken)
                    .textFieldStyle(.roundedBorder)
            }

            settingsRow("Classic Token") {
                SecureField("ghp_xxx", text: $viewModel.githubClassicToken)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                NookButton(.primary, size: .small, label: "保存远程与令牌") {
                    viewModel.saveRemoteProfile()
                }
                Text("当前 Token：\(viewModel.githubTokenUsageSummary)")
                    .font(.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.aiTextSecondary)
                Spacer()
            }

            Text("配置会同步到项目根目录 .nookdesk.local.json，并写入系统 Keychain。")
                .font(.custom("Nunito-Regular", size: 11))
                .foregroundColor(.aiTextMuted)
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsRow("API 地址") {
                NookInput("https://api.openai.com/v1", text: $viewModel.aiBaseURL)
            }

            settingsRow("模型") {
                NookInput("gpt-4.1-mini", text: $viewModel.aiModel)
            }

            settingsRow("API Key") {
                SecureField("sk-...", text: $viewModel.aiAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                NookButton(.primary, size: .small, label: "保存 AI 设置") {
                    viewModel.saveAISettings()
                }

                NookButton(.default, size: .small, label: "测试连通性") {
                    Task {
                        aiTestResponseTime = nil
                        await viewModel.testAIConnectivity()
                        if let result = viewModel.aiTestResult, result.contains("耗时") {
                            aiTestResponseTime = result
                        }
                    }
                }
                .disabled(viewModel.isTestingAI)

                if viewModel.isTestingAI {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            if let testResult = viewModel.aiTestResult {
                StatusBadge(
                    text: testResult,
                    level: testResult.contains("成功") ? .ok : .error
                )
            }
        }
    }

    // MARK: - Theme Section

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            settingsRow("站点地址") {
                NookInput("https://example.com/", text: $viewModel.config.baseURL)
            }

            settingsRow("站点标题") {
                NookInput("站点标题", text: $viewModel.config.title)
            }

            settingsRow("语言代码") {
                NookInput("zh-cn", text: $viewModel.config.languageCode)
            }

            settingsRow("主题") {
                HStack(spacing: 8) {
                    Picker("", selection: themeSelectionBinding) {
                        ForEach(themeOptions, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    NookButton(.default, size: .small, label: "刷新") {
                        viewModel.refreshDetectedThemes()
                    }
                }
            }

            if let detected = viewModel.selectedDetectedTheme {
                Text(detected.sourceDescription + " · " + detected.capabilitySummary)
                    .font(.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.aiTextMuted)
            }

            NookDivider()

            settingsRow("作者名") {
                NookInput("", text: $viewModel.config.params.author)
            }

            settingsRow("个人简介") {
                NookInput("", text: $viewModel.config.params.description)
            }

            settingsRow("GitHub 用户名") {
                NookInput("", text: $viewModel.config.params.github)
            }

            settingsRow("默认关键词") {
                NookInput("blog, tech, tools", text: $viewModel.config.params.keywords)
            }

            NookDivider()

            HStack {
                NookButton(.default, size: .small, label: "从配置重新读取") {
                    viewModel.loadAll()
                    syncTextInputs()
                }
                NookButton(.primary, size: .small, label: "保存主题配置") {
                    applyTextInputs()
                    viewModel.saveThemeConfig()
                }
                Spacer()
            }

            NookDivider()

            settingsRow("自定义 CSS") {
                TextEditor(text: $customCSSInput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 80)
                    .border(Color.aiBorderLight, width: 1)
            }

            settingsRow("自定义 JS") {
                TextEditor(text: $customJSInput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 80)
                    .border(Color.aiBorderLight, width: 1)
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            advancedGroup("检查项目状态") {
                HStack(spacing: 10) {
                    NookButton(.default, size: .small, label: "检查项目状态") {
                        viewModel.runStructureCheck()
                    }
                    Spacer()
                }

                if let report = viewModel.lastStructureReport {
                    StatusBadge(
                        text: report.hasMissingItems ? "存在缺失项" : "结构完整",
                        level: report.hasMissingItems ? .warning : .ok
                    )
                }
            }

            advancedGroup("从 GitHub 拉取") {
                VStack(alignment: .leading, spacing: 8) {
                    NookInput("GitHub 仓库 URL", text: $scaffoldRemoteURL)

                    HStack(spacing: 10) {
                        NookButton(.primary, size: .small, label: "拉取项目") {
                            scaffoldResult = nil
                            scaffoldInProgress = true
                            scaffoldLog = []
                            Task {
                                let result = await viewModel.cloneProjectFromGitHubWithProgress(
                                    url: scaffoldRemoteURL,
                                    log: { message in
                                        DispatchQueue.main.async {
                                            scaffoldLog.append(message)
                                        }
                                    }
                                )
                                scaffoldResult = result
                                scaffoldInProgress = false
                            }
                        }
                        .disabled(scaffoldInProgress)

                        if scaffoldInProgress {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Spacer()
                    }

                    if scaffoldInProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView()
                                .progressViewStyle(.linear)
                            Text("正在克隆并检测项目...")
                                .font(.custom("Nunito-Regular", size: 11))
                                .foregroundColor(.aiTextSecondary)
                        }
                    }

                    if !scaffoldLog.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(scaffoldLog.indices, id: \.self) { i in
                                Text(scaffoldLog[i])
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.aiTextMuted)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.aiBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let result = scaffoldResult {
                        StatusBadge(
                            text: result,
                            level: result.contains("完成") ? .ok : (result.contains("失败") ? .error : .info)
                        )
                    }
                }
            }

            advancedGroup("Workflow 管理") {
                VStack(alignment: .leading, spacing: 8) {
                    let workflowExists = viewModel.hasGitHubPagesWorkflow
                    HStack(spacing: 10) {
                        if workflowExists {
                            StatusBadge(text: "Workflow 已存在", level: .ok)
                        } else {
                            NookButton(.primary, size: .small, label: "生成 Workflow") {
                                viewModel.bootstrapGitHubPagesWorkflow()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func advancedGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Nunito-SemiBold", size: 14))
                .foregroundColor(.aiTextHeader)
            content()
        }
    }

    // MARK: - Helpers

    private func settingsRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
            content()
        }
    }

    private var themeOptions: [String] {
        var names = viewModel.detectedThemes.map(\.name)
        let current = viewModel.config.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty && !names.contains(where: { $0.lowercased() == current.lowercased() }) {
            names.append(current)
        }
        if names.isEmpty { names.append("github-style") }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var themeSelectionBinding: Binding<String> {
        Binding(
            get: {
                let current = viewModel.config.theme.trimmingCharacters(in: .whitespacesAndNewlines)
                return current.isEmpty ? (themeOptions.first ?? "github-style") : current
            },
            set: { viewModel.selectTheme(named: $0) }
        )
    }

    private func syncTextInputs() {
        customCSSInput = viewModel.config.params.customCSS.joined(separator: "\n")
        customJSInput = viewModel.config.params.customJS.joined(separator: "\n")
    }

    private func applyTextInputs() {
        viewModel.config.params.customCSS = customCSSInput
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        viewModel.config.params.customJS = customJSInput
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func pickDirectory() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
