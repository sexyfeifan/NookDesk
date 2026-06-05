import Foundation

struct ViteBackend: SSGBuildBackend {
    let displayName = "Vite + React"
    let configFileNames = [
        "vite.config.ts", "vite.config.js",
        "vite.config.mts", "vite.config.mjs"
    ]
    let contentDirectoryName = "src"
    let buildOutputDirectoryName = "dist"
    let workflowFileName = "deploy.yml"

    func detectProject(in directory: URL) -> Bool {
        let fm = FileManager.default
        let hasViteConfig = configFileNames.contains { name in
            var isDir = ObjCBool(false)
            let path = directory.appendingPathComponent(name).path
            return fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }
        let hasPackageJson: Bool = {
            var isDir = ObjCBool(false)
            let path = directory.appendingPathComponent("package.json").path
            return fm.fileExists(atPath: path, isDirectory: &isDir) && !isDir.boolValue
        }()
        return hasViteConfig && hasPackageJson
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

        let requiredFiles = ["package.json", "index.html"]
        let requiredDirs = ["src"]
        let recommendedFiles = ["tsconfig.json", "vite.config.ts"]
        let recommendedDirs = ["src/pages", "node_modules"]
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
        # NookDesk: managed Vite workflow
        name: Deploy to GitHub Pages

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
              - name: Build
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
        return [
            dist.appendingPathComponent("index.html")
        ]
    }

    func preferredContentSubpath(in rootURL: URL) -> String {
        let fm = FileManager.default
        for dir in ["src/pages/Home", "src/pages", "src/content", "src/posts"] {
            var isDir = ObjCBool(false)
            let path = rootURL.appendingPathComponent(dir).path
            if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return dir
            }
        }
        return "src/pages/Home"
    }

    func defaultConfigTemplate() -> String {
        """
        import { defineConfig } from "vite";
        import react from "@vitejs/plugin-react";

        export default defineConfig({
          base: "/",
          plugins: [react()],
          css: {
            preprocessorOptions: {
              less: { javascriptEnabled: true },
            },
          },
        });
        """
    }

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

    var staticImagesRelativePath: String { "public/images" }
    var workflowDisplayName: String { "Deploy to GitHub Pages" }
}
