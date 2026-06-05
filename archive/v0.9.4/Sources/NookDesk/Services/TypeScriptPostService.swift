import Foundation

final class TypeScriptPostService {

    struct TSPPost: Identifiable {
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
        var existingMap: [String: TSPPost] = [:]
        if let existing = try? loadPosts(from: project) {
            for p in existing { existingMap[p.id] = p }
        }
        for p in posts { existingMap[p.id] = p }
        let merged = existingMap.values.map { $0 }
        let ts = renderPostsFile(merged)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
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
            tag: "Blog",
            color: "app-blue",
            readTime: "5 分钟",
            cover: "📝",
            sections: [],
            takeaways: []
        )
    }

    func restoreFromGit(project: BlogProject) throws -> [TSPPost] {
        let runner = ProcessRunner()
        _ = try runner.run(command: "git", arguments: ["checkout", "HEAD", "--", "src/pages/Home/posts.ts"], in: project.rootURL)
        return try loadPosts(from: project)
    }

    // MARK: - Parsing

    func parsePosts(from content: String) -> [TSPPost] {
        guard let arrayStart = content.range(of: "export const posts") else { return [] }
        let afterPosts = content[arrayStart.upperBound...]
        guard let eqIndex = afterPosts.firstIndex(of: "=") else { return [] }
        let afterEq = afterPosts[afterPosts.index(after: eqIndex)...]
        guard let bracketOpen = afterEq.firstIndex(of: "[") else {
            return []
        }

        let fromBracket = content[bracketOpen...]
        guard let arrayEnd = findMatchingBracket(in: String(fromBracket), openAt: fromBracket.startIndex) else {
            return []
        }

        let arrayInner = content[content.index(after: bracketOpen)..<arrayEnd]
        var posts: [TSPPost] = []
        var searchStart = arrayInner.startIndex

        while searchStart < arrayInner.endIndex {
            guard let objOpen = arrayInner[searchStart...].firstIndex(of: "{") else { break }
            guard let objClose = findMatchingObjectBrace(in: arrayInner, openAt: objOpen) else { break }
            let block = String(arrayInner[objOpen...objClose])
            if let post = parseSinglePost(block) {
                posts.append(post)
            }
            searchStart = arrayInner.index(after: objClose)
        }

        return posts
    }

    private func parseSinglePost(_ block: String) -> TSPPost? {
        func extractQuotedString(_ key: String) -> String {
            guard let keyRange = block.range(of: "\(key):") else { return "" }
            let afterKey = String(block[keyRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !afterKey.isEmpty else { return "" }

            let delimiter: Character = afterKey.first!
            let closingDelim: String
            switch delimiter {
            case "'": closingDelim = "'"
            case "\"": closingDelim = "\""
            case "`": closingDelim = "`"
            default: return ""
            }

            let afterOpen = String(afterKey.dropFirst())
            if let closeIdx = findUnescapedClose(in: afterOpen, closing: closingDelim.first!) {
                return String(afterOpen[afterOpen.startIndex..<closeIdx])
            }
            return ""
        }

        func extractArray(_ key: String) -> [String] {
            guard let keyRange = block.range(of: "\(key):") else { return [] }
            let afterKey = String(block[keyRange.upperBound...])
            guard let openBracket = afterKey.firstIndex(of: "["),
                  let closeBracket = findMatchingBracket(in: afterKey, openAt: openBracket) else {
                return []
            }
            let inner = afterKey[afterKey.index(after: openBracket)..<closeBracket]
            return parseArrayElements(String(inner))
        }

        func extractSections() -> [TSPSection] {
            var sections: [TSPSection] = []
            guard let sectionsRange = block.range(of: "sections:") else { return [] }
            let afterSections = String(block[sectionsRange.upperBound...])
            guard let openBracket = afterSections.firstIndex(of: "["),
                  let closeBracket = findMatchingBracket(in: afterSections, openAt: openBracket) else {
                return []
            }
            let sectionsInner = afterSections[afterSections.index(after: openBracket)..<closeBracket]

            var searchStart = sectionsInner.startIndex
            while searchStart < sectionsInner.endIndex {
                guard let objOpen = sectionsInner[searchStart...].firstIndex(of: "{") else { break }
                guard let objClose = findMatchingObjectBrace(in: sectionsInner, openAt: objOpen) else { break }
                let objBody = sectionsInner[sectionsInner.index(after: objOpen)..<objClose]

                let heading = extractQuotedStringFromSlice("heading", in: String(objBody))
                let paragraphs = extractParagraphsFromSlice(String(objBody))
                if !heading.isEmpty || !paragraphs.isEmpty {
                    sections.append(TSPSection(heading: heading, paragraphs: paragraphs))
                }
                searchStart = sectionsInner.index(after: objClose)
            }
            return sections
        }

        func extractQuotedStringFromSlice(_ key: String, in slice: String) -> String {
            guard let keyRange = slice.range(of: "\(key):") else { return "" }
            let afterKey = String(slice[keyRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !afterKey.isEmpty else { return "" }
            let delimiter: Character = afterKey.first!
            let closingDelim: Character
            switch delimiter {
            case "'": closingDelim = "'"
            case "\"": closingDelim = "\""
            default: return ""
            }
            let afterOpen = String(afterKey.dropFirst())
            if let closeIdx = findUnescapedClose(in: afterOpen, closing: closingDelim) {
                return String(afterOpen[afterOpen.startIndex..<closeIdx])
            }
            return ""
        }

        func extractParagraphsFromSlice(_ slice: String) -> [String] {
            guard let paraRange = slice.range(of: "paragraphs:") else { return [] }
            let afterPara = String(slice[paraRange.upperBound...])
            guard let openBracket = afterPara.firstIndex(of: "["),
                  let closeBracket = findMatchingBracket(in: afterPara, openAt: openBracket) else {
                return []
            }
            let inner = afterPara[afterPara.index(after: openBracket)..<closeBracket]
            return parseArrayElements(String(inner))
        }

        let id = extractQuotedString("id")
        guard !id.isEmpty else { return nil }

        return TSPPost(
            id: id,
            title: extractQuotedString("title"),
            excerpt: extractQuotedString("excerpt"),
            body: extractQuotedString("body"),
            date: extractQuotedString("date"),
            tag: extractQuotedString("tag"),
            color: extractQuotedString("color"),
            readTime: extractQuotedString("readTime"),
            cover: extractQuotedString("cover"),
            sections: extractSections(),
            takeaways: extractArray("takeaways")
        )
    }

    // MARK: - Bracket / Brace Matching

    private func findUnescapedClose(in text: String, closing: Character) -> String.Index? {
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "\\" {
                i = text.index(after: i)
                if i < text.endIndex { i = text.index(after: i) }
                continue
            }
            if text[i] == closing {
                return i
            }
            i = text.index(after: i)
        }
        return nil
    }

    private func findMatchingBracket(in text: String, openAt: String.Index) -> String.Index? {
        var depth = 0
        var i = openAt
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
                if c == stringDelim {
                    inString = false
                }
            } else {
                if c == "'" || c == "\"" {
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

    private func findMatchingObjectBrace(in text: Substring, openAt: String.Index) -> String.Index? {
        var depth = 0
        var i = openAt
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
                if c == "'" || c == "\"" {
                    inString = true
                    stringDelim = c
                } else if c == "{" {
                    depth += 1
                } else if c == "}" {
                    depth -= 1
                    if depth == 0 { return i }
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private func parseArrayElements(_ inner: String) -> [String] {
        var results: [String] = []
        var current = ""
        var inString = false
        var stringDelim: Character = "'"
        var i = inner.startIndex
        while i < inner.endIndex {
            let c = inner[i]
            if inString {
                if c == "\\" {
                    current.append(c)
                    i = inner.index(after: i)
                    if i < inner.endIndex {
                        current.append(inner[i])
                    }
                    i = inner.index(after: i)
                    continue
                }
                if c == stringDelim {
                    inString = false
                    i = inner.index(after: i)
                    continue
                }
                current.append(c)
            } else {
                if c == "'" || c == "\"" {
                    inString = true
                    stringDelim = c
                    current = ""
                } else if c == "," {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { results.append(trimmed) }
                    current = ""
                } else {
                    current.append(c)
                }
            }
            i = inner.index(after: i)
        }
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { results.append(trimmed) }
        return results
    }

    // MARK: - Rendering

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
            lines.append("        id: \"\(escapeTS(post.id))\",")
            lines.append("        title: \"\(escapeTS(post.title))\",")
            lines.append("        excerpt: \"\(escapeTS(post.excerpt))\",")
            lines.append("        body: `\(escapeBacktick(post.body))`,")
            lines.append("        date: \"\(escapeTS(post.date))\",")
            lines.append("        tag: \"\(escapeTS(post.tag))\",")
            lines.append("        color: \"\(escapeTS(post.color))\",")
            lines.append("        readTime: \"\(escapeTS(post.readTime))\",")
            lines.append("        cover: \"\(escapeTS(post.cover))\",")
            lines.append("        sections: [")
            for section in post.sections {
                lines.append("            {")
                lines.append("                heading: \"\(escapeTS(section.heading))\",")
                lines.append("                paragraphs: [")
                for para in section.paragraphs {
                    lines.append("                    \"\(escapeTS(para))\",")
                }
                lines.append("                ],")
                lines.append("            },")
            }
            lines.append("        ],")
            lines.append("        takeaways: [\(post.takeaways.map { "\"\(escapeTS($0))\"" }.joined(separator: ", "))],")
            lines.append(index < posts.count - 1 ? "    }," : "    }")
        }

        lines.append("];")
        lines.append("")
        lines.append("export const getPostById = (id: string) => posts.find((p) => p.id === id);")
        return lines.joined(separator: "\n")
    }

    private func escapeTS(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }

    private func escapeBacktick(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
    }
}
