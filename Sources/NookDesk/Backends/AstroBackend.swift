import Foundation

struct AstroBackend: SSGBuildBackend {
    let displayName = "Astro"
    let configFileNames = [
        "astro.config.mjs", "astro.config.ts", "astro.config.js",
        "astro.config.mts", "astro.config.cjs"
    ]
    let contentDirectoryName = "src/content"
    let buildOutputDirectoryName = "dist"
    let workflowFileName = "astro.yml"

    func detectProject(in directory: URL) -> Bool {
        let fm = FileManager.default
        let hasAstroConfig = configFileNames.contains { name in
            var isDir = ObjCBool(false)
            let path = directory.appendingPathComponent(name).path
            return fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }
        let hasPackageJson: Bool = {
            var isDir = ObjCBool(false)
            let path = directory.appendingPathComponent("package.json").path
            return fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }()
        return hasAstroConfig && hasPackageJson
    }

    func buildCommand(project: BlogProject) -> (executable: String, arguments: [String]) {
        let npmPath = resolveNpm(cwd: project.rootURL) ?? "npm"
        return (npmPath, ["run", "build"])
    }

    func versionCommand(project: BlogProject) -> (executable: String, arguments: [String]) {
        let npmPath = resolveNpm(cwd: project.rootURL) ?? "npm"
        return (npmPath, ["--version"])
    }

    func structureCheck(project: BlogProject) -> StructureReport {
        let fm = FileManager.default
        let root = project.rootURL

        let requiredFiles = ["package.json", "astro.config.mjs"]
        let requiredDirs = ["src"]
        let recommendedFiles = ["tsconfig.json"]
        let recommendedDirs = ["src/content", "src/pages", "src/layouts", "public", "node_modules"]
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
        # NookDesk: managed Astro workflow
        name: Deploy Astro site to Pages

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
            steps:
              - name: Checkout
                uses: actions/checkout@v4
              - name: Setup Node
                uses: actions/setup-node@v4
                with:
                  node-version: "20"
                  cache: "npm"
              - name: Install dependencies
                run: npm ci
              - name: Build with Astro
                run: npm run build
              - name: Upload artifact
                uses: actions/upload-pages-artifact@v3
                with:
                  path: ./dist

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
        let dist = project.rootURL.appendingPathComponent("dist", isDirectory: true)
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
            dist.appendingPathComponent("index.html")
        ]
    }

    func preferredContentSubpath(in rootURL: URL) -> String {
        let fm = FileManager.default
        for dir in ["src/content/blog", "src/content/posts", "src/content/post", "src/content"] {
            var isDir = ObjCBool(false)
            let path = rootURL.appendingPathComponent(dir).path
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return dir
            }
        }
        return "src/content/blog"
    }

    func defaultConfigTemplate() -> String {
        """
        import { defineConfig } from 'astro/config';

        export default defineConfig({
          site: 'https://example.com',
          base: '/',
        });
        """
    }

    var staticImagesRelativePath: String { "public/images" }
    var workflowDisplayName: String { "Deploy Astro site to Pages" }

    private func resolveNpm(cwd: URL) -> String? {
        let fm = FileManager.default
        let localNpm = cwd.appendingPathComponent("node_modules/.bin/npm").path
        if fm.isExecutableFile(atPath: localNpm) { return localNpm }
        let roots = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        for root in roots {
            let path = "\(root)/npm"
            if fm.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }
}
