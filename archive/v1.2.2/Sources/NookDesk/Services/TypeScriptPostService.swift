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

    func savePosts(_ posts: [TSPPost], to project: BlogProject, force: Bool = false) throws {
        let url = postsFilePath(in: project)
        let fm = FileManager.default

        // 安全保护（删除操作跳过保护）
        if !force && fm.fileExists(atPath: url.path) {
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

        // 直接使用传入的 posts 数组，不再合并文件里的文章
        // 删除操作传入的是已移除目标文章的数组
        // 保存操作传入的是完整数组（已包含所有文章）
        let ts = renderPostsFile(posts)
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
        try savePosts(posts, to: project, force: true)
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
        // 从用户的 fork 仓库下载（中文字体版本）
        let remoteURLs = [
            "https://raw.githubusercontent.com/sexyfeifan/animal-island-blog/main/src/pages/Home/posts.ts",
            "https://raw.githubusercontent.com/guokaigdg/animal-island-blog/main/src/pages/Home/posts.ts"
        ]
        
        var remotePosts: [TSPPost] = []
        for urlString in remoteURLs {
            if let remoteURL = URL(string: urlString),
               let data = try? Data(contentsOf: remoteURL),
               let content = String(data: data, encoding: .utf8) {
                remotePosts = (try? parsePostsFromContent(content)) ?? []
                if !remotePosts.isEmpty { break }
            }
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
        let patterns = [
            "\(name):\\s*\"((?:[^\"\\\\]|\\\\.)*)\"",
            "\(name):\\s*`((?:[^`\\\\]|\\\\.)*)`",
            "\(name):\\s*'((?:[^'\\\\]|\\\\.)*)'"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: block, range: NSRange(block.startIndex..., in: block)),
               let range = Range(match.range(at: 1), in: block) {
                return String(block[range])
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\\\", with: "\\")
                    .replacingOccurrences(of: "\\r", with: "\r")
            }
        }
        return nil
    }

    private func parseSections(from block: String) -> [TSPSection] {
        var sections: [TSPSection] = []
        guard let sectionsStart = block.range(of: "sections:") else { return [] }
        let afterSections = block[sectionsStart.upperBound...]
        let afterSectionsStr = String(afterSections)
        guard let arrayOpen = afterSectionsStr.firstIndex(of: "[") else { return [] }

        // 找到 sections 数组的结束 ]
        guard let arrayClose = findMatchingBracket(in: afterSectionsStr, from: arrayOpen) else { return [] }
        let arrayContent = String(afterSectionsStr[afterSectionsStr.index(after: arrayOpen)..<arrayClose])

        // 用正则找每个 section 对象
        // 找 heading 和对应的 paragraphs
        let headingPattern = try! NSRegularExpression(pattern: "heading:\\s*\"([^\"]*)\"", options: [])
        let headingMatches = headingPattern.matches(in: arrayContent, range: NSRange(arrayContent.startIndex..., in: arrayContent))

        // 找每个 paragraphs 数组
        let paraArrayPattern = try! NSRegularExpression(pattern: "paragraphs:\\s*\\[", options: [])
        let paraMatches = paraArrayPattern.matches(in: arrayContent, range: NSRange(arrayContent.startIndex..., in: arrayContent))

        for (i, headingMatch) in headingMatches.enumerated() {
            guard let headingRange = Range(headingMatch.range(at: 1), in: arrayContent) else { continue }
            let heading = String(arrayContent[headingRange])

            // 找对应的 paragraphs 数组
            var paragraphs: [String] = []
            if i < paraMatches.count {
                let paraMatch = paraMatches[i]
                // 从 paragraphs: [ 开始找匹配的 ]
                let paraStart = arrayContent.index(arrayContent.startIndex, offsetBy: paraMatch.range.location + paraMatch.range.length - 1)
                if let paraClose = findMatchingBracket(in: arrayContent, from: paraStart) {
                    let paraContent = String(arrayContent[arrayContent.index(after: paraStart)..<paraClose])
                    let strPattern = try! NSRegularExpression(pattern: "\"([^\"]*)\"", options: [])
                    let strMatches = strPattern.matches(in: paraContent, range: NSRange(paraContent.startIndex..., in: paraContent))
                    for strMatch in strMatches {
                        if let strRange = Range(strMatch.range(at: 1), in: paraContent) {
                            paragraphs.append(String(paraContent[strRange])
                                .replacingOccurrences(of: "\\\"", with: "\"")
                                .replacingOccurrences(of: "\\n", with: "\n"))
                        }
                    }
                }
            }

            sections.append(TSPSection(heading: heading, paragraphs: paragraphs))
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
        var inString = false
        var stringDelim: Character = "'"
        while i < text.endIndex {
            let c = text[i]
            if inString {
                if c == "\\" {
                    i = text.index(after: i)
                    if i < text.endIndex { i = text.index(after: i) }
                    continue
                }
                if c == stringDelim { inString = false }
            } else {
                if c == "'" || c == "\"" || c == "`" {
                    inString = true
                    stringDelim = c
                } else if c == "[" {
                    depth += 1
                } else if c == "]" {
                    depth -= 1
                    if depth == 0 { return i }
                }
            }
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

        for (postIndex, post) in posts.enumerated() {
            let isLastPost = postIndex == posts.count - 1
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

            if post.sections.isEmpty {
                lines.append("        sections: [],")
            } else {
                lines.append("        sections: [")
                for (sIdx, section) in post.sections.enumerated() {
                    let isLastSection = sIdx == post.sections.count - 1
                    let sComma = isLastSection ? "" : ","
                    lines.append("            {")
                    lines.append("                heading: \"\(escapeDQ(section.heading))\",")
                    if section.paragraphs.isEmpty {
                        lines.append("                paragraphs: []")
                    } else {
                        lines.append("                paragraphs: [")
                        for (pIdx, para) in section.paragraphs.enumerated() {
                            let isLastPara = pIdx == section.paragraphs.count - 1
                            let pComma = isLastPara ? "" : ","
                            lines.append("                    \"\(escapeDQ(para))\"\(pComma)")
                        }
                        lines.append("                ]")
                    }
                    lines.append("            }\(sComma)")
                }
                lines.append("        ],")
            }

            if post.takeaways.isEmpty {
                lines.append("        takeaways: []")
            } else {
                lines.append("        takeaways: [")
                for (tIdx, takeaway) in post.takeaways.enumerated() {
                    let isLastTakeaway = tIdx == post.takeaways.count - 1
                    let tComma = isLastTakeaway ? "" : ","
                    lines.append("            \"\(escapeDQ(takeaway))\"\(tComma)")
                }
                lines.append("        ]")
            }

            let postComma = isLastPost ? "" : ","
            lines.append("    }\(postComma)")
        }

        lines.append("];")
        lines.append("")
        lines.append("export const getPostById = (id: string) => posts.find((p) => p.id === id);")

        let result = lines.joined(separator: "\n")
        validateRenderedOutput(result)
        return result
    }

    private func validateRenderedOutput(_ content: String) {
        for (lineNum, line) in content.components(separatedBy: "\n").enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "," {
                print("[NookDesk] ⚠️ BUG: Orphan comma at line \(lineNum + 1) — this should never happen")
            }
        }
    }

    private func escapeDQ(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
    }
}
