import Foundation

protocol SSGBuildBackend {
    var displayName: String { get }
    var configFileNames: [String] { get }
    var contentDirectoryName: String { get }
    var buildOutputDirectoryName: String { get }
    var workflowFileName: String { get }

    func detectProject(in directory: URL) -> Bool
    func buildCommand(project: BlogProject) -> (executable: String, arguments: [String])
    func versionCommand(project: BlogProject) -> (executable: String, arguments: [String])
    func structureCheck(project: BlogProject) -> StructureReport
    func generateWorkflow(project: BlogProject) -> String
    func renderedHTMLCandidates(for postFileURL: URL, project: BlogProject) -> [URL]
    func preferredContentSubpath(in rootURL: URL) -> String
    func defaultConfigTemplate() -> String
}

struct StructureReport {
    let rootPath: String
    let missingRequiredFiles: [String]
    let missingRequiredDirectories: [String]
    let missingRecommendedFiles: [String]
    let missingRecommendedDirectories: [String]
    var createdFiles: [String]
    var createdDirectories: [String]

    var hasMissingItems: Bool {
        !missingRequiredFiles.isEmpty
            || !missingRequiredDirectories.isEmpty
            || !missingRecommendedFiles.isEmpty
            || !missingRecommendedDirectories.isEmpty
    }

    var hasMissingRequiredItems: Bool {
        !missingRequiredFiles.isEmpty || !missingRequiredDirectories.isEmpty
    }

    func renderCheckLog(backendName: String) -> String {
        var lines: [String] = []
        lines.append("== \(backendName) 文件结构检测 ==")
        lines.append("项目目录：\(rootPath)")
        if hasMissingRequiredItems {
            lines.append("检测结果：存在必需项缺失（会阻断发布）。")
        } else if hasMissingItems {
            lines.append("检测结果：存在推荐项缺失（不阻断发布）。")
        } else {
            lines.append("检测结果：结构完整。")
        }
        for item in missingRequiredFiles { lines.append("- 必需文件：\(item)") }
        for item in missingRequiredDirectories { lines.append("- 必需目录：\(item)") }
        for item in missingRecommendedFiles { lines.append("- 推荐文件：\(item)") }
        for item in missingRecommendedDirectories { lines.append("- 推荐目录：\(item)") }
        return lines.joined(separator: "\n")
    }

    func renderRepairLog(backendName: String) -> String {
        var lines: [String] = []
        lines.append("== \(backendName) 文件结构修复 ==")
        lines.append("项目目录：\(rootPath)")
        if createdFiles.isEmpty && createdDirectories.isEmpty {
            lines.append("没有创建新文件或目录。")
        } else {
            for item in createdFiles { lines.append("- 已创建文件：\(item)") }
            for item in createdDirectories { lines.append("- 已创建目录：\(item)") }
        }
        if hasMissingItems {
            lines.append("⚠️ 仍有缺失项，请检查目录权限或手动处理。")
        } else {
            lines.append("✅ 结构修复完成。")
        }
        return lines.joined(separator: "\n")
    }
}
