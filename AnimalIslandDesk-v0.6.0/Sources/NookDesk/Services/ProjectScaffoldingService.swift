import Foundation

enum ProjectScaffoldingError: LocalizedError {
    case emptyPath
    case pathNotEmptyNoSrc
    case cloneFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "目标路径不能为空。"
        case .pathNotEmptyNoSrc:
            return "目标目录不为空且缺少 src/ 目录，无法安全克隆。"
        case let .cloneFailed(msg):
            return "克隆失败：\(msg)"
        }
    }
}

final class ProjectScaffoldingService: @unchecked Sendable {
    static let defaultTemplateURL = "https://github.com/sexyfeifan/sexyfeifan.github.io.git"

    private let processRunner = ProcessRunner()

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

    func scaffoldFromRemote(remoteURL: String, localPath: String) throws -> String {
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
            throw ProjectScaffoldingError.pathNotEmptyNoSrc
        }

        let srcURL = targetURL.appendingPathComponent("src", isDirectory: true)
        var isSrcDir = ObjCBool(false)
        let hasSrc = fm.fileExists(atPath: srcURL.path, isDirectory: &isSrcDir) && isSrcDir.boolValue

        if hasSrc {
            return "目标目录已存在且包含 src/，跳过克隆。"
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

        throw ProjectScaffoldingError.pathNotEmptyNoSrc
    }
}
