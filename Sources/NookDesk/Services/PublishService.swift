import Foundation

final class PublishService {
    private let runner = ProcessRunner()
    private let fm = FileManager.default

    // MARK: - Signal-safe cleanup for temp askpass scripts
    static var pendingAskPassPaths: Set<String> = []
    private static var signalCleanupInstalled = false

    static func installSignalCleanupIfNeeded() {
        guard !signalCleanupInstalled else { return }
        signalCleanupInstalled = true
        let cleanup: @convention(c) (Int32) -> Void = { sig in
            for path in pendingAskPassPaths {
                try? FileManager.default.removeItem(atPath: path)
            }
            _exit(128 + sig)
        }
        signal(SIGINT, cleanup)
        signal(SIGTERM, cleanup)
    }

    func runBuild(project: BlogProject) throws -> String {
        let be = project.backend
        let cmd = be.buildCommand(project: project)
        let executable = resolveCommandPath(name: cmd.executable, cwd: project.rootURL) ?? cmd.executable
        let result = try runner.run(command: executable, arguments: cmd.arguments, in: project.rootURL)
        return renderProcessLog(step: "构建 \(be.displayName) 站点", result: result)
    }

    func checkVersion(project: BlogProject) throws -> String {
        let be = project.backend
        let cmd = be.versionCommand(project: project)
        let executable = resolveCommandPath(name: cmd.executable, cwd: project.rootURL) ?? cmd.executable
        let result = try runner.run(command: executable, arguments: cmd.arguments, in: project.rootURL)
        return renderProcessLog(step: "检查 \(be.displayName) 版本", result: result)
    }

    func checkStructure(project: BlogProject) -> StructureReport {
        project.backend.structureCheck(project: project)
    }

    func repairStructure(project: BlogProject) throws -> StructureReport {
        let be = project.backend
        var report = be.structureCheck(project: project)
        var createdDirs: [String] = []
        var createdFiles: [String] = []

        for relativePath in report.missingRequiredDirectories {
            let dirURL = project.rootURL.appendingPathComponent(relativePath, isDirectory: true)
            try fm.createDirectory(at: dirURL, withIntermediateDirectories: true)
            createdDirs.append(relativePath)
        }

        for relativePath in report.missingRequiredFiles {
            let fileURL = project.rootURL.appendingPathComponent(relativePath, isDirectory: false)
            if relativePath == be.configFileNames.first {
                try be.defaultConfigTemplate().write(to: fileURL, atomically: true, encoding: .utf8)
                createdFiles.append(relativePath)
            }
        }

        if !hasGitHubPagesWorkflow(project: project) {
            _ = try ensureGitHubPagesWorkflow(project: project)
            createdFiles.append(".github/workflows/\(be.workflowFileName)")
        }

        report = be.structureCheck(project: project)
        report.createdDirectories = Array(Set(createdDirs)).sorted()
        report.createdFiles = Array(Set(createdFiles)).sorted()
        return report
    }

    func commitAndPush(
        project: BlogProject,
        message: String,
        remoteURL: String,
        githubToken: String = ""
    ) throws -> String {
        var logs: [String] = []
        let auth = try makeGitAuthContext(githubToken: githubToken)
        defer { auth.cleanup() }
        let tokenEnv = auth.environment

        let unresolved = unresolvedConflictFiles(project: project)
        if !unresolved.isEmpty {
            let lines = unresolved.map { "- \($0)" }.joined(separator: "\n")
            throw ProcessRunnerError.commandFailed(command: "git commit", code: 1, output: """
                检测到未解决的 Git 冲突，无法继续提交。
                冲突文件：
                \(lines)
                """)
        }

        if !remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logs.append(contentsOf: ensureRemoteURLLogs(project: project, remoteURL: remoteURL))
        }

        let add = try stagePublishFiles(project: project)
        logs.append(renderProcessLog(step: "暂存变更", result: add))

        if !hasGitHubPagesWorkflow(project: project) {
            logs.append("== 部署链路提示 ==\n未检测到 Pages Workflow，请在发布页点击生成。")
        }

