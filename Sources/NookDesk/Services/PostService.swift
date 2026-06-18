import Foundation
import CoreFoundation

final class PostService {
    private let processRunner = ProcessRunner()

    func loadPosts(for project: BlogProject) throws -> [BlogPost] {
        let contentURL = project.contentURL
        try FileManager.default.createDirectory(at: contentURL, withIntermediateDirectories: true)

        let enumerator = FileManager.default.enumerator(
            at: contentURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var files: [URL] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(fileURL)
            }
        }

        let posts = try files.map(loadPost)
        return posts.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.displayFileName.localizedStandardCompare(rhs.displayFileName) == .orderedAscending
            }
            return lhs.date > rhs.date
        }
    }

    func loadPost(at fileURL: URL) throws -> BlogPost {
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let split = splitFrontMatter(from: raw)

        var post = BlogPost.empty(in: fileURL.deletingLastPathComponent())
        post.fileURL = fileURL
        post.body = split.body
        post.frontMatterFormat = split.format
        post.rawFrontMatter = split.frontMatter

        applyFrontMatter(split.frontMatter, format: split.format, to: &post)
        return post
    }

    func suggestFileName(from title: String) -> String {
        "\(StringHelpers.slugify(title.isEmpty ? "new-post" : title)).md"
    }

    func suggestTitle(fromFileName fileName: String) -> String {
        let base = fileName
            .replacingOccurrences(of: ".md", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty {
            return "未命名文章"
        }
        return base
    }

    func suggestSummary(fromMarkdown markdown: String, maxLength: Int = 140) -> String {
        if let explicit = explicitSummaryMarkerSummary(from: markdown), !explicit.isEmpty {
            return explicit
        }

        let noCode = markdown.replacingOccurrences(
            of: #"```[\s\S]*?```"#,
            with: " ",
            options: .regularExpression
        )
        let noImages = noCode.replacingOccurrences(
            of: #"\!\[[^\]]*\]\([^)]+\)"#,
            with: " ",
            options: .regularExpression
        )
        let noLinks = noImages.replacingOccurrences(
            of: #"\[([^\]]+)\]\([^)]+\)"#,
            with: "$1",
            options: .regularExpression
        )
        let stripped = noLinks
            .replacingOccurrences(of: #"(^|\n)\s{0,3}#{1,6}\s*"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"[>*_`~]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\n{2,}"#, with: "\n\n", options: .regularExpression)

        let paragraphs = stripped
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let source = paragraphs.first ?? stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty {
            return ""
        }

        if source.count <= maxLength {
            return source
        }
        return String(source.prefix(maxLength)) + "..."
    }

    func summaryMode(for post: BlogPost) -> SummaryHandlingMode {
        if post.body.contains("<!--more-->") {
            return .manualDivider
        }
        if !post.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .frontMatter
        }
        return .auto
    }

    func ensureSummaryDivider(in body: String) -> String {
        if body.contains("<!--more-->") {
            return body
        }
        if body.isEmpty {
            return "<!--more-->\n"
        }
        if body.hasSuffix("\n") {
            return body + "<!--more-->\n"
        }
        return body + "\n\n<!--more-->\n"
    }

    func createNewPost(
        title: String,
        fileName: String?,
        in project: BlogProject,
        sectionPath: String,
        frontMatterFormat: FrontMatterFormat
    ) -> BlogPost {
        let desiredStem = sanitizeFileStem(fileName ?? "", fallbackTitle: title)
        let targetDir = project.contentURL(forSectionPath: sectionPath)
        var attempt = 1
        var candidate = targetDir.appendingPathComponent("\(desiredStem).md")
        while FileManager.default.fileExists(atPath: candidate.path) {
            attempt += 1
            candidate = targetDir.appendingPathComponent("\(desiredStem)-\(attempt).md")
        }

        var post = BlogPost.empty(in: targetDir, backend: project.backend)
        post.fileURL = candidate
        post.title = title
        post.date = Date()
        post.draft = true
        post.frontMatterFormat = frontMatterFormat
        post.rawFrontMatter = renderFrontMatter(for: post)
        return post
    }

    func savePost(_ post: BlogPost, preferRawFrontMatter: Bool = false) throws {
        try FileManager.default.createDirectory(at: post.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let raw = renderPost(post, preferRawFrontMatter: preferRawFrontMatter)
        try raw.write(to: post.fileURL, atomically: true, encoding: .utf8)
    }

    func deletePost(at fileURL: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: fileURL.path) {
            try fm.removeItem(at: fileURL)
        }
    }

    func applyRawFrontMatter(_ rawFrontMatter: String, format: FrontMatterFormat, to post: inout BlogPost) {
        post.frontMatterFormat = format
        post.rawFrontMatter = rawFrontMatter
        resetStructuredFields(on: &post)
        applyFrontMatter(rawFrontMatter, format: format, to: &post)
    }

    func renderFrontMatter(for post: BlogPost) -> String {
        switch post.frontMatterFormat {
        case .toml:
            return renderTOMLFrontMatter(for: post)
        case .yaml:
            return renderYAMLFrontMatter(for: post)
        case .json:
            return renderJSONFrontMatter(for: post)
        case .astro:
            return renderAstroYAMLFrontMatter(for: post)
        }
    }

    private func renderPost(_ post: BlogPost, preferRawFrontMatter: Bool) -> String {
        let frontMatter = preferRawFrontMatter
            ? post.rawFrontMatter.trimmingCharacters(in: .whitespacesAndNewlines)
            : renderFrontMatter(for: post)

        switch post.frontMatterFormat {
        case .toml:
            return renderDelimitedPost(frontMatter: frontMatter, delimiter: "+++", body: post.body)
        case .yaml, .astro:
            return renderDelimitedPost(frontMatter: frontMatter, delimiter: "---", body: post.body)
        case .json:
            let trimmed = frontMatter.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = post.body.hasPrefix("\n") ? String(post.body.dropFirst()) : post.body
            return trimmed + "\n\n" + body + (body.hasSuffix("\n") ? "" : "\n")
        }
    }

    private func renderDelimitedPost(frontMatter: String, delimiter: String, body: String) -> String {
        var lines: [String] = []
        lines.append(delimiter)
        if !frontMatter.isEmpty {
            lines.append(frontMatter)
        }
        lines.append(delimiter)
        lines.append("")
        lines.append(body)
        if !body.hasSuffix("\n") {
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func splitFrontMatter(from raw: String) -> (format: FrontMatterFormat, frontMatter: String, body: String) {
        if let value = splitDelimitedFrontMatter(from: raw, delimiter: "+++", format: .toml) {
            return value
        }
        if let value = splitDelimitedFrontMatter(from: raw, delimiter: "---", format: .yaml) {
            return value
        }
        if let value = splitJSONFrontMatter(from: raw) {
            return value
        }
        return (.toml, "", raw)
    }

    private func splitDelimitedFrontMatter(from raw: String, delimiter: String, format: FrontMatterFormat) -> (format: FrontMatterFormat, frontMatter: String, body: String)? {
        let lines = raw.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == delimiter else {
            return nil
        }

        var endIndex: Int?
        for idx in 1..<lines.count where lines[idx].trimmingCharacters(in: .whitespaces) == delimiter {
            endIndex = idx
            break
        }
        guard let end = endIndex else { return nil }
        let front = lines[1..<end].joined(separator: "\n")
        let body = end + 1 < lines.count ? lines[(end + 1)...].joined(separator: "\n") : ""
        return (format, front, body)
    }

    private func splitJSONFrontMatter(from raw: String) -> (format: FrontMatterFormat, frontMatter: String, body: String)? {
        let trimmed = raw.trimmingCharacters(in: .newlines)
        guard trimmed.first == "{" else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        for (offset, ch) in raw.enumerated() {
            if inString {
                if escaped {
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "\"" {
                    inString = false
                }
                continue
            }
            if ch == "\"" {
                inString = true
                continue
            }
            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    let end = raw.index(raw.startIndex, offsetBy: offset)
                    let front = String(raw[raw.startIndex...end])
                    let bodyStart = raw.index(after: end)
                    let body = bodyStart < raw.endIndex ? String(raw[bodyStart...]).trimmingCharacters(in: .newlines) : ""
                    return (.json, front, body)
                }
            }
        }
        return nil
    }

    private func applyFrontMatter(_ frontMatter: String, format: FrontMatterFormat, to post: inout BlogPost) {
        switch format {
        case .toml:
            let entries = parseTOMLFrontMatter(frontMatter)
            assign(entries: entries, to: &post)
        case .yaml, .astro:
            let entries = parseYAMLFrontMatter(frontMatter)
            assign(entries: entries, to: &post)
        case .json:
            let entries = parseJSONFrontMatter(frontMatter)
            assign(entries: entries, to: &post)
        }
    }

    private func assign(entries: [String: Any], to post: inout BlogPost) {
        if let title = stringValue(entries["title"]) { post.title = title }
        // Support both Hugo (date) and Astro (pubDate) field names
        if let dateText = stringValue(entries["date"] ?? entries["pubDate"]), let date = parseDate(dateText) { post.date = date }
        if let draft = boolValue(entries["draft"]) { post.draft = draft }
        // Support both Hugo (summary) and Astro (description) field names
        if let summary = stringValue(entries["summary"] ?? entries["description"]) { post.summary = summary }
        if let tags = stringArrayValue(entries["tags"]) { post.tags = tags }
        // Support both Hugo (categories array) and Astro (category singular) field names
        if let categories = stringArrayValue(entries["categories"]) {
            post.categories = categories
        } else if let category = stringValue(entries["category"]), !category.isEmpty {
            post.categories = [category]
        }
        if let pin = boolValue(entries["pin"]) { post.pin = pin }
        if let math = boolValue(entries["math"]) { post.math = math }
        if let mathJax = boolValue(entries["MathJax"] ?? entries["mathJax"]) { post.mathJax = mathJax }
        if let value = boolValue(entries["private"]) { post.isPrivate = value }
        if let value = boolValue(entries["searchable"]) { post.searchable = value }
        if let cover = stringValue(entries["cover"]) { post.cover = cover }
        if let author = stringValue(entries["author"] ?? entries["Author"]) { post.author = author }
        if let keywords = stringArrayValue(entries["keywords"] ?? entries["Keywords"]) { post.keywords = keywords }
        if let slug = stringValue(entries["slug"]) { post.slug = slug }
        if let url = stringValue(entries["url"]) { post.urlPath = url }
        if let aliases = stringArrayValue(entries["aliases"]) { post.aliases = aliases }
        if let translationKey = stringValue(entries["translationKey"]) { post.translationKey = translationKey }
        // Astro-specific: readTime, color, heroImage
        if let readTime = stringValue(entries["readTime"]) { post.customTaxonomies["readTime"] = [readTime] }
        if let color = stringValue(entries["color"]) { post.customTaxonomies["color"] = [color] }
        if let heroImage = stringValue(entries["heroImage"]) { post.customTaxonomies["heroImage"] = [heroImage] }
    }

    private func resetStructuredFields(on post: inout BlogPost) {
        post.title = ""
        post.date = Date()
        post.draft = true
        post.summary = ""
        post.tags = []
        post.categories = []
        post.pin = false
        post.math = false
        post.mathJax = false
        post.isPrivate = false
        post.searchable = true
        post.cover = ""
        post.author = ""
        post.keywords = []
        post.customTaxonomies = [:]
        post.taxonomyWeights = [:]
        post.slug = ""
        post.urlPath = ""
        post.aliases = []
        post.translationKey = ""
    }

    // [NookDesk 修复] 支持 TOML 嵌套表语法 [key.sub]，
    // 将子表中的键存储为 "sub.key" 形式的扁平 key，
    // 使得 front matter 解析能正确处理 Hugo 的多级表结构。
    private func parseTOMLFrontMatter(_ raw: String) -> [String: Any] {
        var entries: [String: Any] = [:]
        var currentSection = ""
        var currentSubSection = ""
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            // 匹配 [[array.of.tables]]（TOML 数组表，跳过内部处理）
            if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
                currentSection = ""
                currentSubSection = ""
                continue
            }
            // 匹配 [section] 或 [section.subsection]
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let sectionName = String(trimmed.dropFirst().dropLast())
                if let dotIndex = sectionName.firstIndex(of: ".") {
                    // [key.sub] 形式：记录父节和子节
                    currentSection = String(sectionName[..<dotIndex])
                    currentSubSection = String(sectionName[sectionName.index(after: dotIndex)...])
                } else {
                    currentSection = sectionName
                    currentSubSection = ""
                }
                continue
            }
            guard let idx = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            let parsed = parseScalarOrArray(value)
            // 如果在子节 [section.sub] 下，用 "sub.key" 作为存储键
            if !currentSection.isEmpty && !currentSubSection.isEmpty {
                entries["\(currentSubSection).\(key)"] = parsed
            } else if !currentSection.isEmpty {
                entries["\(currentSection).\(key)"] = parsed
            } else {
                entries[key] = parsed
            }
        }
        return entries
    }

    private func parseYAMLFrontMatter(_ raw: String) -> [String: Any] {
        var entries: [String: Any] = [:]
        var activeArrayKey: String?
        for line in raw.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if let key = activeArrayKey, trimmed.hasPrefix("- ") {
                var current = entries[key] as? [String] ?? []
                current.append(StringHelpers.parseString(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                entries[key] = current
                continue
            }
            activeArrayKey = nil
            guard let idx = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
            if value.isEmpty {
                activeArrayKey = key
                entries[key] = [String]()
            } else {
                entries[key] = parseScalarOrArray(value)
            }
        }
        return entries
    }

    private func parseJSONFrontMatter(_ raw: String) -> [String: Any] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json
    }

    private func parseScalarOrArray(_ raw: String) -> Any {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            return StringHelpers.parseArray(trimmed)
        }
        if trimmed.lowercased() == "true" || trimmed.lowercased() == "false" {
            return StringHelpers.parseBool(trimmed)
        }
        return StringHelpers.parseString(trimmed)
    }

    private func renderTOMLFrontMatter(for post: BlogPost) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var lines: [String] = []
        lines.append("title = \(StringHelpers.encodeString(post.title))")
        lines.append("date = \(StringHelpers.encodeString(formatter.string(from: post.date)))")
        lines.append("draft = \(post.draft ? "true" : "false")")
        appendOptionalString(post.summary, key: "summary", to: &lines)
        appendOptionalArray(post.tags, key: "tags", to: &lines)
        appendOptionalArray(post.categories, key: "categories", to: &lines)
        appendOptionalBool(post.pin, key: "pin", to: &lines)
        appendOptionalBool(post.math, key: "math", to: &lines)
        appendOptionalBool(post.mathJax, key: "MathJax", to: &lines)
        appendOptionalBool(post.isPrivate, key: "private", to: &lines)
        if !post.searchable { lines.append("searchable = false") }
        appendOptionalString(post.cover, key: "cover", to: &lines)
        appendOptionalString(post.author, key: "author", to: &lines)
        appendOptionalArray(post.keywords, key: "keywords", to: &lines)
        for key in post.customTaxonomies.keys.sorted() {
            appendOptionalArray(post.customTaxonomies[key] ?? [], key: key, to: &lines)
        }
        appendOptionalString(post.slug, key: "slug", to: &lines)
        appendOptionalString(post.urlPath, key: "url", to: &lines)
        appendOptionalArray(post.aliases, key: "aliases", to: &lines)
        appendOptionalString(post.translationKey, key: "translationKey", to: &lines)
        return lines.joined(separator: "\n")
    }

    private func renderYAMLFrontMatter(for post: BlogPost) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var lines: [String] = []
        lines.append("title: \(StringHelpers.encodeYAML(post.title))")
        lines.append("date: \(StringHelpers.encodeYAML(formatter.string(from: post.date)))")
        lines.append("draft: \(post.draft ? "true" : "false")")
        appendOptionalYAMLString(post.summary, key: "summary", to: &lines)
        appendOptionalYAMLArray(post.tags, key: "tags", to: &lines)
        appendOptionalYAMLArray(post.categories, key: "categories", to: &lines)
        appendOptionalYAMLString(post.cover, key: "cover", to: &lines)
        appendOptionalYAMLString(post.slug, key: "slug", to: &lines)
        return lines.joined(separator: "\n")
    }

    func renderAstroYAMLFrontMatter(for post: BlogPost) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        var lines: [String] = []
        let title = post.title.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("title: \(StringHelpers.encodeYAML(title.isEmpty ? "未命名文章" : title))")
        let desc = post.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append("description: \(StringHelpers.encodeYAML(desc.isEmpty ? (title.isEmpty ? "待补充描述" : title) : desc))")
        lines.append("pubDate: \(formatter.string(from: post.date))")
        let category = post.categories.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        lines.append("category: \(StringHelpers.encodeYAML(category.isEmpty ? "未分类" : category))")
        if !post.tags.isEmpty {
            lines.append("tags: [\(post.tags.map { StringHelpers.encodeYAML($0) }.joined(separator: ", "))]")
        } else {
            lines.append("tags: []")
        }
        if let cover = post.customTaxonomies["cover"]?.first, !cover.isEmpty {
            lines.append("cover: \(StringHelpers.encodeYAML(cover))")
        } else if !post.cover.isEmpty {
            lines.append("cover: \(StringHelpers.encodeYAML(post.cover))")
        } else {
            lines.append("cover: \"📝\"")
        }
        if let color = post.customTaxonomies["color"]?.first, !color.isEmpty {
            lines.append("color: \"\(color)\"")
        } else {
            lines.append("color: \"app-blue\"")
        }
        if let readTime = post.customTaxonomies["readTime"]?.first, !readTime.isEmpty {
            lines.append("readTime: \(StringHelpers.encodeYAML(readTime))")
        } else {
            lines.append("readTime: \"5 分钟\"")
        }
        if post.draft {
            lines.append("draft: true")
        }
        if post.pin {
            lines.append("pin: true")
        }
        return lines.joined(separator: "\n")
    }

    private func renderJSONFrontMatter(for post: BlogPost) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var dict: [String: Any] = [
            "title": post.title,
            "date": formatter.string(from: post.date),
            "draft": post.draft
        ]
        if !post.summary.isEmpty { dict["summary"] = post.summary }
        if !post.tags.isEmpty { dict["tags"] = post.tags }
        if !post.categories.isEmpty { dict["categories"] = post.categories }
        if !post.cover.isEmpty { dict["cover"] = post.cover }
        if !post.slug.isEmpty { dict["slug"] = post.slug }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func appendOptionalString(_ value: String, key: String, to lines: inout [String]) {
        guard !value.isEmpty else { return }
        lines.append("\(key) = \(StringHelpers.encodeString(value))")
    }

    private func appendOptionalArray(_ value: [String], key: String, to lines: inout [String]) {
        guard !value.isEmpty else { return }
        lines.append("\(key) = \(StringHelpers.encodeArray(value))")
    }

    private func appendOptionalBool(_ value: Bool, key: String, to lines: inout [String]) {
        guard value else { return }
        lines.append("\(key) = true")
    }

    private func appendOptionalYAMLString(_ value: String, key: String, to lines: inout [String]) {
        guard !value.isEmpty else { return }
        lines.append("\(key): \(StringHelpers.encodeYAML(value))")
    }

    private func appendOptionalYAMLArray(_ value: [String], key: String, to lines: inout [String]) {
        guard !value.isEmpty else { return }
        lines.append("\(key):")
        for item in value {
            lines.append("  - \(StringHelpers.encodeYAML(item))")
        }
    }

    private func explicitSummaryMarkerSummary(from markdown: String) -> String? {
        let parts = markdown.components(separatedBy: "<!--more-->")
        guard parts.count > 1 else { return nil }
        return parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ raw: String) -> Date? {
        let text = StringHelpers.parseString(raw)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = iso.date(from: text) {
            return value
        }
        let iso2 = ISO8601DateFormatter()
        iso2.formatOptions = [.withInternetDateTime]
        return iso2.date(from: text)
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool? {
        if let bool = value as? Bool { return bool }
        if let string = value as? String { return StringHelpers.parseBool(string) }
        return nil
    }

    private func stringArrayValue(_ value: Any?) -> [String]? {
        if let array = value as? [String] { return array }
        if let array = value as? [Any] { return array.compactMap { $0 as? String } }
        if let string = value as? String {
            let parsed = StringHelpers.parseArray(string)
            return parsed.isEmpty ? nil : parsed
        }
        return nil
    }

    // parseString, parseBool, parseArray, encodeString, encodeArray, encodeYAML
    // are now provided by StringHelpers.

    private func sanitizeFileStem(_ raw: String, fallbackTitle: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let noExt = trimmed.hasSuffix(".md") ? String(trimmed.dropLast(3)) : trimmed
        let base = noExt.isEmpty ? StringHelpers.slugify(fallbackTitle.isEmpty ? "new-post" : fallbackTitle) : StringHelpers.slugify(noExt)
        return base.isEmpty ? "post-\(Int(Date().timeIntervalSince1970))" : base
    }
}
