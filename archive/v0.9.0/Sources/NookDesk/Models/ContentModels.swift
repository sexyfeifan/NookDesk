import Foundation

enum FrontMatterFormat: String, CaseIterable, Codable, Identifiable {
    case toml = "TOML"
    case yaml = "YAML"
    case json = "JSON"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    var openingDelimiter: String {
        switch self {
        case .toml:
            return "+++"
        case .yaml:
            return "---"
        case .json:
            return "{"
        }
    }
}

enum FrontMatterEditorMode: String, CaseIterable, Identifiable {
    case structured = "结构化"
    case raw = "原始"

    var id: String { rawValue }
}

enum ImageStorageMode: String, CaseIterable, Identifiable {
    case automatic = "自动"
    case staticUploads = "静态目录"

    var id: String { rawValue }

    var helpText: String {
        switch self {
        case .automatic:
            return "自动判断图片存储位置。"
        case .staticUploads:
            return "统一写入 public/images/uploads。"
        }
    }
}

enum SummaryHandlingMode: String, CaseIterable, Identifiable {
    case auto = "自动摘要"
    case frontMatter = "Front Matter 摘要"
    case manualDivider = "手动 more 标记"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return "自动摘要"
        case .frontMatter:
            return "摘要字段优先"
        case .manualDivider:
            return "手动 more 标记"
        }
    }
}

struct LanguageProfile: Identifiable, Codable, Equatable {
    var code: String
    var title: String
    var contentDir: String
    var weight: Int

    var id: String { code }
}

struct TranslationDiagnostic: Identifiable, Hashable {
    let translationKey: String
    let sourceTitle: String
    let sourceFilePath: String
    let existingLanguageCodes: [String]
    let existingLanguages: [String]
    let missingLanguageCodes: [String]
    let missingLanguages: [String]

    var id: String { translationKey + "|" + sourceFilePath }
}

struct ReferenceDiagnostic: Identifiable, Hashable {
    let postTitle: String
    let filePath: String
    let reference: String
    let linePreview: String

    var id: String { filePath + "|" + reference + "|" + linePreview }
}

struct MenuTreeEntry: Identifiable, Hashable {
    let menuName: String
    let identifier: String
    let title: String
    let parent: String
    let weight: Int
    let filePath: String

    var id: String { menuName + "|" + identifier + "|" + filePath }
}

struct PageReferenceCandidate: Identifiable, Hashable {
    let title: String
    let referencePath: String
    let filePath: String

    var id: String { filePath }
}

struct ShortcodeParameterHint: Identifiable, Hashable {
    let name: String
    let sampleValue: String
    let isPositional: Bool

    var id: String { name }
}

struct ShortcodeDefinition: Identifiable, Hashable {
    let name: String
    let sourcePath: String
    let isProjectLocal: Bool
    let parameterHints: [ShortcodeParameterHint]
    let summary: String

    var id: String { sourcePath }
}

// Legacy types kept for backward compatibility with EditorView.swift

enum ContentCreationMode: String, CaseIterable, Identifiable, Codable {
    case singleFile = "单文件"
    case leafBundle = "Leaf Bundle"
    case branchBundle = "Section Bundle"

    var id: String { rawValue }

    var displayName: String { rawValue }
    var helpText: String { "" }
    var fileNameHint: String { "" }
    var createsBundle: Bool { false }
}

struct PageResourceItem: Identifiable, Hashable {
    let url: URL
    let relativePath: String
    let mediaKind: String

    var id: String { url.path }
}

struct MenuFrontMatter: Codable, Equatable {
    var menuName: String = ""
    var entryName: String = ""
    var identifier: String = ""
    var parent: String = ""
    var weight: Int = 0
    var pre: String = ""
    var post: String = ""

    var isEmpty: Bool {
        menuName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum BuildListMode: String, CaseIterable, Codable, Identifiable {
    case always = "always"
    case never = "never"
    case local = "local"
    var id: String { rawValue }
    var displayName: String { rawValue }
}

enum BuildRenderMode: String, CaseIterable, Codable, Identifiable {
    case always = "always"
    case never = "never"
    case link = "link"
    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct PostBuildOptions: Codable, Equatable {
    var list: BuildListMode = .always
    var render: BuildRenderMode = .always
    var publishResources: Bool = true

    var isDefault: Bool {
        list == .always && render == .always && publishResources
    }
}
