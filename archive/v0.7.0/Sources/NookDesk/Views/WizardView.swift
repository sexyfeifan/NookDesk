import SwiftUI

struct WizardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var currentStep = 0
    @State private var projectPath: String = ""
    @State private var detectedBackendName: String = ""
    @State private var githubRemoteURL: String = ""
    @State private var githubToken: String = ""
    @State private var isDetecting = false
    @State private var showTypewriter = false
    @State private var showCloneOption = false
    @State private var cloneURL: String = ProjectScaffoldingService.defaultTemplateURL
    @State private var isCloning = false
    @State private var cloneError: String?
    @State private var cloneLog: [String] = []

    var body: some View {
        ZStack {
            Color.aiBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                logoSection
                    .padding(.bottom, 32)

                wizardCard
                    .frame(maxWidth: 560)

                Spacer()
            }
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

                Divider()

                stepContent

                Divider()

                HStack {
                    if currentStep > 0 {
                        NookButton(.default, size: .medium, label: "上一步") {
                            withAnimation(NookAnimations.nookEase) {
                                currentStep -= 1
                            }
                        }
                    }

                    Spacer()

                    if currentStep < 3 {
                        NookButton(.primary, size: .medium, label: "下一步") {
                            advanceStep()
                        }
                        .disabled(currentStep == 0 && projectPath.isEmpty)
                    } else {
                        NookButton(.primary, size: .large, label: "开始使用") {
                            finishSetup()
                        }
                    }
                }
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { step in
                HStack(spacing: 6) {
                    Circle()
                        .fill(step <= currentStep ? Color.aiPrimary : Color.aiBorderLight)
                        .frame(width: 10, height: 10)
                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep ? Color.aiPrimary : Color.aiBorderLight)
                            .frame(height: 2)
                            .frame(maxWidth: 40)
                    }
                }
            }
            Spacer()
            Text("步骤 \(currentStep + 1) / 4")
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case 0:
            stepProjectFolder
        case 1:
            stepDetectBackend
        case 2:
            stepGitHubRemote
        case 3:
            stepGitHubToken
        default:
            EmptyView()
        }
    }

    private var stepProjectFolder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择项目文件夹")
                .font(.custom("Nunito-Bold", size: 18))
                .foregroundColor(.aiTextHeader)

            Text("选择你的博客项目根目录，包含 hugo.toml 或 vite.config.ts 等配置文件。")
                .font(.custom("Nunito-Medium", size: 13))
                .foregroundColor(.aiTextSecondary)

            NookInput("项目根目录路径", text: $projectPath)

            NookButton(.default, size: .medium, label: "选择文件夹") {
                if let path = pickDirectory() {
                    projectPath = path
                    showCloneOption = false
                    cloneError = nil
                    cloneLog = []
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

            NookDivider()

            if !showCloneOption {
                NookButton(.ghost, size: .small, label: "没有项目？从 GitHub 克隆") {
                    showCloneOption = true
                }
            }

            if showCloneOption {
                VStack(alignment: .leading, spacing: 8) {
                    Text("从 GitHub 克隆项目")
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(.aiTextHeader)

                    NookInput("GitHub 仓库 URL", text: $cloneURL)

                    HStack(spacing: 8) {
                        NookButton(.primary, size: .small, label: "克隆到所选目录") {
                            runClone()
                        }
                        .disabled(isCloning || projectPath.isEmpty)

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
                .padding(12)
                .background(Color.aiSecondaryBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var stepDetectBackend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("检测后端类型")
                .font(.custom("Nunito-Bold", size: 18))
                .foregroundColor(.aiTextHeader)

            Text("NookDesk 将自动检测你的项目使用哪种静态站点生成器。")
                .font(.custom("Nunito-Medium", size: 13))
                .foregroundColor(.aiTextSecondary)

            if isDetecting {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在检测...")
                        .font(.custom("Nunito-Medium", size: 13))
                        .foregroundColor(.aiTextSecondary)
                }
            } else if !detectedBackendName.isEmpty {
                NookCard(color: .appGreen) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.aiSuccess)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已检测到后端")
                                .font(.custom("Nunito-Bold", size: 14))
                                .foregroundColor(.aiTextHeader)
                            Text(detectedBackendName)
                                .font(.custom("Nunito-SemiBold", size: 16))
                                .foregroundColor(.aiPrimary)
                        }
                        Spacer()
                    }
                }
            } else {
                NookCard(color: .appYellow) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.aiWarning)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("未检测到后端")
                                .font(.custom("Nunito-Bold", size: 14))
                                .foregroundColor(.aiTextHeader)
                            Text("将使用默认配置，你可以在设置中手动修改。")
                                .font(.custom("Nunito-Medium", size: 12))
                                .foregroundColor(.aiTextSecondary)
                        }
                        Spacer()
                    }
                }
            }

            NookButton(.default, size: .small, label: "重新检测") {
                detectBackend()
            }
        }
        .onAppear {
            if detectedBackendName.isEmpty {
                detectBackend()
            }
        }
    }

    private var stepGitHubRemote: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置 GitHub 远程仓库")
                .font(.custom("Nunito-Bold", size: 18))
                .foregroundColor(.aiTextHeader)

            Text("填写你的 GitHub 仓库地址，用于推送和部署。")
                .font(.custom("Nunito-Medium", size: 13))
                .foregroundColor(.aiTextSecondary)

            NookInput("https://github.com/you/you.github.io.git", text: $githubRemoteURL)

            Text("此步骤可稍后在设置中配置。")
                .font(.custom("Nunito-Regular", size: 12))
                .foregroundColor(.aiTextMuted)
        }
    }

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

            Text("可以跳过此步骤，稍后在设置中配置。")
                .font(.custom("Nunito-Regular", size: 12))
                .foregroundColor(.aiTextMuted)
        }
    }

    private var cardColorForStep: NookColor {
        switch currentStep {
        case 0:  return .appBlue
        case 1:  return .appGreen
        case 2:  return .purple
        case 3:  return .appOrange
        default: return .nookDefault
        }
    }

    private func runClone() {
        let trimmedPath = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = cloneURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPath.isEmpty else {
            cloneError = "请先选择项目目录。"
            return
        }
        guard !trimmedURL.isEmpty else {
            cloneError = "请填写 GitHub 仓库 URL。"
            return
        }

        isCloning = true
        cloneError = nil
        cloneLog = ["正在克隆 \(trimmedURL)..."]

        viewModel.setProjectRootPath(trimmedPath)

        Task {
            let result = await viewModel.cloneProjectFromGitHubWithProgress(url: trimmedURL)
            isCloning = false

            if result.contains("失败") || result.contains("错误") || result.contains("不能") {
                cloneError = result
                cloneLog.append("克隆失败。")
            } else {
                cloneLog.append("克隆完成。")
                cloneLog.append("检测到 \(viewModel.project.backend.displayName) 项目。")
                cloneLog.append("初始化完成。")
                detectedBackendName = viewModel.project.backend.displayName
            }
        }
    }

    private func advanceStep() {
        if currentStep == 0 {
            let trimmed = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            viewModel.setProjectRootPath(trimmed)
        }
        withAnimation(NookAnimations.nookEase) {
            currentStep += 1
        }
    }

    private func detectBackend() {
        isDetecting = true
        detectedBackendName = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let backend = viewModel.project.backend
            detectedBackendName = backend.displayName
            isDetecting = false
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
            viewModel.saveRemoteProfile()
        }

        let token = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            viewModel.githubFineGrainedToken = token
            viewModel.saveRemoteProfile()
        }

        viewModel.loadAll()
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
