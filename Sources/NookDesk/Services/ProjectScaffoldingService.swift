import Foundation

enum ProjectScaffoldingError: LocalizedError {
    case emptyPath
    case cloneFailed(String)
    case pathIsFile
    case directoryNotEmpty(path: String)

    var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "目标路径不能为空。"
        case let .cloneFailed(msg):
            return "克隆失败：\(msg)"
        case .pathIsFile:
            return "目标路径是一个文件，不是目录。"
        case let .directoryNotEmpty(path):
            return "目录已有文件但未检测到项目配置：\(path)\n请手动清理后重试，或使用「从 GitHub 拉取」功能。"
        }
    }
}

final class ProjectScaffoldingService: @unchecked Sendable {
    static let defaultTemplateURL = "https://github.com/sexyfeifan/sexyfeifan.github.io.git"

    private let processRunner = ProcessRunner()
    private let registry = BackendRegistry.shared

    // MARK: - Clone from GitHub

    func cloneTemplate(remoteURL: String, localPath: String, log: ((String) -> Void)? = nil) throws -> String {
        let trimmedURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty, !trimmedPath.isEmpty else {
            throw ProjectScaffoldingError.emptyPath
        }

        let fm = FileManager.default
        let targetURL = URL(fileURLWithPath: trimmedPath, isDirectory: true)

        if fm.fileExists(atPath: trimmedPath) {
            let gitDir = targetURL.appendingPathComponent(".git").path
            if fm.fileExists(atPath: gitDir) {
                log?("目录已存在 Git 仓库，删除后重新克隆...")
                try fm.removeItem(at: targetURL)
            }
        }

        let parentDir = targetURL.deletingLastPathComponent()
        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)

        log?("正在克隆 \(trimmedURL)...")
        log?("目标路径: \(trimmedPath)")

        let result = try processRunner.run(
            command: "git",
            arguments: ["clone", "--depth=1", trimmedURL, trimmedPath],
            in: parentDir
        )

        log?("git clone 退出码: \(result.exitCode)")
        if !result.stderr.isEmpty {
            log?(result.stderr)
        }

        var isDir = ObjCBool(false)
        guard fm.fileExists(atPath: trimmedPath, isDirectory: &isDir), isDir.boolValue else {
            throw ProjectScaffoldingError.cloneFailed("克隆后目录不存在。")
        }

        let contents = try fm.contentsOfDirectory(at: targetURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let nonHidden = contents.filter { !$0.lastPathComponent.hasPrefix(".") }
        if nonHidden.isEmpty {
            throw ProjectScaffoldingError.cloneFailed("克隆成功但目录为空，请检查仓库地址是否正确。")
        }

        log?("克隆完成，共 \(nonHidden.count) 个文件/目录。")

        if let detected = registry.detectBackend(in: targetURL) {
            log?("检测到项目类型: \(detected.displayName)")
        }

        return result.output.isEmpty ? "克隆完成。" : result.output
    }

    func scaffoldFromRemote(remoteURL: String, localPath: String, force: Bool = false, log: ((String) -> Void)? = nil) throws -> String {
        let trimmedPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ProjectScaffoldingError.emptyPath
        }

        let fm = FileManager.default
        let targetURL = URL(fileURLWithPath: trimmedPath, isDirectory: true)
        var isDir = ObjCBool(false)
        let exists = fm.fileExists(atPath: trimmedPath, isDirectory: &isDir)

        if !exists {
            log?("目标目录不存在，开始克隆...")
            return try cloneTemplate(remoteURL: remoteURL, localPath: trimmedPath, log: log)
        }

        guard isDir.boolValue else {
            throw ProjectScaffoldingError.pathIsFile
        }

        if let detected = registry.detectBackend(in: targetURL) {
            log?("项目已存在（\(detected.displayName)），无需重新克隆。")
            return "项目已存在，无需拉取（已检测到 \(detected.displayName) 项目）。"
        }

        let contents = try fm.contentsOfDirectory(
            at: targetURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let nonHidden = contents.filter { !$0.lastPathComponent.hasPrefix(".") }

        if nonHidden.isEmpty {
            log?("目录为空，开始克隆...")
            return try cloneTemplate(remoteURL: remoteURL, localPath: trimmedPath, log: log)
        }

        if force {
            log?("强制模式：删除现有内容后重新克隆...")
            try fm.removeItem(at: targetURL)
            return try cloneTemplate(remoteURL: remoteURL, localPath: trimmedPath, log: log)
        }

        throw ProjectScaffoldingError.directoryNotEmpty(path: trimmedPath)
    }

    // MARK: - Inject Built-in Astro Theme

    func injectBuiltinTheme(into projectRoot: URL, log: ((String) -> Void)? = nil) throws {
        let fm = FileManager.default

        guard let bundleResourceURL = Bundle.main.resourceURL else {
            log?("无法访问 app 资源目录。")
            return
        }

        let themeSourceURL = bundleResourceURL
            .appendingPathComponent("NookDesk_NookDesk.bundle")
            .appendingPathComponent("Contents")
            .appendingPathComponent("Resources")
            .appendingPathComponent("AstroTemplate")

        var isDir = ObjCBool(false)
        guard fm.fileExists(atPath: themeSourceURL.path, isDirectory: &isDir), isDir.boolValue else {
            log?("内置主题资源未找到，跳过主题注入。")
            return
        }

        try fm.createDirectory(at: projectRoot, withIntermediateDirectories: true)

        let templateContents = try fm.contentsOfDirectory(
            at: themeSourceURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        var copiedCount = 0
        for item in templateContents {
            let fileName = item.lastPathComponent
            let destination = projectRoot.appendingPathComponent(fileName)

            if fm.fileExists(atPath: destination.path) {
                continue
            }

            try fm.copyItem(at: item, to: destination)
            copiedCount += 1
            log?("注入: \(fileName)")
        }

        log?("主题注入完成，共复制 \(copiedCount) 个文件/目录。")

        if copiedCount > 0 {
            try initializeGitRepo(at: projectRoot, log: log)
            try installDependencies(at: projectRoot, log: log)
        }
    }

    private func initializeGitRepo(at projectRoot: URL, log: ((String) -> Void)? = nil) throws {
        let gitDir = projectRoot.appendingPathComponent(".git").path
        if !FileManager.default.fileExists(atPath: gitDir) {
            log?("初始化 Git 仓库...")
            _ = try processRunner.run(command: "git", arguments: ["init"], in: projectRoot)
            _ = try processRunner.run(command: "git", arguments: ["add", "."], in: projectRoot)
            _ = try processRunner.run(
                command: "git",
                arguments: ["commit", "-m", "初始化 Astro 动森风格博客"],
                in: projectRoot
            )
            log?("Git 仓库初始化完成。")
        }
    }

    private func installDependencies(at projectRoot: URL, log: ((String) -> Void)? = nil) throws {
        let packageJSON = projectRoot.appendingPathComponent("package.json").path
        guard FileManager.default.fileExists(atPath: packageJSON) else { return }

        let nodeModules = projectRoot.appendingPathComponent("node_modules").path
        if FileManager.default.fileExists(atPath: nodeModules) {
            log?("node_modules 已存在，跳过安装。")
            return
        }

        log?("正在安装依赖（npm install）...")
        let result = try processRunner.run(command: "npm", arguments: ["install"], in: projectRoot)
        if result.exitCode == 0 {
            log?("依赖安装完成。")
        } else {
            log?("依赖安装失败：\(result.stderr)")
        }
    }
}
