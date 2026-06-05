import Foundation

struct HugoBackend: SSGBuildBackend {
    let displayName = "Hugo"
    let configFileNames = [
        "hugo.toml", "hugo.yaml", "hugo.yml", "hugo.json",
        "config.toml", "config.yaml", "config.yml", "config.json",
        "config/_default/hugo.toml", "config/_default/hugo.yaml",
        "config/_default/hugo.yml", "config/_default/hugo.json",
        "config/_default/config.toml", "config/_default/config.yaml",
        "config/_default/config.yml", "config/_default/config.json"
    ]
    let contentDirectoryName = "content"
    let buildOutputDirectoryName = "public"
    let workflowFileName = "hugo.yaml"

    func detectProject(in directory: URL) -> Bool {
        let fm = FileManager.default
        for name in configFileNames {
            var isDir = ObjCBool(false)
            let path = directory.appendingPathComponent(name).path
            if fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue {
                return true
            }
        }
        return false
    }

    func buildCommand(project: BlogProject) -> (executable: String, arguments: [String]) {
        (project.buildExecutable, ["--gc", "--minify"])
    }

    func versionCommand(project: BlogProject) -> (executable: String, arguments: [String]) {
        (project.buildExecutable, ["version"])
    }

    func structureCheck(project: BlogProject) -> StructureReport {
        let fm = FileManager.default
        let root = project.rootURL
        let hasConfig = configFileNames.contains { name in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(name).path
            return fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }

        var missingFiles: [String] = []
        if !hasConfig { missingFiles.append("hugo.toml") }

        let requiredDirs = [contentDirectoryName]
        let recommendedDirs = ["archetypes", "assets", "layouts", "static", "themes"]
        let recommendedFiles = [".github/workflows/\(workflowFileName)"]

        let missingRequired = requiredDirs.filter { dir in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(dir).path
            return !(fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue)
        }
        let missingRecDirs = recommendedDirs.filter { dir in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(dir).path
            return !(fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue)
        }
        let missingRecFiles = recommendedFiles.filter { name in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(name).path
            return !(fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue)
        }

        return StructureReport(
            rootPath: project.rootPath,
            missingRequiredFiles: missingFiles,
            missingRequiredDirectories: missingRequired,
            missingRecommendedFiles: missingRecFiles,
            missingRecommendedDirectories: missingRecDirs,
            createdFiles: [],
            createdDirectories: []
        )
    }

    func generateWorkflow(project: BlogProject) -> String {
        """
        # NookDesk: managed Hugo workflow
        name: Deploy Hugo site to Pages

        on:
          push:
            branches:
              - \(project.publishBranch)
          workflow_dispatch:

        permissions:
          contents: read
          pages: write
          id-token: write

        concurrency:
          group: "pages"
          cancel-in-progress: false

        jobs:
          build:
            runs-on: ubuntu-latest
            env:
              HUGO_VERSION: 0.157.0
            steps:
              - name: Checkout
                uses: actions/checkout@v4
                with:
                  fetch-depth: 0
                  submodules: recursive
              - name: Setup Hugo
                uses: peaceiris/actions-hugo@v3
                with:
                  hugo-version: ${{ env.HUGO_VERSION }}
                  extended: true
              - name: Setup Pages
                id: pages
                uses: actions/configure-pages@v5
              - name: Build with Hugo
                run: hugo --gc --minify --baseURL "${{ steps.pages.outputs.base_url }}/"
              - name: Upload artifact
                uses: actions/upload-pages-artifact@v3
                with:
                  path: ./public

          deploy:
            environment:
              name: github-pages
              url: ${{ steps.deployment.outputs.page_url }}
            runs-on: ubuntu-latest
            needs: build
            steps:
              - name: Deploy to GitHub Pages
                id: deployment
                uses: actions/deploy-pages@v4
        """
    }

    func renderedHTMLCandidates(for postFileURL: URL, project: BlogProject) -> [URL] {
        let standardized = postFileURL.standardizedFileURL.path
        let contentRoot = project.contentURL.standardizedFileURL.path
        guard standardized.hasPrefix(contentRoot) else { return [] }
        var relative = String(standardized.dropFirst(contentRoot.count))
        if relative.hasPrefix("/") { relative.removeFirst() }
        let cleaned = URL(fileURLWithPath: relative).deletingPathExtension().path
        guard !cleaned.isEmpty else { return [] }
        let pub = project.rootURL.appendingPathComponent("public", isDirectory: true)
        return [
            pub.appendingPathComponent(cleaned).appendingPathComponent("index.html"),
            pub.appendingPathComponent(cleaned + ".html")
        ]
    }

    func preferredContentSubpath(in rootURL: URL) -> String {
        let fm = FileManager.default
        for dir in ["content/posts", "content/post"] {
            var isDir = ObjCBool(false)
            let path = rootURL.appendingPathComponent(dir).path
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return dir
            }
        }
        return "content/posts"
    }

    func defaultConfigTemplate() -> String {
        """
        baseURL = "/"
        languageCode = "zh-cn"
        title = "My Hugo Site"

        [markup]
          [markup.goldmark]
            [markup.goldmark.renderer]
              unsafe = true

        [params]
          author = ""
        """
    }

    var staticImagesRelativePath: String { "static/images" }
    var workflowDisplayName: String { "Deploy Hugo site to Pages" }
}
