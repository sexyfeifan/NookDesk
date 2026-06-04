import Foundation

final class TypeScriptPostService {

    struct TSPPost {
        var id: String
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

    func postsFilePath(in project: BlogProject) -> URL {
        project.contentURL.appendingPathComponent("posts.ts")
    }

    func loadPosts(from project: BlogProject) throws -> [TSPPost] {
        let url = postsFilePath(in: project)
        let content = try String(contentsOf: url, encoding: .utf8)
        return parsePosts(from: content)
    }

    func savePosts(_ posts: [TSPPost], to project: BlogProject) throws {
        let url = postsFilePath(in: project)
        let ts = renderPostsFile(posts)
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
        let id = UUID().uuidString.prefix(8).lowercased()
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFmt.string(from: Date())
        return TSPPost(
            id: String(id),
            title: title,
            excerpt: "",
            body: "",
            date: dateStr,
            tag: "",
            color: "bg-blue",
            readTime: "1 min read",
            cover: "",
            sections: [],
            takeaways: []
        )
    }

    // MARK: - Parsing

    func parsePosts(from content: String) -> [TSPPost] {
        var posts: [TSPPost] = []

        let objectPattern = #"\{[\s\S]*?id:\s*['"]([^'"]+)['"][\s\S]*?\}"#
        guard let regex = try? NSRegularExpression(pattern: objectPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let ns = content as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        var searchRange = fullRange
        while searchRange.location < ns.length {
            guard let match = regex.firstMatch(in: content, options: [], range: searchRange) else { break }
            let block = ns.substring(with: match.range)
            if let post = parseSinglePost(block) {
                posts.append(post)
            }
            let nextLoc = match.range.location + match.range.length
            searchRange = NSRange(location: nextLoc, length: ns.length - nextLoc)
        }

        return posts
    }

    private func parseSinglePost(_ block: String) -> TSPPost? {
        func extractString(_ key: String) -> String {
            let patterns = [
                #"\#(key):\s*'([^']*)'"#,
                #"\#(key):\s*"([^"]*)""#,
                #"\#(key):\s*`([^`]*)`"#
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: block, range: NSRange(location: 0, length: block.utf16.count)),
                   match.numberOfRanges > 1 {
                    return (block as NSString).substring(with: match.range(at: 1))
                }
            }
            return ""
        }

        func extractArray(_ key: String) -> [String] {
            let pattern = #"\#(key):\s*\[([^\]]*)\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: block, range: NSRange(location: 0, length: block.utf16.count)),
                  match.numberOfRanges > 1 else {
                return []
            }
            let inner = (block as NSString).substring(with: match.range(at: 1))
            return inner.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .map { $0.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "") }
                .filter { !$0.isEmpty }
        }

        func extractSections() -> [TSPSection] {
            var sections: [TSPSection] = []
            let sectionPattern = #"\{\s*heading:\s*'([^']*)',\s*paragraphs:\s*\[([^\]]*)\]\s*\}"#
            guard let regex = try? NSRegularExpression(pattern: sectionPattern, options: [.dotMatchesLineSeparators]) else {
                return []
            }
            let ns = block as NSString
            let range = NSRange(location: 0, length: ns.length)
            let matches = regex.matches(in: block, range: range)
            for m in matches {
                let heading = ns.substring(with: m.range(at: 1))
                let parasRaw = ns.substring(with: m.range(at: 2))
                let paragraphs = parasRaw.components(separatedBy: "',")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .map { $0.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "") }
                    .filter { !$0.isEmpty }
                sections.append(TSPSection(heading: heading, paragraphs: paragraphs))
            }
            return sections
        }

        let id = extractString("id")
        guard !id.isEmpty else { return nil }

        return TSPPost(
            id: id,
            title: extractString("title"),
            excerpt: extractString("excerpt"),
            body: extractString("body"),
            date: extractString("date"),
            tag: extractString("tag"),
            color: extractString("color"),
            readTime: extractString("readTime"),
            cover: extractString("cover"),
            sections: extractSections(),
            takeaways: extractArray("takeaways")
        )
    }

    // MARK: - Rendering

    func renderPostsFile(_ posts: [TSPPost]) -> String {
        var lines: [String] = []
        lines.append("export interface Post {")
        lines.append("  id: string;")
        lines.append("  title: string;")
        lines.append("  excerpt: string;")
        lines.append("  body: string;")
        lines.append("  date: string;")
        lines.append("  tag: string;")
        lines.append("  color: string;")
        lines.append("  readTime: string;")
        lines.append("  cover: string;")
        lines.append("  sections: { heading: string; paragraphs: string[] }[];")
        lines.append("  takeaways: string[];")
        lines.append("}")
        lines.append("")
        lines.append("export const posts: Post[] = [")

        for (index, post) in posts.enumerated() {
            lines.append("  {")
            lines.append("    id: '\(escapeTS(post.id))',")
            lines.append("    title: '\(escapeTS(post.title))',")
            lines.append("    excerpt: '\(escapeTS(post.excerpt))',")
            lines.append("    body: `\(post.body)`,")
            lines.append("    date: '\(escapeTS(post.date))',")
            lines.append("    tag: '\(escapeTS(post.tag))',")
            lines.append("    color: '\(escapeTS(post.color))',")
            lines.append("    readTime: '\(escapeTS(post.readTime))',")
            lines.append("    cover: '\(escapeTS(post.cover))',")
            lines.append("    sections: [")
            for section in post.sections {
                lines.append("      {")
                lines.append("        heading: '\(escapeTS(section.heading))',")
                lines.append("        paragraphs: [")
                for para in section.paragraphs {
                    lines.append("          '\(escapeTS(para))',")
                }
                lines.append("        ],")
                lines.append("      },")
            }
            lines.append("    ],")
            lines.append("    takeaways: [\(post.takeaways.map { "'\(escapeTS($0))'" }.joined(separator: ", "))],")
            lines.append(index < posts.count - 1 ? "  }," : "  }")
        }

        lines.append("];")
        return lines.joined(separator: "\n")
    }

    private func escapeTS(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
