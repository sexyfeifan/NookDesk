import Foundation

struct BlogProject: Codable {
    static let lastRootPathDefaultsKey = "nookdesk.lastProjectRootPath"

    var rootPath: String
    var hugoExecutable: String
    var contentSubpath: String
    var gitRemote: String
    var publishBranch: String
    var backendName: String

    var backend: SSGBuildBackend {
        BackendRegistry.shared.backend(named: backendName) ?? ViteBackend()
    }

    static func bootstrap() -> BlogProject {
        let registry = BackendRegistry.shared

        if let cachedRoot = UserDefaults.standard.string(forKey: lastRootPathDefaultsKey),
           !cachedRoot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cachedURL = URL(fileURLWithPath: cachedRoot, isDirectory: true)
            if let detected = registry.detectBackend(in: cachedURL) {
                return BlogProject(
                    rootPath: cachedURL.path,
                    hugoExecutable: "hugo",
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
            return BlogProject(
                rootPath: cwd.path,
                hugoExecutable: "hugo",
                contentSubpath: detected.preferredContentSubpath(in: cwd),
                gitRemote: "origin",
                publishBranch: "main",
                backendName: detected.displayName
            )
        }

        if let detected = registry.detectBackend(in: parent) {
            return BlogProject(
                rootPath: parent.path,
                hugoExecutable: "hugo",
                contentSubpath: detected.preferredContentSubpath(in: parent),
                gitRemote: "origin",
                publishBranch: "main",
                backendName: detected.displayName
            )
        }

        return BlogProject(
            rootPath: cwd.path,
            hugoExecutable: "hugo",
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
        if backendName == "Hugo" {
            return rootURL.appendingPathComponent("static/images", isDirectory: true)
        }
        return rootURL.appendingPathComponent("public/images", isDirectory: true)
    }

    var archetypesURL: URL {
        rootURL.appendingPathComponent("archetypes", isDirectory: true)
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
