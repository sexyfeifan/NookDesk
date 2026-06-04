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
    @State private var displayedTitle = ""

    private let titleText = "NookDesk"

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
        .onAppear {
            startTypewriter()
        }
    }

    private var logoSection: some View {
        VStack(spacing: 12) {
            NookIcon.variant.image
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.aiPrimary)

            Text(displayedTitle)
                .font(.custom("Nunito-Black", size: 36))
                .foregroundColor(.aiTextHeader)

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

    private func startTypewriter() {
        displayedTitle = ""
        for (index, char) in titleText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.08) {
                displayedTitle.append(char)
                if index == titleText.count - 1 {
                    showTypewriter = true
                }
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
