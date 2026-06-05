import SwiftUI

struct WizardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var currentStep = 0
    @State private var projectPath: String = ""
    @State private var detectedBackendName: String = ""
    @State private var githubRemoteURL: String = ""
    @State private var githubBranch: String = "main"
    @State private var githubToken: String = ""
    @State private var isDetecting = false
    @State private var showTypewriter = false
    @State private var showCloneOption = false
    @State private var cloneURL: String = "https://github.com/sexyfeifan/sexyfeifan.github.io.git"
    @State private var clonePath: String = ""
    @State private var isCloning = false
    @State private var cloneError: String?
    @State private var cloneLog: [String] = []
    @State private var connectionTestResult: String?
    @State private var tokenTestResult: String?
    @State private var isTestingConnection = false
    @State private var isTestingToken = false
    @State private var wizardError: String?

    private let stepCount = 5
    private let stepDefaultsKey = "nookdesk.wizard.lastStep"

    var body: some View {
        ZStack {
            Color.aiBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                logoSection
                    .padding(.bottom, 32)

                wizardCard
                    .frame(maxWidth: 580)

                Spacer()
            }
        }
        .onAppear {
            loadSavedProgress()
        }
    }

    private var logoSection: some View {
        VStack(spacing: 12) {
            NookLeafIcon(size: 48)

            if showTypewriter {
                NookTypewriterText("NookDesk", typingSpeed: 0.06)
            } else {
                Text("NookDesk")
                    .font(.custom("Nunito-Black", size: 36))
                    .foregroundColor(.aiTextHeader)
                    .opacity(0)
            }

            Text("欢迎来到 NookDesk")
                .font(.custom("Nunito-Bold", size: 20))
                .foregroundColor(.aiTextBody)
                .opacity(showTypewriter ? 1 : 0)
                .animation(NookAnimations.nookEase.delay(0.8), value: showTypewriter)

            Text("你的博客写作与发布工作台")
                .font(.custom("Nunito-Medium", size: 14))
                .foregroundColor(.aiTextSecondary)
                .opacity(showTypewriter ? 1 : 0)
                .animation(NookAnimations.nookEase.delay(1.2), value: showTypewriter)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showTypewriter = true
            }
        }
    }

    private var wizardCard: some View {
        NookCard(color: cardColorForStep) {
            VStack(alignment: .leading, spacing: 20) {
                stepIndicator

                NookDivider()

                stepContent

                if let error = wizardError {
                    NookCard(color: .appRed) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.aiError)
                            Text(error)
                                .font(.custom("Nunito-Medium", size: 12))
                                .foregroundColor(.aiError)
                            Spacer()
                            NookButton(.default, size: .small, label: "重试") {
                                wizardError = nil
                                advanceStep()
                            }
                        }
                    }
                }

                NookDivider()

                HStack {
                    if currentStep > 0 {
                        NookButton(.default, size: .medium, label: "上一步") {
                            withAnimation(NookAnimations.nookEase) {
                                currentStep -= 1
                                saveProgress()
                            }
                        }
                    }

                    Spacer()

                    if currentStep == 0 {
                        NookButton(.primary, size: .large, label: "开始配置") {
                            withAnimation(NookAnimations.nookEase) {
                                currentStep = 1
                                saveProgress()
                            }
                        }
                    } else if currentStep < stepCount - 1 {
                        NookButton(.primary, size: .medium, label: "下一步") {
                            advanceStep()
                        }
                        .disabled(!canAdvance)
                    } else {
                        NookButton(.primary, size: .large, label: "进入 NookDesk") {
                            finishSetup()
                        }
                    }
                }
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<stepCount, id: \.self) { step in
                HStack(spacing: 4) {
                    Circle()
                        .fill(step <= currentStep ? Color.aiPrimary : Color.aiBorderLight)
                        .frame(width: 10, height: 10)
                    if step < stepCount - 1 {
                        Rectangle()
                            .fill(step < currentStep ? Color.aiPrimary : Color.aiBorderLight)
                            .frame(height: 2)
                            .frame(maxWidth: 30)
                    }
                }
            }
            Spacer()
            Text("步骤 \(currentStep + 1) / \(stepCount)")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 1: return !projectPath.isEmpty
        case 2: return !githubRemoteURL.isEmpty
        default: return true
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            stepWelcome
        case 1:
            stepProjectFolder
        case 2:
            stepGitHubRemote
        case 3:
            stepGitHubToken
        case 4:
            stepComplete
        default:
            EmptyView()
        }
    }

    // MARK: - Step 0: Welcome

    private var stepWelcome: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("欢迎使用 NookDesk")
                .font(.custom("Nunito-Bold", size: 20))
                .foregroundColor(.aiTextHeader)

            Text("NookDesk 是一个博客管理工作台，帮助你管理 animal-island-blog 项目，创建和编辑文章，并一键发布到 GitHub Pages。")
                .font(.custom("Nunito-Medium", size: 14))
                .foregroundColor(.aiTextBody)

            NookWaveDivider()

            VStack(alignment: .leading, spacing: 8) {
                featureRow("paintbrush.fill", "写作与编辑", "使用 Vditor 编辑器撰写 Markdown 文章")
                featureRow("icloud.fill", "发布与部署", "自动推送到 GitHub 并部署 Pages")
                featureRow("sparkles", "AI 写作助手", "辅助生成和排版文章内容")
            }
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.aiPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Nunito-SemiBold", size: 13))
                    .foregroundColor(.aiTextHeader)
                Text(desc)
                    .font(.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.aiTextSecondary)
            }
        }
    }

    // MARK: - Step 1: Choose Project

    private var stepProjectFolder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择项目")
                .font(.custom("Nunito-Bold", size: 18))
                .foregroundColor(.aiTextHeader)

            Text("选择你的博客项目根目录，或从 GitHub 克隆一个新项目。")
                .font(.custom("Nunito-Medium", size: 13))
                .foregroundColor(.aiTextSecondary)

            NookCard(color: .appBlue) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("选项 A：选择本地目录")
                        .font(.custom("Nunito-SemiBold", size: 14))
                        .foregroundColor(.aiTextHeader)

                    HStack(spacing: 8) {
                        NookInput("项目根目录路径", text: $projectPath)
                        NookButton(.default, size: .small, label: "选择文件夹") {
                            if let path = pickDirectory() {
                                projectPath = path
                                showCloneOption = false
                                cloneError = nil
                                cloneLog = []
                            }
                        }
                    }

                    if !projectPath.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.aiPrimary)
                            Text(projectPath)
                                .font(.custom("Nunito-Medium", size: 12))
                                .foregroundColor(.aiTextBody)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }

            NookWaveDivider()

            if !showCloneOption {
                NookButton(.ghost, size: .small, label: "没有项目？从 GitHub 克隆") {
                    showCloneOption = true
                }
            }

            if showCloneOption {
                NookCard(color: .appGreen) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("选项 B：从 GitHub 克隆")
                            .font(.custom("Nunito-SemiBold", size: 14))
                            .foregroundColor(.aiTextHeader)

                        NookInput("GitHub 仓库 URL", text: $cloneURL)

                        HStack(spacing: 8) {
                            NookInput("本地保存路径", text: $clonePath)
                            NookButton(.default, size: .small, label: "选择") {
                                if let path = pickDirectory() {
                                    clonePath = path
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            NookButton(.primary, size: .small, label: "克隆") {
                                runClone()
                            }
                            .disabled(isCloning || clonePath.isEmpty)

                            if isCloning {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Spacer()
                        }

                        if isCloning {
                            VStack(alignment: .leading, spacing: 4) {
                                ProgressView()
                                    .progressViewStyle(.linear)
                                Text("正在克隆并检测项目类型...")
                                    .font(.custom("Nunito-Regular", size: 11))
                                    .foregroundColor(.aiTextSecondary)
                            }
                        }

                        if !cloneLog.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(cloneLog.indices, id: \.self) { index in
                                    Text(cloneLog[index])
                                        .font(.custom("Nunito-Regular", size: 11))
                                        .foregroundColor(.aiTextMuted)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.aiBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if let error = cloneError {
                            Text(error)
                                .font(.custom("Nunito-Regular", size: 11))
                                .foregroundColor(.aiError)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Configure GitHub

    private var stepGitHubRemote: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置 GitHub 远程仓库")
                .font(.custom("Nunito-Bold", size: 18))
                .foregroundColor(.aiTextHeader)

            Text("填写你的 GitHub 仓库地址，用于推送和部署。")
                .font(.custom("Nunito-Medium", size: 13))
                .foregroundColor(.aiTextSecondary)

            NookInput("https://github.com/you/you.github.io.git", text: $githubRemoteURL)

            NookInput("分支名称", text: $githubBranch)

            HStack(spacing: 8) {
                NookButton(.default, size: .small, label: "格式检查") {
                    testConnection()
                }
                .disabled(isTestingConnection || githubRemoteURL.isEmpty)

                if isTestingConnection {
                    ProgressView()
                        .controlSize(.small)
                }

                if let result = connectionTestResult {
                    StatusBadge(
                        text: result,
                        level: result.contains("成功") || result.contains("格式正确") ? .ok : .error
                    )
                }
            }

            Text("此步骤可稍后在设置中配置。")
                .font(.custom("Nunito-Regular", size: 12))
                .foregroundColor(.aiTextMuted)
        }
        .onAppear {
            if githubRemoteURL.isEmpty {
                let remote = viewModel.publishRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if !remote.isEmpty {
                    githubRemoteURL = remote
                }
            }
            if githubBranch.isEmpty {
                githubBranch = viewModel.project.publishBranch
            }
        }
    }

    // MARK: - Step 3: Configure Token

    private var stepGitHubToken: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置 GitHub Token")
                .font(.custom("Nunito-Bold", size: 18))
                .foregroundColor(.aiTextHeader)

            Text("可选步骤。配置 Token 后可以自动查询部署状态和管理 Pages 来源。")
                .font(.custom("Nunito-Medium", size: 13))
                .foregroundColor(.aiTextSecondary)

            NookInput("github_pat_xxx 或 ghp_xxx", text: $githubToken)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.aiTextMuted)
                Text("Token 保存在本地配置包和系统钥匙串中，不会上传到 Git。")
                    .font(.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.aiTextMuted)
            }

            HStack(spacing: 8) {
                NookButton(.default, size: .small, label: "格式检查") {
                    testToken()
                }
                .disabled(isTestingToken || githubToken.isEmpty)

                if isTestingToken {
                    ProgressView()
                        .controlSize(.small)
                }

                if let result = tokenTestResult {
                    StatusBadge(
                        text: result,
                        level: result.contains("格式正确") ? .ok : .error
                    )
                }
            }

            NookWaveDivider()

            NookButton(.ghost, size: .small, label: "跳过") {
                withAnimation(NookAnimations.nookEase) {
                    currentStep = 4
                    saveProgress()
                }
            }
        }
    }

    // MARK: - Step 4: Complete

    private var stepComplete: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("配置完成")
                .font(.custom("Nunito-Bold", size: 20))
                .foregroundColor(.aiTextHeader)

            NookCard(color: .appGreen) {
                VStack(alignment: .leading, spacing: 10) {
                    summaryRow("项目路径", projectPath.isEmpty ? "未设置" : projectPath)
                    summaryRow("后端类型", detectedBackendName.isEmpty ? "自动检测" : detectedBackendName)
                    summaryRow("远程仓库", githubRemoteURL.isEmpty ? "未设置" : githubRemoteURL)
                    summaryRow("分支", githubBranch)
                    summaryRow("Token", githubToken.isEmpty ? "未配置" : "已配置")
                }
            }

            NookButton(.default, size: .small, label: "重新开始引导") {
                resetWizard()
            }
        }
    }

    private func summaryRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(key)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.custom("Nunito-Medium", size: 12))
                .foregroundColor(.aiTextBody)
                .textSelection(.enabled)
            Spacer()
        }
    }

    // MARK: - Card Color

    private var cardColorForStep: NookColor {
        switch currentStep {
        case 0:  return .appBlue
        case 1:  return .appGreen
        case 2:  return .purple
        case 3:  return .appOrange
        case 4:  return .appGreen
        default: return .nookDefault
        }
    }

    // MARK: - Actions

    private func advanceStep() {
        wizardError = nil
        if currentStep == 1 {
            let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            // 检查目录是否存在
            var isDir = ObjCBool(false)
            let exists = FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDir)
            if exists && isDir.boolValue {
                viewModel.project.rootPath = URL(fileURLWithPath: trimmed, isDirectory: true).path
                UserDefaults.standard.set(trimmed, forKey: BlogProject.lastRootPathDefaultsKey)
                detectedBackendName = viewModel.project.backend.displayName
            } else {
                wizardError = "目录不存在：\(trimmed)"
                return
            }
        }
        if currentStep == 2 {
            let remote = githubRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !remote.isEmpty {
                viewModel.publishRemoteURL = remote
                viewModel.project.publishBranch = githubBranch
                viewModel.saveRemoteProfile()
            }
        }
        wizardError = nil
        withAnimation(NookAnimations.nookEase) {
            currentStep += 1
            saveProgress()
        }
    }

    private func runClone() {
        let trimmedPath = clonePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = cloneURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPath.isEmpty else {
            cloneError = "请选择本地保存路径。"
            return
        }
        guard !trimmedURL.isEmpty else {
            cloneError = "请填写 GitHub 仓库 URL。"
            return
        }

        // 拼接完整路径：用户选的目录 + 仓库名
        let repoName = trimmedURL
            .replacingOccurrences(of: ".git", with: "")
            .split(separator: "/").last.map(String.init) ?? "blog"
        let fullPath = (trimmedPath as NSString).appendingPathComponent(repoName)

        isCloning = true
        cloneError = nil
        cloneLog = ["正在克隆 \(trimmedURL)...", "目标路径: \(fullPath)"]

        Task {
            let result = await viewModel.cloneProjectFromGitHubWithProgress(
                url: trimmedURL,
                targetPath: fullPath,
                log: { message in
                    DispatchQueue.main.async {
                        self.cloneLog.append(message)
                    }
                }
            )

            await MainActor.run {
                isCloning = false

                if result.contains("失败") {
                    cloneError = result
                    cloneLog.append("❌ 克隆失败。")
                } else {
                    projectPath = fullPath
                    cloneLog.append("✅ 克隆完成！")
                    detectedBackendName = viewModel.project.backend.displayName
                    cloneLog.append("✅ 检测到 \(detectedBackendName) 项目")
                    cloneLog.append("✅ 项目路径: \(fullPath)")
                    // 自动关闭克隆面板，显示项目路径
                    showCloneOption = false
                }
            }
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionTestResult = nil
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let url = githubRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if url.isEmpty {
                connectionTestResult = "请输入仓库地址"
            } else if url.contains("github.com") {
                connectionTestResult = "地址格式正确"
            } else {
                connectionTestResult = "地址格式可能有误"
            }
            isTestingConnection = false
        }
    }

    private func testToken() {
        isTestingToken = true
        tokenTestResult = nil
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let token = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty {
                tokenTestResult = "请输入 Token"
            } else if token.hasPrefix("ghp_") || token.hasPrefix("github_pat_") {
                tokenTestResult = "Token 格式正确"
            } else {
                tokenTestResult = "Token 格式可能有误"
            }
            isTestingToken = false
        }
    }

    private func finishSetup() {
        let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            viewModel.setProjectRootPath(trimmed)
        }

        let remote = githubRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remote.isEmpty {
            viewModel.publishRemoteURL = remote
            viewModel.project.publishBranch = githubBranch
            viewModel.saveRemoteProfile()
        }

        let token = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            viewModel.githubFineGrainedToken = token
            viewModel.saveRemoteProfile()
        }

        clearSavedProgress()
        viewModel.loadAll()
    }

    // MARK: - Progress Persistence

    private func saveProgress() {
        UserDefaults.standard.set(currentStep, forKey: stepDefaultsKey)
    }

    private func loadSavedProgress() {
        let saved = UserDefaults.standard.integer(forKey: stepDefaultsKey)
        if saved > 0 && saved < stepCount {
            currentStep = saved
        }
    }

    private func clearSavedProgress() {
        UserDefaults.standard.removeObject(forKey: stepDefaultsKey)
    }

    private func resetWizard() {
        currentStep = 0
        projectPath = ""
        detectedBackendName = ""
        githubRemoteURL = ""
        githubBranch = "main"
        githubToken = ""
        cloneLog = []
        cloneError = nil
        connectionTestResult = nil
        tokenTestResult = nil
        wizardError = nil
        showCloneOption = false
        clearSavedProgress()
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
