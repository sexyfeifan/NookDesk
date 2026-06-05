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
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parsePostsFromContent(content)
    }

    func savePosts(_ posts: [TSPPost], to project: BlogProject) throws {
        let url = postsFilePath(in: project)
        let fm = FileManager.default

        // 安全保护
        if fm.fileExists(atPath: url.path) {
            if let existingContent = try? String(contentsOf: url, encoding: .utf8) {
                let hasContent = existingContent.count > 500
                let parsed = (try? parsePostsFromContent(existingContent)) ?? []
                if hasContent && parsed.isEmpty {
                    throw NSError(domain: "NookDesk", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "安全保护：posts.ts 有内容但解析失败，拒绝覆盖。请点击「恢复」按钮。"
                    ])
                }
            }
        }

        var existingMap: [String: TSPPost] = [:]
        if let existing = try? loadPosts(from: project) {
            for p in existing { existingMap[p.id] = p }
        }
        for p in posts { existingMap[p.id] = p }
        let merged = existingMap.values.sorted { $0.id < $1.id }

        let ts = renderPostsFile(merged)
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try ts.write(to: url, atomically: true, encoding: .utf8)
    }

    func addPost(_ post: TSPPost, to project: BlogProject) throws -> [TSPPost] {
        var posts = (try? loadPosts(from: project)) ?? []
        posts.insert(post, at: 0)
        try savePosts(posts, to: project)
        return try loadPosts(from: project)
    }

    func updatePost(_ post: TSPPost, in project: BlogProject) throws -> [TSPPost] {
        var posts = (try? loadPosts(from: project)) ?? []
        if let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx] = post
        }
        try savePosts(posts, to: project)
        return try loadPosts(from: project)
    }

    func deletePost(id: String, in project: BlogProject) throws -> [TSPPost] {
        var posts = (try? loadPosts(from: project)) ?? []
        posts.removeAll { $0.id == id }
        try savePosts(posts, to: project)
        return try loadPosts(from: project)
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
        // 从原始仓库下载并合并
        var remotePosts: [TSPPost] = []
        if let remoteURL = URL(string: "https://raw.githubusercontent.com/guokaigdg/animal-island-blog/main/src/pages/Home/posts.ts"),
           let data = try? Data(contentsOf: remoteURL),
           let content = String(data: data, encoding: .utf8) {
            remotePosts = (try? parsePostsFromContent(content)) ?? []
        }

        let localPosts = (try? loadPosts(from: project)) ?? []

        // 合并：本地优先
        var merged: [String: TSPPost] = [:]
        for p in remotePosts { merged[p.id] = p }
        for p in localPosts { merged[p.id] = p }

        let result = Array(merged.values).sorted { $0.id < $1.id }
        try savePosts(result, to: project)
        return try loadPosts(from: project)
    }

    // MARK: - 纯 Swift 解析器（不依赖 esbuild/Node.js）

    private func parsePostsFromContent(_ content: String) throws -> [TSPPost] {
        var posts: [TSPPost] = []

        // 找到 posts 数组
        guard let arrayStart = content.range(of: "export const posts") else { return [] }
        let afterPosts = content[arrayStart.upperBound...]
        guard let eqIndex = afterPosts.firstIndex(of: "=") else { return [] }
        let afterEq = afterPosts[afterPosts.index(after: eqIndex)...]
        guard let bracketOpen = afterEq.firstIndex(of: "[") else { return [] }

        // 找到每个 post 对象的 { }
        var searchStart = bracketOpen
        while searchStart < content.endIndex {
            guard let objOpen = content[searchStart...].firstIndex(of: "{") else { break }
            guard let objClose = findMatchingBrace(in: content, from: objOpen) else { break }

            let block = String(content[objOpen...objClose])
            if let post = parsePostBlock(block) {
                posts.append(post)
            }

            searchStart = content.index(after: objClose)
        }

        return posts
    }

    private func findMatchingBrace(in content: String, from openBrace: String.Index) -> String.Index? {
        var depth = 0
        var i = openBrace
        var inString = false
        var stringDelim: Character = "'"

        while i < content.endIndex {
            let c = content[i]
            if inString {
                if c == "\\" {
                    i = content.index(after: i)
                    if i < content.endIndex { i = content.index(after: i) }
                    continue
                }
                if c == stringDelim { inString = false }
            } else {
                if c == "'" || c == "\"" || c == "`" {
                    inString = true
                    stringDelim = c
                } else if c == "{" {
                    depth += 1
                } else if c == "}" {
                    depth -= 1
                    if depth == 0 { return i }
                }
            }
            i = content.index(after: i)
        }
        return nil
    }

    private func parsePostBlock(_ block: String) -> TSPPost? {
        guard let id = extractField("id", from: block) else { return nil }

        return TSPPost(
            id: id,
            title: extractField("title", from: block) ?? "",
            excerpt: extractField("excerpt", from: block) ?? "",
            body: extractField("body", from: block) ?? "",
            date: extractField("date", from: block) ?? "",
            tag: extractField("tag", from: block) ?? "",
            color: extractField("color", from: block) ?? "app-blue",
            readTime: extractField("readTime", from: block) ?? "",
            cover: extractField("cover", from: block) ?? "",
            sections: parseSections(from: block),
            takeaways: parseStringArray("takeaways", from: block)
        )
    }

    private func extractField(_ name: String, from block: String) -> String? {
        // 匹配 name: "value" 或 name: `value`
        let patterns = [
            "\(name):\\s*\"([^\"]*)\"",
            "\(name):\\s*`([^`]*)`",
            "\(name):\\s*'([^']*)'"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
               let range = Range(match.range(at: 1), in: block) {
                return String(block[range])
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            }
        }
        return nil
    }

    private func parseSections(from block: String) -> [TSPSection] {
        var sections: [TSPSection] = []
        guard let sectionsStart = block.range(of: "sections:") else { return [] }
        let afterSections = block[sectionsStart.upperBound...]
        guard let arrayOpen = afterSections.firstIndex(of: "[") else { return [] }

        var searchStart = arrayOpen
        while searchStart < afterSections.endIndex {
            guard let objOpen = afterSections[searchStart...].firstIndex(of: "{") else { break }
            // 找到这个 section 对象的结束 }
            let sectionBlock = String(afterSections[objOpen...])
            guard let objClose = findMatchingBrace(in: sectionBlock, from: sectionBlock.startIndex) else { break }
            let sBlock = String(sectionBlock[sectionBlock.startIndex...objClose])

            if let heading = extractField("heading", from: sBlock) {
                let paragraphs = parseStringArray("paragraphs", from: sBlock)
                sections.append(TSPSection(heading: heading, paragraphs: paragraphs))
            }

            searchStart = afterSections.index(after: afterSections.index(objOpen, offsetBy: objClose.utf16Offset(in: sectionBlock)))
        }

        return sections
    }

    private func parseStringArray(_ name: String, from block: String) -> [String] {
        guard let arrayStart = block.range(of: "\(name):") else { return [] }
        let afterArray = block[arrayStart.upperBound...]
        guard let openBracket = afterArray.firstIndex(of: "[") else { return [] }
        guard let closeBracket = findMatchingBracket(in: String(afterArray), from: openBracket) else { return [] }

        let arrayContent = String(afterArray[afterArray.index(after: openBracket)..<closeBracket])

        // 提取所有引号内的字符串
        var items: [String] = []
        let pattern = "\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: arrayContent, range: NSRange(arrayContent.startIndex..., in: arrayContent))
            for match in matches {
                if let range = Range(match.range(at: 1), in: arrayContent) {
                    items.append(String(arrayContent[range])
                        .replacingOccurrences(of: "\\\"", with: "\"")
                        .replacingOccurrences(of: "\\n", with: "\n"))
                }
            }
        }
        return items
    }

    private func findMatchingBracket(in text: String, from openBracket: String.Index) -> String.Index? {
        var depth = 0
        var i = openBracket
        while i < text.endIndex {
            let c = text[i]
            if c == "[" { depth += 1 }
            if c == "]" { depth -= 1; if depth == 0 { return i } }
            i = text.index(after: i)
        }
        return nil
    }

    // MARK: - TypeScript 生成

    func renderPostsFile(_ posts: [TSPPost]) -> String {
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
            lines.append("        body: \"\(escapeDQ(post.body))\",")
            lines.append("        date: \"\(escapeDQ(post.date))\",")
            lines.append("        tag: \"\(escapeDQ(post.tag))\",")
            lines.append("        color: \"\(escapeDQ(post.color))\",")
            lines.append("        readTime: \"\(escapeDQ(post.readTime))\",")
            lines.append("        cover: \"\(escapeDQ(post.cover))\",")
            lines.append("        sections: [")
            if post.sections.isEmpty {
                lines.append("        ],")
            } else {
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
            }
            lines.append("        takeaways: [")
            if post.takeaways.isEmpty {
                lines.append("        ],")
            } else {
                for takeaway in post.takeaways {
                    lines.append("            \"\(escapeDQ(takeaway))\",")
                }
                lines.append("        ],")
            }
            lines.append("    }\(index < posts.count - 1 ? "," : "")")
        }

        lines.append("];")
        lines.append("")
        lines.append("export const getPostById = (id: string) => posts.find((p) => p.id === id);")
        return lines.joined(separator: "\n")
    }

    private func escapeDQ(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
    }
}