        do {
            let commit = try runner.run(command: "git", arguments: ["commit", "-m", message], in: project.rootURL)
            logs.append(renderProcessLog(step: "提交变更", result: commit))
        } catch let ProcessRunnerError.commandFailed(_, _, output) {
            if output.contains("nothing to commit") || output.contains("no changes added") {
                logs.append("== 提交变更 ==\n无需提交：没有新的暂存变更。")
            } else {
                throw ProcessRunnerError.commandFailed(command: "git commit", code: 1, output: output)
            }
        }

        do {
            let push = try runner.run(
                command: "git",
                arguments: ["push", project.gitRemote, project.publishBranch],
                in: project.rootURL,
                environment: tokenEnv
            )
            logs.append(renderProcessLog(step: "推送到远端", result: push))
        } catch let ProcessRunnerError.commandFailed(_, _, output) {
            if containsNonFastForward(output) {
                logs.append("== 推送到远端 ==\nPush 被拒绝，自动同步后重试。")
                let syncOutput = try syncWithRemote(project: project, remoteURL: remoteURL, githubToken: githubToken)
                if !syncOutput.isEmpty { logs.append(syncOutput) }
                let retry = try runner.run(
                    command: "git",
                    arguments: ["push", project.gitRemote, project.publishBranch],
                    in: project.rootURL,
                    environment: tokenEnv
                )
                logs.append(renderProcessLog(step: "重试推送", result: retry))
            } else {
                throw ProcessRunnerError.commandFailed(command: "git push", code: 1, output: output)
            }
        }

