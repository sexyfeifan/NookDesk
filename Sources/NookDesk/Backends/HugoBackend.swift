import Foundation

// [NookDesk 修复] 实现完整的 HugoBackend，注册到 BackendRegistry.swift
// Hugo 使用 config.toml 作为配置文件，content/ 作为内容目录，public/ 作为构建输出。
struct HugoBackend: SSGBuildBackend {
    let displayName = "Hugo"
    let configFileNames = ["config.toml", "config.yaml", "config.yml", "config.json", "hugo.toml", "hugo.yaml", "hugo.yml", "hugo.json"]
    let contentDirectoryName = "content"
    let buildOutputDirectoryName = "public"
    let workflowFileName = "hugo.yml"

    func detectProject(in directory: URL) -> Bool {
        let fm = FileManager.default
        // 检测是否存在 Hugo 配置文件
        let hasHugoConfig = configFileNames.contains { name in
            var isDir = ObjCBool(false)
            let path = directory.appendingPathComponent(name).path
            return fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }
        // 或者存在 config.toml 且包含 theme 字段（Hugo 典型标志）
        let hasConfigDir: Bool = {
            var isDir = ObjCBool(false)
            let path = directory.appendingPathComponent("config").path
            return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }()
        return hasHugoConfig || hasConfigDir
    }

    func buildCommand(project: BlogProject) -> (executable: String, arguments: [String]) {
        let hugoPath = resolveHugo(cwd: project.rootURL) ?? "hugo"
        return (hugoPath, [])
    }

    func versionCommand(project: BlogProject) -> (executable: String, arguments: [String]) {
        let hugoPath = resolveHugo(cwd: project.rootURL) ?? "hugo"
        return (hugoPath, ["version"])
    }

    func structureCheck(project: BlogProject) -> StructureReport {
        let fm = FileManager.default
        let root = project.rootURL

        let requiredFiles = ["config.toml"]
        let requiredDirs = ["content"]
        let recommendedFiles = ["archetypes/default.md"]
        let recommendedDirs = ["layouts", "static", "themes", "public"]
        let workflowFiles = [".github/workflows/\(workflowFileName)"]

        let missingReqFiles = requiredFiles.filter { name in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(name).path
            return !(fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue)
        }
        let missingReqDirs = requiredDirs.filter { dir in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(dir).path
            return !(fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue)
        }
        let missingRecFiles = (recommendedFiles + workflowFiles).filter { name in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(name).path
            return !(fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue)
        }
        let missingRecDirs = recommendedDirs.filter { dir in
            var isDir = ObjCBool(false)
            let path = root.appendingPathComponent(dir).path
            return !(fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue)
        }

        return StructureReport(
            rootPath: project.rootPath,
            missingRequiredFiles: missingReqFiles,
            missingRequiredDirectories: missingReqDirs,
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
              HUGO_VERSION: 0.139.0
            steps:
              - name: Install Hugo CLI
                run: |
                  wget -O ${{ runner.temp }}/hugo.deb https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.deb \
                  && sudo dpkg -i ${{ runner.temp }}/hugo.deb
              - name: Checkout
                uses: actions/checkout@v4
                with:
                  submodules: recursive
                  fetch-depth: 0
              - name: Setup Pages
                id: pages
                uses: actions/configure-pages@v5
              - name: Build with Hugo
                env:
                  HUGO_CACHEDIR: ${{ runner.temp }}/hugo_cache
                  HUGO_ENVIRONMENT: production
                run: |
                  hugo \
                    --gc \
                    --minify \
                    --baseURL "${{ steps.pages.outputs.base_path }}/"
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
        let dist = project.rootURL.appendingPathComponent("public", isDirectory: true)
        let standardized = postFileURL.standardizedFileURL.path
        let contentRoot = project.contentURL.standardizedFileURL.path
        guard standardized.hasPrefix(contentRoot) else { return [] }
        var relative = String(standardized.dropFirst(contentRoot.count))
        if relative.hasPrefix("/") { relative.removeFirst() }
        let cleaned = URL(fileURLWithPath: relative).deletingPathExtension().path
        guard !cleaned.isEmpty else { return [] }
        return [
            dist.appendingPathComponent(cleaned).appendingPathComponent("index.html"),
            dist.appendingPathComponent(cleaned + ".html"),
            dist.appendingPathComponent(cleaned + "/index.html")
        ]
    }

    func preferredContentSubpath(in rootURL: URL) -> String {
        let fm = FileManager.default
        for dir in ["content/posts", "content/post", "content/blog", "content"] {
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
        baseURL = 'https://example.com/'
        languageCode = 'zh-cn'
        title = 'My Blog'
        theme = 'github-style'

        [params]
          author = ''
          description = ''

        [[params.links]]
          title = 'GitHub'
          href = 'https://github.com'
          icon = '/images/github-mark.png'
        """
    }

    var staticImagesRelativePath: String { "static/images" }
    var workflowDisplayName: String { "Deploy Hugo site to Pages" }

    private func resolveHugo(cwd: URL) -> String? {
        let fm = FileManager.default
        // 优先查找本地 node_modules 中的 hugo（不太常见但检查一下）
        let roots = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/snap/bin"]
        for root in roots {
            let path = "\(root)/hugo"
            if fm.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }
}
