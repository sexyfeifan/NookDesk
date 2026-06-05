import Foundation

enum ProjectScaffoldingError: LocalizedError {
    case emptyPath
    case cloneFailed(String)
    case pathIsFile

    var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "目标路径不能为空。"
        case let .cloneFailed(msg):
            return "克隆失败：\(msg)"
        case .pathIsFile:
            return "目标路径是一个文件，不是目录。"
        }
    }
}

final class ProjectScaffoldingService: @unchecked Sendable {
    static let defaultTemplateURL = "https://github.com/sexyfeifan/sexyfeifan.github.io.git"

    private let processRunner = ProcessRunner()
    private let registry = BackendRegistry.shared

    func cloneTemplate(remoteURL: String, localPath: String) throws -> String {
        let trimmedURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty, !trimmedPath.isEmpty else {
            throw ProjectScaffoldingError.emptyPath
        }

        let parentDir = URL(fileURLWithPath: trimmedPath, isDirectory: true).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        let result = try processRunner.run(
            command: "git",
            arguments: ["clone", trimmedURL, trimmedPath],
            in: parentDir
        )
        return result.output.isEmpty ? "克隆完成。" : result.output
    }

    func scaffoldFromRemote(remoteURL: String, localPath: String, force: Bool = false) throws -> String {
        let trimmedPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw ProjectScaffoldingError.emptyPath
        }

        let fm = FileManager.default
        let targetURL = URL(fileURLWithPath: trimmedPath, isDirectory: true)
        var isDir = ObjCBool(false)
        let exists = fm.fileExists(atPath: trimmedPath, isDirectory: &isDir)

        if !exists {
            return try cloneTemplate(remoteURL: remoteURL, localPath: trimmedPath)
        }

        guard isDir.boolValue else {
            throw ProjectScaffoldingError.pathIsFile
        }

        if let detected = registry.detectBackend(in: targetURL) {
            return "项目已存在，无需拉取（已检测到 \(detected.displayName) 项目）。"
        }

        let contents = try fm.contentsOfDirectory(
            at: targetURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let nonHidden = contents.filter { !$0.lastPathComponent.hasPrefix(".") }
        if nonHidden.isEmpty {
            return try cloneTemplate(remoteURL: remoteURL, localPath: trimmedPath)
        }

        if force {
            return try cloneTemplate(remoteURL: remoteURL, localPath: trimmedPath)
        }

        return "目录已有文件但未检测到项目配置，如需克隆请使用强制模式。"
    }
}
