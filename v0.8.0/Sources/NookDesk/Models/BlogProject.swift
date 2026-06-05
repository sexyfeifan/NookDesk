import Foundation

struct BlogProject: Codable {
    static let lastRootPathDefaultsKey = "nookdesk.lastProjectRootPath"

    var rootPath: String
    var buildExecutable: String
    var contentSubpath: String
    var gitRemote: String
    var publishBranch: String
    var backendName: String

    private enum CodingKeys: String, CodingKey {
        case rootPath
        case buildExecutable
        case hugoExecutable
        case contentSubpath
        case gitRemote
        case publishBranch
        case backendName
    }

    init(rootPath: String, buildExecutable: String, contentSubpath: String, gitRemote: String, publishBranch: String, backendName: String) {
        self.rootPath = rootPath
        self.buildExecutable = buildExecutable
        self.contentSubpath = contentSubpath
        self.gitRemote = gitRemote
        self.publishBranch = publishBranch
        self.backendName = backendName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rootPath = try container.decode(String.self, forKey: .rootPath)
        if let newExec = try container.decodeIfPresent(String.self, forKey: .buildExecutable) {
            buildExecutable = newExec
        } else {
            buildExecutable = try container.decodeIfPresent(String.self, forKey: .hugoExecutable) ?? "hugo"
        }
        contentSubpath = try container.decode(String.self, forKey: .contentSubpath)
        gitRemote = try container.decode(String.self, forKey: .gitRemote)
        publishBranch = try container.decode(String.self, forKey: .publishBranch)
        backendName = try container.decodeIfPresent(String.self, forKey: .backendName) ?? "Vite + React"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rootPath, forKey: .rootPath)
        try container.encode(buildExecutable, forKey: .buildExecutable)
        try container.encode(contentSubpath, forKey: .contentSubpath)
        try container.encode(gitRemote, forKey: .gitRemote)
        try container.encode(publishBranch, forKey: .publishBranch)
        try container.encode(backendName, forKey: .backendName)
    }

    var backend: SSGBuildBackend {
        BackendRegistry.shared.backend(named: backendName) ?? ViteBackend()
    }

    static func bootstrap() -> BlogProject {
        let registry = BackendRegistry.shared

        if let cachedRoot = UserDefaults.standard.string(forKey: lastRootPathDefaultsKey),
           !cachedRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cachedURL = URL(fileURLWithPath: cachedRoot, isDirectory: true)
            if let detected = registry.detectBackend(in: cachedURL) {
                let exec = detected.displayName == "Hugo" ? "hugo" : "npm"
                return BlogProject(
                    rootPath: cachedURL.path,
                    buildExecutable: exec,
                    contentSubpath: detected.preferredContentSubpath(in: cachedURL),
                    gitRemote: "origin",
                    publishBranch: "main",
                    backendName: detected.displayName
                )
            }
        }

        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let parent = cwd.deletingLastPathComponent()

        if let detected = registry.detectBackend(in: cwd) {
            let exec = detected.displayName == "Hugo" ? "hugo" : "npm"
            return BlogProject(
                rootPath: cwd.path,
                buildExecutable: exec,
                contentSubpath: detected.preferredContentSubpath(in: cwd),
                gitRemote: "origin",
                publishBranch: "main",
                backendName: detected.displayName
            )
        }

        if let detected = registry.detectBackend(in: parent) {
            let exec = detected.displayName == "Hugo" ? "hugo" : "npm"
            return BlogProject(
                rootPath: parent.path,
                buildExecutable: exec,
                contentSubpath: detected.preferredContentSubpath(in: parent),
                gitRemote: "origin",
                publishBranch: "main",
                backendName: detected.displayName
            )
        }

        return BlogProject(
            rootPath: cwd.path,
            buildExecutable: "npm",
            contentSubpath: "src/pages/Home",
            gitRemote: "origin",
            publishBranch: "main",
            backendName: "Vite + React"
        )
    }

    var rootURL: URL {
        URL(fileURLWithPath: rootPath, isDirectory: true)
    }

    var contentURL: URL {
        rootURL.appendingPathComponent(contentSubpath, isDirectory: true)
    }

    var configURL: URL {
        let be = backend
        for name in be.configFileNames {
            let url = rootURL.appendingPathComponent(name)
            var isDir = ObjCBool(false)
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                return url
            }
        }
        return rootURL.appendingPathComponent(be.configFileNames.first ?? "vite.config.ts")
    }

    var staticImagesURL: URL {
        let relativePath = backend.staticImagesRelativePath
        return rootURL.appendingPathComponent(relativePath, isDirectory: true)
    }

    var archetypesURL: URL? {
        guard backendName == "Hugo" else { return nil }
        return rootURL.appendingPathComponent("archetypes", isDirectory: true)
    }

    var detectedConfigRelativePath: String? {
        let be = backend
        for name in be.configFileNames {
            var isDir = ObjCBool(false)
            let path = rootURL.appendingPathComponent(name).path
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue {
                return name
            }
        }
        return nil
    }

    var localConfigBundleURL: URL {
        rootURL.appendingPathComponent(".nookdesk.local.json", isDirectory: false)
    }

    func contentURL(forSectionPath sectionPath: String) -> URL {
        let trimmed = sectionPath.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return contentURL }
        return contentURL.appendingPathComponent(trimmed, isDirectory: true)
    }

    func withContentSubpath(_ subpath: String) -> BlogProject {
        var copy = self
        copy.contentSubpath = subpath
        return copy
    }

    func renderedHTMLCandidates(for postFileURL: URL) -> [URL] {
        backend.renderedHTMLCandidates(for: postFileURL, project: self)
    }
}
