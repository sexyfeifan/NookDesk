import Foundation

struct TSPPost: Identifiable {
    let id: String
    var title: String
    var excerpt: String
    var body: String
    var date: String
    var tag: String
    var color: String
    var readTime: String
    var cover: String
    var sections: [TSPSection]
    var takeaways: [String]
}

struct TSPSection {
    var heading: String
    var paragraphs: [String]
}

final class TypeScriptPostService: @unchecked Sendable {
    private let runner = ProcessRunner()

    func postsFilePath(in project: BlogProject) -> URL {
        project.contentURL.appendingPathComponent("posts.ts")
    }

    func loadPosts(from project: BlogProject) throws -> [TSPPost] {
        let url = postsFilePath(in: project)
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return [] }

        // 用 esbuild + node 读取 posts.ts → JSON
        let json = try readPostsViaNode(postsFile: url, cwd: project.rootURL)
        return try parseJSONPosts(json)
    }

    func savePosts(_ posts: [TSPPost], to project: BlogProject) throws {
        let url = postsFilePath(in: project)
        let fm = FileManager.default

        // 安全保护：检查文件是否已有内容但解析失败
        if fm.fileExists(atPath: url.path) {
            if let existingContent = try? String(contentsOf: url, encoding: .utf8) {
                let hasContent = existingContent.contains("id:") && existingContent.count > 1000
                let parsed = (try? loadPosts(from: project)) ?? []
                if hasContent && parsed.isEmpty {
                    throw NSError(domain: "NookDesk", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "安全保护：posts.ts 有 \(existingContent.count) 字节内容但解析失败（0 篇），拒绝覆盖。请点击「恢复」按钮。"
                    ])
                }
            }
        }

        // 合并已有文章
        var existingMap: [String: TSPPost] = [:]
        if let existing = try? loadPosts(from: project) {
            for p in existing { existingMap[p.id] = p }
        }
        for p in posts { existingMap[p.id] = p }
        let merged = existingMap.values.map { $0 }

        // 生成 TypeScript
        let ts = renderPostsFile(merged)
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try ts.write(to: url, atomically: true, encoding: .utf8)
    }

    func addPost(_ post: TSPPost, to project: BlogProject) throws -> [TSPPost] {
        var posts = (try? loadPosts(from: project)) ?? []
        posts.insert(post, at: 0)
        try savePosts(posts, to: project)
        return posts
    }

    func updatePost(_ post: TSPPost, in project: BlogProject) throws -> [TSPPost] {
        var posts = (try? loadPosts(from: project)) ?? []
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx] = post
        }
        try savePosts(posts, to: project)
        return posts
    }

    func deletePost(id: String, in project: BlogProject) throws -> [TSPPost] {
        var posts = (try? loadPosts(from: project)) ?? []
        posts.removeAll { $0.id == id }
        try savePosts(posts, to: project)
        return posts
    }

    func makeNewPost(title: String) -> TSPPost {
        TSPPost(
            id: UUID().uuidString.prefix(8).lowercased(),
            title: title.isEmpty ? "未命名文章" : title,
            excerpt: "",
            body: "",
            date: DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none),
            tag: "Blog",
            color: "app-blue",
            readTime: "5 分钟",
            cover: "📝",
            sections: [],
            takeaways: []
        )
    }

    func restoreFromGit(project: BlogProject) throws -> [TSPPost] {
        let url = postsFilePath(in: project)
        // 从原始仓库下载
        if let remoteURL = URL(string: "https://raw.githubusercontent.com/guokaigdg/animal-island-blog/main/src/pages/Home/posts.ts"),
           let data = try? Data(contentsOf: remoteURL),
           let content = String(data: data, encoding: .utf8) {
            try content.write(to: url, atomically: true, encoding: .utf8)
        }
        return try loadPosts(from: project)
    }

    // MARK: - Node.js 读取

    private func readPostsViaNode(postsFile: URL, cwd: URL) throws -> String {
        // 1. 用 esbuild 转译
        let tmpFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nookdesk-\(UUID().uuidString.prefix(8)).mjs")
        
        let esbuildResult = try runner.run(
            command: "npx",
            arguments: ["esbuild", postsFile.path, "--bundle", "--format=esm", "--outfile=\(tmpFile.path)"],
            in: cwd
        )
        
        guard esbuildResult.exitCode == 0 else {
            throw NSError(domain: "NookDesk", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "esbuild 转译失败：\(esbuildResult.stderr)"
            ])
        }
        
        // 2. 用 node 读取 JSON
        let nodeScript = """
        import { posts } from '\(tmpFile.path.replacingOccurrences(of: "'", with: "\\'"))';
        console.log(JSON.stringify(posts));
        """
        
        let nodeResult = try runner.run(
            command: "node",
            arguments: ["--input-type=module", "-e", nodeScript],
            in: cwd
        )
        
        // 清理临时文件
        try? FileManager.default.removeItem(at: tmpFile)
        
        guard nodeResult.exitCode == 0 else {
            throw NSError(domain: "NookDesk", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Node.js 读取失败：\(nodeResult.stderr)"
            ])
        }
        
        return nodeResult.stdout
    }

    private func parseJSONPosts(_ json: String) throws -> [TSPPost] {
        guard let data = json.data(using: .utf8) else {
            throw NSError(domain: "NookDesk", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "JSON 数据为空"
            ])
        }
        
        let decoder = JSONDecoder()
        let rawPosts = try decoder.decode([RawPost].self, from: data)
        
        return rawPosts.map { raw in
            TSPPost(
                id: raw.id,
                title: raw.title,
                excerpt: raw.excerpt,
                body: raw.body,
                date: raw.date,
                tag: raw.tag,
                color: raw.color,
                readTime: raw.readTime,
                cover: raw.cover,
                sections: raw.sections.map { TSPSection(heading: $0.heading, paragraphs: $0.paragraphs) },
                takeaways: raw.takeaways
            )
        }
    }

    // MARK: - TypeScript 生成

    private func renderPostsFile(_ posts: [TSPPost]) -> String {
        var lines: [String] = []
        lines.append("export type BlogColor =")
        lines.append("    | \"app-pink\"")
        lines.append("    | \"purple\"")
        lines.append("    | \"app-blue\"")
        lines.append("    | \"app-yellow\"")
        lines.append("    | \"app-orange\"")
        lines.append("    | \"app-teal\"")
        lines.append("    | \"app-green\"")
        lines.append("    | \"app-red\"")
        lines.append("    | \"lime-green\"")
        lines.append("    | \"yellow-green\"")
        lines.append("    | \"brown\"")
        lines.append("    | \"warm-peach-pink\";")
        lines.append("")
        lines.append("export interface PostSection {")
        lines.append("    heading: string;")
        lines.append("    paragraphs: string[];")
        lines.append("}")
        lines.append("")
        lines.append("export interface Post {")
        lines.append("    id: string;")
        lines.append("    title: string;")
        lines.append("    excerpt: string;")
        lines.append("    body: string;")
        lines.append("    date: string;")
        lines.append("    tag: string;")
        lines.append("    color: BlogColor;")
        lines.append("    readTime: string;")
        lines.append("    cover: string;")
        lines.append("    sections: PostSection[];")
        lines.append("    takeaways: string[];")
        lines.append("}")
        lines.append("")
        lines.append("export const posts: Post[] = [")

        for (index, post) in posts.enumerated() {
            lines.append("    {")
            lines.append("        id: \"\(escapeDQ(post.id))\",")
            lines.append("        title: \"\(escapeDQ(post.title))\",")
            lines.append("        excerpt: \"\(escapeDQ(post.excerpt))\",")
            lines.append("        body: `\(escapeBacktick(post.body))`,")
            lines.append("        date: \"\(escapeDQ(post.date))\",")
            lines.append("        tag: \"\(escapeDQ(post.tag))\",")
            lines.append("        color: \"\(escapeDQ(post.color))\",")
            lines.append("        readTime: \"\(escapeDQ(post.readTime))\",")
            lines.append("        cover: \"\(escapeDQ(post.cover))\",")
            lines.append("        sections: [")
            for section in post.sections {
                lines.append("            {")
                lines.append("                heading: \"\(escapeDQ(section.heading))\",")
                lines.append("                paragraphs: [")
                for para in section.paragraphs {
                    lines.append("                    \"\(escapeDQ(para))\",")
                }
                lines.append("                ],")
                lines.append("            },")
            }
            lines.append("        ],")
            lines.append("        takeaways: [")
            for takeaway in post.takeaways {
                lines.append("            \"\(escapeDQ(takeaway))\",")
            }
            lines.append("        ],")
            lines.append("    \(index < posts.count - 1 ? "," : "")")
        }

        lines.append("];")
        lines.append("")
        lines.append("export const getPostById = (id: string) => posts.find((p) => p.id === id);")
        return lines.joined(separator: "\n")
    }

    private func escapeDQ(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func escapeBacktick(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "`", with: "\\`")
         .replacingOccurrences(of: "$", with: "\\$")
    }
}

// MARK: - JSON 解码用的原始结构

private struct RawPost: Codable {
    let id: String
    let title: String
    let excerpt: String
    let body: String
    let date: String
    let tag: String
    let color: String
    let readTime: String
    let cover: String
    let sections: [RawSection]
    let takeaways: [String]
}

private struct RawSection: Codable {
    let heading: String
    let paragraphs: [String]
}