        return logs.joined(separator: "\n\n")
    }

    func syncWithRemote(project: BlogProject, remoteURL: String, githubToken: String = "") throws -> String {
        var logs: [String] = []
        let auth = try makeGitAuthContext(githubToken: githubToken)
        defer { auth.cleanup() }
        let tokenEnv = auth.environment

        if !remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logs.append(contentsOf: ensureRemoteURLLogs(project: project, remoteURL: remoteURL))
        }

        let fetch = try runner.run(
            command: "git", arguments: ["fetch", project.gitRemote, project.publishBranch],
            in: project.rootURL, environment: tokenEnv
        )
        logs.append(renderProcessLog(step: "拉取远端引用", result: fetch))

        let pull = try runner.run(
            command: "git", arguments: ["pull", "--rebase", "--autostash", project.gitRemote, project.publishBranch],
            in: project.rootURL, environment: tokenEnv
        )
        logs.append(renderProcessLog(step: "变基同步", result: pull))

        return logs.joined(separator: "\n\n")
    }

    func detectRemoteURL(project: BlogProject) -> String {
        do {
            let result = try runner.run(
                command: "git", arguments: ["remote", "get-url", project.gitRemote], in: project.rootURL
            )
            return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch { return "" }
    }

    func diagnosePublishEnvironment(
        project: BlogProject,
        remoteURL: String,
        githubToken: String = ""
    ) throws -> String {
        var lines: [String] = []
        let be = project.backend
        let auth = try makeGitAuthContext(githubToken: githubToken)
        defer { auth.cleanup() }
        let tokenEnv = auth.environment

        lines.append("== 组件检查 ==")
        let gitOK = capture(command: "git", arguments: ["--version"], in: project.rootURL)
        lines.append(gitOK.success ? "✅ Git：\(gitOK.output)" : "❌ Git 不可用")

        let buildOK = {
            let cmd = be.buildCommand(project: project)
            return capture(command: "/usr/bin/env", arguments: ["which", cmd.executable], in: project.rootURL)
        }()
        lines.append(buildOK.success ? "✅ \(be.displayName) 构建工具可用" : "❌ \(be.displayName) 构建工具不可用")

        lines.append("")
        lines.append("== 推送能力检查 ==")
        if !gitOK.success {
            lines.append("❌ Git 不可用，跳过推送检查。")
            return lines.joined(separator: "\n")
        }

        let isRepo = capture(command: "git", arguments: ["rev-parse", "--is-inside-work-tree"], in: project.rootURL)
        lines.append(isRepo.success ? "✅ Git 仓库" : "❌ 不是 Git 仓库")
        guard isRepo.success else { return lines.joined(separator: "\n") }

        let remoteTarget = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if remoteTarget.isEmpty {
            lines.append("❌ 未配置远程地址")
            return lines.joined(separator: "\n")
        }

        let probe = capture(command: "git", arguments: ["ls-remote", remoteTarget, "HEAD"], in: project.rootURL, environment: tokenEnv)
        lines.append(probe.success ? "✅ 远程可达" : "❌ 远程不可达：\(probe.output)")

        let dryRun = capture(command: "git", arguments: ["push", "--dry-run", remoteTarget, project.publishBranch], in: project.rootURL, environment: tokenEnv)
        lines.append(dryRun.success ? "✅ 推送权限正常" : "❌ 推送权限不足：\(dryRun.output)")

        lines.append("")
        lines.append("== 部署链路检查 ==")
        let wfExists = hasGitHubPagesWorkflow(project: project)
        lines.append(wfExists
            ? "✅ GitHub Pages Workflow：已检测到 \(be.workflowFileName)"
            : "❌ GitHub Pages Workflow：未检测到 \(be.workflowFileName)")

        if probe.success && dryRun.success {
            lines.append("✅ 推送链路可用。")
        } else {
            lines.append("⚠️ 推送能力存在问题，请先修复上方失败项。")
        }

        return lines.joined(separator: "\n")
    }

    func hasGitHubPagesWorkflow(project: BlogProject) -> Bool {
        let be = project.backend
        return fm.fileExists(atPath: project.rootURL
            .appendingPathComponent(".github/workflows/\(be.workflowFileName)").path)
    }

    func ensureGitHubPagesWorkflow(project: BlogProject) throws -> String {
        let be = project.backend
        let workflowURL = project.rootURL
            .appendingPathComponent(".github/workflows/\(be.workflowFileName)")
        try fm.createDirectory(at: workflowURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try be.generateWorkflow(project: project).write(to: workflowURL, atomically: true, encoding: .utf8)
        return workflowURL.path
    }

    func unresolvedConflictFiles(project: BlogProject) -> [String] {
        let result = capture(command: "git", arguments: ["diff", "--name-only", "--diff-filter=U"], in: project.rootURL)
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func duplicatePagesWorkflowFileNames(project: BlogProject) -> [String] {
        let be = project.backend
        let workflowDir = project.rootURL.appendingPathComponent(".github/workflows", isDirectory: true)
        guard let files = try? fm.contentsOfDirectory(at: workflowDir, includingPropertiesForKeys: nil) else { return [] }
        let canonical = be.workflowFileName
        return files.filter { file in
            let ext = file.pathExtension.lowercased()
            guard ext == "yml" || ext == "yaml" else { return false }
            guard file.lastPathComponent != canonical else { return false }
            guard let content = try? String(contentsOf: file, encoding: .utf8).lowercased() else { return false }
            return content.contains("nookdesk: managed") || content.contains("actions/deploy-pages@v4")
        }.map(\.lastPathComponent)
    }

    // MARK: - Private

    private func ensureRemoteURLLogs(project: BlogProject, remoteURL: String) -> [String] {
        do {
            _ = try runner.run(command: "git", arguments: ["remote", "get-url", project.gitRemote], in: project.rootURL)
            let result = try runner.run(command: "git", arguments: ["remote", "set-url", project.gitRemote, remoteURL], in: project.rootURL)
            return [renderProcessLog(step: "更新远端地址", result: result)]
        } catch {
            do {
                let result = try runner.run(command: "git", arguments: ["remote", "add", project.gitRemote, remoteURL], in: project.rootURL)
                return [renderProcessLog(step: "添加远端地址", result: result)]
            } catch {
                return ["== 配置远端地址 ==\n失败：\(error.localizedDescription)"]
            }
        }
    }

    private func stagePublishFiles(project: BlogProject) throws -> ProcessResult {
        let excludes = [
            ":(exclude).nookdesk.local.json",
            ":(exclude)NookDesk",
            ":(exclude)NookDesk/**",
            ":(exclude)NookDeskStorage",
            ":(exclude)NookDeskStorage/**"
        ]
        let base = ["add", "--all", "--", "."]
        do {
            return try runner.run(command: "git", arguments: base + excludes, in: project.rootURL)
        } catch let ProcessRunnerError.commandFailed(_, _, output) {
            if output.contains("ignored by one of your .gitignore files") {
                // 安全回退：只暂存已跟踪文件的修改，不暂存未跟踪文件
                let _ = try? runner.run(command: "git", arguments: ["add", "-u"], in: project.rootURL)
                // 手动添加已知安全的博客文件
                let safePaths = ["src/", "package.json", "vite.config.ts", "index.html", "tsconfig.json", ".github/"]
                for path in safePaths {
                    let testPath = project.rootURL.appendingPathComponent(path).path
                    if FileManager.default.fileExists(atPath: testPath) {
                        let _ = try? runner.run(command: "git", arguments: ["add", path], in: project.rootURL)
                    }
                }
                return try runner.run(command: "git", arguments: ["status", "--short"], in: project.rootURL)
            }
            throw ProcessRunnerError.commandFailed(command: "git add", code: 1, output: output)
        }
    }

    private func renderProcessLog(step: String, result: ProcessResult) -> String {
        var lines = ["== \(step) ==", "命令：\(result.commandLine)", "目录：\(result.workingDirectory)",
                     "退出码：\(result.exitCode)", String(format: "耗时：%.2fs", result.duration)]
        if !result.stdout.isEmpty { lines.append("-- stdout --\n\(result.stdout)") }
        if !result.stderr.isEmpty { lines.append("-- stderr --\n\(result.stderr)") }
        return lines.joined(separator: "\n")
    }

    private func containsNonFastForward(_ output: String) -> Bool {
        let t = output.lowercased()
        return t.contains("non-fast-forward") || t.contains("fetch first") || t.contains("pushed branch tip is behind")
    }

    private func capture(command: String, arguments: [String], in cwd: URL, environment: [String: String] = [:]) -> CommandCapture {
        do {
            let result = try runner.run(command: command, arguments: arguments, in: cwd, environment: environment)
            return CommandCapture(success: true, output: result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch let ProcessRunnerError.commandFailed(_, _, output) {
            return CommandCapture(success: false, output: output.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            return CommandCapture(success: false, output: error.localizedDescription)
        }
    }

    private func makeGitAuthContext(githubToken: String) throws -> GitAuthContext {
        let token = githubToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return GitAuthContext(environment: [:], cleanup: {}) }
        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nookdesk-askpass-\(UUID().uuidString).sh")
        let script = """
        #!/bin/sh
        case "$1" in
          *sername*) echo "x-access-token" ;;
          *assword*) echo "$AID_GITHUB_TOKEN" ;;
          *) echo "" ;;
        esac
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        // Register signal cleanup to remove temp script on crash/exit
        let cleanupAction: () -> Void = {
            try? FileManager.default.removeItem(at: scriptURL)
        }
        #if os(macOS)
        // Signal handler cleanup — store path in a global so C-convention handler can access it
        Self.pendingAskPassPaths.insert(scriptURL.path)
        Self.installSignalCleanupIfNeeded()
        #endif

        return GitAuthContext(
            environment: ["GIT_ASKPASS": scriptURL.path, "AID_GITHUB_TOKEN": token, "GCM_INTERACTIVE": "Never", "GIT_TERMINAL_PROMPT": "0"],
            cleanup: cleanupAction
        )
    }

    private func resolveCommandPath(name: String, cwd: URL) -> String? {
        if name.contains("/") { return fm.isExecutableFile(atPath: name) ? name : nil }
        for root in ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"] {
            let path = "\(root)/\(name)"
            if fm.isExecutableFile(atPath: path) { return path }
        }
        let lookup = capture(command: "/usr/bin/env", arguments: ["which", name], in: cwd)
        let path = lookup.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if lookup.success, !path.isEmpty, fm.isExecutableFile(atPath: path) { return path }
        return nil
    }
}

private struct CommandCapture {
    var success: Bool
    var output: String
}

private struct GitAuthContext {
    var environment: [String: String]
    var cleanup: () -> Void
}
