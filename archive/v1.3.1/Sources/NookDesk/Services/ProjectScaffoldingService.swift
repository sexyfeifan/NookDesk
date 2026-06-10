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
    static let defaultTemplateURL = "https://github.com/guokaigdg/animal-island-blog.git"

    private let processRunner = ProcessRunner()
    private let registry = BackendRegistry.shared

    func cloneTemplate(remoteURL: String, localPath: String, log: ((String) -> Void)? = nil) throws -> String {
        let trimmedURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty, !trimmedPath.isEmpty else {
            throw ProjectScaffoldingError.emptyPath
        }

        let fm = FileManager.default
        let targetURL = URL(fileURLWithPath: trimmedPath, isDirectory: true)

        // 如果目标目录已存在且有 .git，先删除再重新克隆
        if fm.fileExists(atPath: trimmedPath) {
            let gitDir = targetURL.appendingPathComponent(".git").path
            if fm.fileExists(atPath: gitDir) {
                log?("目录已存在 Git 仓库，删除后重新克隆...")
                try fm.removeItem(at: targetURL)
            }
        }

        // 确保父目录存在
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

        // 验证克隆结果
        var isDir = ObjCBool(false)
        guard fm.fileExists(atPath: trimmedPath, isDirectory: &isDir), isDir.boolValue else {
            throw ProjectScaffoldingError.cloneFailed("克隆后目录不存在。")
        }

        // 检查是否有文件
        let contents = try fm.contentsOfDirectory(at: targetURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let nonHidden = contents.filter { !$0.lastPathComponent.hasPrefix(".") }
        if nonHidden.isEmpty {
            throw ProjectScaffoldingError.cloneFailed("克隆成功但目录为空，请检查仓库地址是否正确。")
        }

        log?("克隆完成，共 \(nonHidden.count) 个文件/目录。")

        // 检测后端类型
        if let detected = registry.detectBackend(in: targetURL) {
            log?("检测到项目类型: \(detected.displayName)")
        } else {
            log?("未检测到已知项目类型，将使用默认配置。")
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

        // 目录不存在 → 直接克隆
        if !exists {
            log?("目标目录不存在，开始克隆...")
            return try cloneTemplate(remoteURL: remoteURL, localPath: trimmedPath, log: log)
        }

        guard isDir.boolValue else {
            throw ProjectScaffoldingError.pathIsFile
        }

        // 目录存在，检查是否已有有效项目
        if let detected = registry.detectBackend(in: targetURL) {
            log?("项目已存在（\(detected.displayName)），无需重新克隆。")
            return "项目已存在，无需拉取（已检测到 \(detected.displayName) 项目）。"
        }

        // 目录存在但没有有效项目配置
        let contents = try fm.contentsOfDirectory(
            at: targetURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let nonHidden = contents.filter { !$0.lastPathComponent.hasPrefix(".") }

        // 空目录 → 克隆
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
}
