import Foundation

final class ConfigService {
    func loadConfig(for project: BlogProject) throws -> ThemeConfig {
        let fileURL = project.configURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ThemeConfig()
        }

        let ext = fileURL.pathExtension.lowercased()
        if ext == "ts" || ext == "js" || ext == "mts" || ext == "mjs" {
            // [NookDesk 修复] 对 .ts/.js/.mjs 配置文件（如 Astro），不再返回空配置，
            // 而是尝试用正则解析 astro.config.mjs 中的 site 和 base 字段，
            // 返回一个带基本配置的 ThemeConfig，避免 UI 显示空白。
            return parseAstroConfig(from: fileURL)
        }

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var config = ThemeConfig()
        var section = ""
        var linkIndex: Int?
        var currentLanguageCode: String?

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
                let name = String(trimmed.dropFirst(2).dropLast(2))
                section = name
                currentLanguageCode = nil
                if name == "params.links" {
                    config.params.links.append(ThemeLink())
                    linkIndex = config.params.links.count - 1
                }
                continue
            }

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                section = String(trimmed.dropFirst().dropLast())
                linkIndex = nil
                currentLanguageCode = nil
                if section.hasPrefix("languages.") {
                    currentLanguageCode = String(section.dropFirst("languages.".count))
                    if !currentLanguageCode!.isEmpty,
                       !config.languageProfiles.contains(where: { $0.code == currentLanguageCode! }) {
                        config.languageProfiles.append(
                            LanguageProfile(
                                code: currentLanguageCode!,
                                title: currentLanguageCode!,
                                contentDir: project.contentSubpath,
                                weight: config.languageProfiles.count
                            )
                        )
                    }
                }
                continue
            }

            guard let (key, valueRaw) = splitKeyValue(trimmed) else {
                continue
            }

            let value = stripInlineComment(valueRaw).trimmingCharacters(in: .whitespaces)

            switch section {
            case "":
                switch key {
                case "baseURL": config.baseURL = StringHelpers.parseString(value)
                case "languageCode": config.languageCode = StringHelpers.parseString(value)
                case "title": config.title = StringHelpers.parseString(value)
                case "theme": config.theme = StringHelpers.parseString(value)
                case "sectionPagesMenu": config.sectionPagesMenu = StringHelpers.parseString(value)
                case "pygmentsCodeFences": config.pygmentsCodeFences = StringHelpers.parseBool(value)
                case "pygmentsUseClasses": config.pygmentsUseClasses = StringHelpers.parseBool(value)
                default: break
                }

            case "params":
                applyParam(key: key, value: value, to: &config)

            case "params.gitalk":
                applyGitalkParam(key: key, value: value, to: &config)

            case "params.links":
                if let idx = linkIndex {
                    switch key {
                    case "title": config.params.links[idx].title = StringHelpers.parseString(value)
                    case "href": config.params.links[idx].href = StringHelpers.parseString(value)
                    case "icon": config.params.links[idx].icon = StringHelpers.parseString(value)
                    default: break
                    }
                }

            case "frontmatter":
                if key == "lastmod" {
                    let normalized = value.replacingOccurrences(of: " ", with: "").lowercased()
                    config.frontmatterTrackLastmod = normalized.contains(":filemodtime")
                }

            case "services.googleAnalytics":
                if key == "ID" {
                    config.googleAnalyticsID = StringHelpers.parseString(value)
                }

            case "outputs":
                if key == "home" {
                    config.outputsHome = StringHelpers.parseArray(value)
                }

            case "outputFormats.json":
                switch key {
                case "mediaType": config.outputFormatJSONMediaType = StringHelpers.parseString(value)
                case "baseName": config.outputFormatJSONBaseName = StringHelpers.parseString(value)
                case "isPlainText": config.outputFormatJSONIsPlainText = StringHelpers.parseBool(value)
                default: break
                }

            case "taxonomies":
                config.taxonomies[key] = StringHelpers.parseString(value)

            default:
                if let currentLanguageCode, section == "languages.\(currentLanguageCode)" {
                    if let idx = config.languageProfiles.firstIndex(where: { $0.code == currentLanguageCode }) {
                        switch key {
                        case "contentDir":
                            config.languageProfiles[idx].contentDir = StringHelpers.parseString(value)
                        case "languageName", "title":
                            config.languageProfiles[idx].title = StringHelpers.parseString(value)
                        case "weight":
                            config.languageProfiles[idx].weight = Int(StringHelpers.parseString(value)) ?? config.languageProfiles[idx].weight
                        default:
                            break
                        }
                    }
                }
                break
            }
        }

        config.languageProfiles.sort { lhs, rhs in
            if lhs.weight == rhs.weight {
                return lhs.code < rhs.code
            }
            return lhs.weight < rhs.weight
        }
        return config
    }

    func saveConfig(_ config: ThemeConfig, for project: BlogProject) throws {
        let fileURL = project.configURL
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            let output = buildManagedConfigLines(config).joined(separator: "\n") + "\n"
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
            return
        }

        let existing = try String(contentsOf: fileURL, encoding: .utf8)
        var editor = ConfigLineEditor(raw: existing)
        applyManagedConfig(config, to: &editor)
        let output = editor.rendered()
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func applyManagedConfig(_ config: ThemeConfig, to editor: inout ConfigLineEditor) {
        editor.set(
            key: "baseURL",
            value: StringHelpers.encodeString(config.baseURL),
            section: nil
        )
        editor.set(
            key: "languageCode",
            value: StringHelpers.encodeString(config.languageCode),
            section: nil
        )
        editor.set(
            key: "title",
            value: StringHelpers.encodeString(config.title),
            section: nil
        )
        editor.set(
            key: "theme",
            value: StringHelpers.encodeString(config.theme),
            section: nil
        )
        editor.set(
            key: "sectionPagesMenu",
            value: StringHelpers.encodeString(config.sectionPagesMenu),
            section: nil
        )
        editor.set(
            key: "pygmentsCodeFences",
            value: config.pygmentsCodeFences ? "true" : "false",
            section: nil
        )
        editor.set(
            key: "pygmentsUseClasses",
            value: config.pygmentsUseClasses ? "true" : "false",
            section: nil
        )

        editor.set(key: "author", value: StringHelpers.encodeString(config.params.author), section: "params")
        editor.set(key: "description", value: StringHelpers.encodeString(config.params.description), section: "params", aliases: ["Description"])
        editor.set(key: "tagline", value: StringHelpers.encodeString(config.params.tagline), section: "params")
        editor.set(key: "github", value: StringHelpers.encodeString(config.params.github), section: "params")
        editor.set(key: "twitter", value: StringHelpers.encodeString(config.params.twitter), section: "params")
        editor.set(key: "facebook", value: StringHelpers.encodeString(config.params.facebook), section: "params")
        editor.set(key: "linkedin", value: StringHelpers.encodeString(config.params.linkedin), section: "params")
        editor.set(key: "instagram", value: StringHelpers.encodeString(config.params.instagram), section: "params")
        editor.set(key: "tumblr", value: StringHelpers.encodeString(config.params.tumblr), section: "params")
        editor.set(key: "stackoverflow", value: StringHelpers.encodeString(config.params.stackoverflow), section: "params")
        editor.set(key: "bluesky", value: StringHelpers.encodeString(config.params.bluesky), section: "params")
        editor.set(key: "email", value: StringHelpers.encodeString(config.params.email), section: "params", aliases: ["Email"])
        editor.set(key: "url", value: StringHelpers.encodeString(config.params.url), section: "params")
        editor.set(key: "keywords", value: StringHelpers.encodeString(config.params.keywords), section: "params", aliases: ["Keywords"])
        editor.set(key: "favicon", value: StringHelpers.encodeString(config.params.favicon), section: "params")
        editor.set(key: "avatar", value: StringHelpers.encodeString(config.params.avatar), section: "params")
        editor.set(key: "headerIcon", value: StringHelpers.encodeString(config.params.headerIcon), section: "params")
        editor.set(key: "location", value: StringHelpers.encodeString(config.params.location), section: "params")
        editor.set(key: "userStatusEmoji", value: StringHelpers.encodeString(config.params.userStatusEmoji), section: "params")
        editor.set(key: "rss", value: config.params.rss ? "true" : "false", section: "params")
        editor.set(key: "lastmod", value: config.params.lastmod ? "true" : "false", section: "params")
        editor.set(key: "enableGitalk", value: config.params.enableGitalk ? "true" : "false", section: "params")
        editor.set(key: "enableSearch", value: config.params.enableSearch ? "true" : "false", section: "params")
        editor.set(key: "math", value: config.params.math ? "true" : "false", section: "params")
        editor.set(key: "MathJax", value: config.params.mathJax ? "true" : "false", section: "params", aliases: ["mathJax"])
        editor.set(key: "custom_css", value: StringHelpers.encodeArray(config.params.customCSS), section: "params")
        editor.set(key: "custom_js", value: StringHelpers.encodeArray(config.params.customJS), section: "params")

        editor.set(key: "clientID", value: StringHelpers.encodeString(config.params.gitalk.clientID), section: "params.gitalk")
        editor.set(key: "clientSecret", value: StringHelpers.encodeString(config.params.gitalk.clientSecret), section: "params.gitalk")
        editor.set(key: "repo", value: StringHelpers.encodeString(config.params.gitalk.repo), section: "params.gitalk")
        editor.set(key: "owner", value: StringHelpers.encodeString(config.params.gitalk.owner), section: "params.gitalk")
        editor.set(key: "admin", value: StringHelpers.encodeString(config.params.gitalk.admin), section: "params.gitalk")
        editor.set(key: "id", value: StringHelpers.encodeString(config.params.gitalk.id), section: "params.gitalk")
        editor.set(key: "labels", value: StringHelpers.encodeString(config.params.gitalk.labels), section: "params.gitalk")
        editor.set(key: "perPage", value: String(config.params.gitalk.perPage), section: "params.gitalk")
        editor.set(key: "pagerDirection", value: StringHelpers.encodeString(config.params.gitalk.pagerDirection), section: "params.gitalk")
        editor.set(key: "createIssueManually", value: config.params.gitalk.createIssueManually ? "true" : "false", section: "params.gitalk")
        editor.set(key: "distractionFreeMode", value: config.params.gitalk.distractionFreeMode ? "true" : "false", section: "params.gitalk")
        editor.set(key: "proxy", value: StringHelpers.encodeString(config.params.gitalk.proxy), section: "params.gitalk")

        let linkBlocks = config.params.links.map { link in
            var rows: [String] = []
            rows.append("title = \(StringHelpers.encodeString(link.title))")
            rows.append("href = \(StringHelpers.encodeString(link.href))")
            if !link.icon.isEmpty {
                rows.append("icon = \(StringHelpers.encodeString(link.icon))")
            }
            return rows
        }
        editor.replaceArrayTable(name: "params.links", blocks: linkBlocks, preferredAnchorSection: "params.gitalk")

        editor.set(
            key: "lastmod",
            value: config.frontmatterTrackLastmod
                ? "[\"lastmod\", \":fileModTime\", \":default\"]"
                : "[\":default\"]",
            section: "frontmatter"
        )

        editor.set(key: "ID", value: StringHelpers.encodeString(config.googleAnalyticsID), section: "services.googleAnalytics")
        editor.set(key: "home", value: StringHelpers.encodeArray(config.outputsHome), section: "outputs")
        editor.set(key: "mediaType", value: StringHelpers.encodeString(config.outputFormatJSONMediaType), section: "outputFormats.json")
        editor.set(key: "baseName", value: StringHelpers.encodeString(config.outputFormatJSONBaseName), section: "outputFormats.json")
        editor.set(key: "isPlainText", value: config.outputFormatJSONIsPlainText ? "true" : "false", section: "outputFormats.json")

        let taxonomyRows = config.taxonomies
            .sorted { $0.key < $1.key }
            .map { "\($0.key) = \(StringHelpers.encodeString($0.value))" }
        editor.replaceSection(name: "taxonomies", rows: taxonomyRows, preferredAnchorSection: "outputFormats.json")

        let languageSections = config.languageProfiles
            .filter { !$0.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted {
                if $0.weight == $1.weight {
                    return $0.code < $1.code
                }
                return $0.weight < $1.weight
            }
            .map { profile -> (String, [String]) in
                var rows: [String] = []
                let contentDir = profile.contentDir.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = profile.title.trimmingCharacters(in: .whitespacesAndNewlines)
                if !contentDir.isEmpty {
                    rows.append("contentDir = \(StringHelpers.encodeString(contentDir))")
                }
                if !title.isEmpty {
                    rows.append("languageName = \(StringHelpers.encodeString(title))")
                }
                rows.append("weight = \(profile.weight)")
                return ("languages.\(profile.code)", rows)
            }
        editor.replaceSections(prefix: "languages.", sections: languageSections, preferredAnchorSection: "taxonomies")
    }

    private func buildManagedConfigLines(_ config: ThemeConfig) -> [String] {
        var lines: [String] = []

        lines.append("baseURL = \(StringHelpers.encodeString(config.baseURL))")
        lines.append("languageCode = \(StringHelpers.encodeString(config.languageCode))")
        lines.append("title = \(StringHelpers.encodeString(config.title))")
        lines.append("theme = \(StringHelpers.encodeString(config.theme))")
        lines.append("sectionPagesMenu = \(StringHelpers.encodeString(config.sectionPagesMenu))")
        lines.append("pygmentsCodeFences = \(config.pygmentsCodeFences ? "true" : "false")")
        lines.append("pygmentsUseClasses = \(config.pygmentsUseClasses ? "true" : "false")")
        lines.append("")

        lines.append("[params]")
        lines.append("  author = \(StringHelpers.encodeString(config.params.author))")
        lines.append("  description = \(StringHelpers.encodeString(config.params.description))")
        lines.append("  tagline = \(StringHelpers.encodeString(config.params.tagline))")
        lines.append("  github = \(StringHelpers.encodeString(config.params.github))")
        lines.append("  twitter = \(StringHelpers.encodeString(config.params.twitter))")
        lines.append("  facebook = \(StringHelpers.encodeString(config.params.facebook))")
        lines.append("  linkedin = \(StringHelpers.encodeString(config.params.linkedin))")
        lines.append("  instagram = \(StringHelpers.encodeString(config.params.instagram))")
        lines.append("  tumblr = \(StringHelpers.encodeString(config.params.tumblr))")
        lines.append("  stackoverflow = \(StringHelpers.encodeString(config.params.stackoverflow))")
        lines.append("  bluesky = \(StringHelpers.encodeString(config.params.bluesky))")
        lines.append("  email = \(StringHelpers.encodeString(config.params.email))")
        lines.append("  url = \(StringHelpers.encodeString(config.params.url))")
        lines.append("  keywords = \(StringHelpers.encodeString(config.params.keywords))")
        lines.append("  favicon = \(StringHelpers.encodeString(config.params.favicon))")
        lines.append("  avatar = \(StringHelpers.encodeString(config.params.avatar))")
        lines.append("  headerIcon = \(StringHelpers.encodeString(config.params.headerIcon))")
        lines.append("  location = \(StringHelpers.encodeString(config.params.location))")
        lines.append("  userStatusEmoji = \(StringHelpers.encodeString(config.params.userStatusEmoji))")
        lines.append("  rss = \(config.params.rss ? "true" : "false")")
        lines.append("  lastmod = \(config.params.lastmod ? "true" : "false")")
        lines.append("  enableGitalk = \(config.params.enableGitalk ? "true" : "false")")
        lines.append("  enableSearch = \(config.params.enableSearch ? "true" : "false")")
        lines.append("  math = \(config.params.math ? "true" : "false")")
        lines.append("  MathJax = \(config.params.mathJax ? "true" : "false")")
        lines.append("  custom_css = \(StringHelpers.encodeArray(config.params.customCSS))")
        lines.append("  custom_js = \(StringHelpers.encodeArray(config.params.customJS))")
        lines.append("")

        lines.append("  [params.gitalk]")
        lines.append("    clientID = \(StringHelpers.encodeString(config.params.gitalk.clientID))")
        lines.append("    clientSecret = \(StringHelpers.encodeString(config.params.gitalk.clientSecret))")
        lines.append("    repo = \(StringHelpers.encodeString(config.params.gitalk.repo))")
        lines.append("    owner = \(StringHelpers.encodeString(config.params.gitalk.owner))")
        lines.append("    admin = \(StringHelpers.encodeString(config.params.gitalk.admin))")
        lines.append("    id = \(StringHelpers.encodeString(config.params.gitalk.id))")
        lines.append("    labels = \(StringHelpers.encodeString(config.params.gitalk.labels))")
        lines.append("    perPage = \(config.params.gitalk.perPage)")
        lines.append("    pagerDirection = \(StringHelpers.encodeString(config.params.gitalk.pagerDirection))")
        lines.append("    createIssueManually = \(config.params.gitalk.createIssueManually ? "true" : "false")")
        lines.append("    distractionFreeMode = \(config.params.gitalk.distractionFreeMode ? "true" : "false")")
        lines.append("    proxy = \(StringHelpers.encodeString(config.params.gitalk.proxy))")

        if !config.params.links.isEmpty {
            lines.append("")
            for link in config.params.links {
                lines.append("  [[params.links]]")
                lines.append("    title = \(StringHelpers.encodeString(link.title))")
                lines.append("    href = \(StringHelpers.encodeString(link.href))")
                if !link.icon.isEmpty {
                    lines.append("    icon = \(StringHelpers.encodeString(link.icon))")
                }
            }
        }

        lines.append("")
        lines.append("[frontmatter]")
        if config.frontmatterTrackLastmod {
            lines.append("  lastmod = [\"lastmod\", \":fileModTime\", \":default\"]")
        } else {
            lines.append("  lastmod = [\":default\"]")
        }

        lines.append("")
        lines.append("[services]")
        lines.append("  [services.googleAnalytics]")
        lines.append("    ID = \(StringHelpers.encodeString(config.googleAnalyticsID))")

        lines.append("")
        lines.append("[outputs]")
        lines.append("  home = \(StringHelpers.encodeArray(config.outputsHome))")

        lines.append("")
        lines.append("[outputFormats.json]")
        lines.append("  mediaType = \(StringHelpers.encodeString(config.outputFormatJSONMediaType))")
        lines.append("  baseName = \(StringHelpers.encodeString(config.outputFormatJSONBaseName))")
        lines.append("  isPlainText = \(config.outputFormatJSONIsPlainText ? "true" : "false")")

        if !config.taxonomies.isEmpty {
            lines.append("")
            lines.append("[taxonomies]")
            for entry in config.taxonomies.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(entry.key) = \(StringHelpers.encodeString(entry.value))")
            }
        }

        if !config.languageProfiles.isEmpty {
            for profile in config.languageProfiles.sorted(by: {
                if $0.weight == $1.weight {
                    return $0.code < $1.code
                }
                return $0.weight < $1.weight
            }) {
                let code = profile.code.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !code.isEmpty else { continue }
                lines.append("")
                lines.append("[languages.\(code)]")
                if !profile.contentDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append("  contentDir = \(StringHelpers.encodeString(profile.contentDir))")
                }
                if !profile.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    lines.append("  languageName = \(StringHelpers.encodeString(profile.title))")
                }
                lines.append("  weight = \(profile.weight)")
            }
        }
        return lines
    }

    private func applyParam(key: String, value: String, to config: inout ThemeConfig) {
        switch key {
        case "author": config.params.author = StringHelpers.parseString(value)
        case "description", "Description": config.params.description = StringHelpers.parseString(value)
        case "tagline": config.params.tagline = StringHelpers.parseString(value)
        case "github": config.params.github = StringHelpers.parseString(value)
        case "twitter": config.params.twitter = StringHelpers.parseString(value)
        case "facebook": config.params.facebook = StringHelpers.parseString(value)
        case "linkedin": config.params.linkedin = StringHelpers.parseString(value)
        case "instagram": config.params.instagram = StringHelpers.parseString(value)
        case "tumblr": config.params.tumblr = StringHelpers.parseString(value)
        case "stackoverflow": config.params.stackoverflow = StringHelpers.parseString(value)
        case "bluesky": config.params.bluesky = StringHelpers.parseString(value)
        case "email", "Email": config.params.email = StringHelpers.parseString(value)
        case "url": config.params.url = StringHelpers.parseString(value)
        case "keywords", "Keywords": config.params.keywords = StringHelpers.parseString(value)
        case "favicon": config.params.favicon = StringHelpers.parseString(value)
        case "avatar": config.params.avatar = StringHelpers.parseString(value)
        case "headerIcon": config.params.headerIcon = StringHelpers.parseString(value)
        case "location": config.params.location = StringHelpers.parseString(value)
        case "userStatusEmoji": config.params.userStatusEmoji = StringHelpers.parseString(value)
        case "rss": config.params.rss = StringHelpers.parseBool(value)
        case "lastmod": config.params.lastmod = StringHelpers.parseBool(value)
        case "enableGitalk": config.params.enableGitalk = StringHelpers.parseBool(value)
        case "enableSearch": config.params.enableSearch = StringHelpers.parseBool(value)
        case "math": config.params.math = StringHelpers.parseBool(value)
        case "MathJax", "mathJax": config.params.mathJax = StringHelpers.parseBool(value)
        case "custom_css": config.params.customCSS = StringHelpers.parseArray(value)
        case "custom_js": config.params.customJS = StringHelpers.parseArray(value)
        default: break
        }
    }

    private func applyGitalkParam(key: String, value: String, to config: inout ThemeConfig) {
        switch key {
        case "clientID": config.params.gitalk.clientID = StringHelpers.parseString(value)
        case "clientSecret": config.params.gitalk.clientSecret = StringHelpers.parseString(value)
        case "repo": config.params.gitalk.repo = StringHelpers.parseString(value)
        case "owner": config.params.gitalk.owner = StringHelpers.parseString(value)
        case "admin": config.params.gitalk.admin = StringHelpers.parseString(value)
        case "id": config.params.gitalk.id = StringHelpers.parseString(value)
        case "labels": config.params.gitalk.labels = StringHelpers.parseString(value)
        case "perPage": config.params.gitalk.perPage = Int(StringHelpers.parseString(value)) ?? 15
        case "pagerDirection": config.params.gitalk.pagerDirection = StringHelpers.parseString(value)
        case "createIssueManually": config.params.gitalk.createIssueManually = StringHelpers.parseBool(value)
        case "distractionFreeMode": config.params.gitalk.distractionFreeMode = StringHelpers.parseBool(value)
        case "proxy": config.params.gitalk.proxy = StringHelpers.parseString(value)
        default: break
        }
    }

    // MARK: - Astro 配置解析（正则提取 site 和 base）
    // [NookDesk 修复] Astro 的配置文件是 .mjs/.ts/.js，无法被 TOML 解析器读取。
    // 这里用正则从中提取 site 和 base 字段，填充到 ThemeConfig，
    // 使设置界面能显示基本站点信息。
    private func parseAstroConfig(from fileURL: URL) -> ThemeConfig {
        var config = ThemeConfig()
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return config
        }
        // 匹配 site: 'https://...' 或 site: "https://..."
        let sitePattern = #"site\s*:\s*['"]([^'"]+)['"]"#
        if let regex = try? NSRegularExpression(pattern: sitePattern),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            config.baseURL = String(content[range])
        }
        // 匹配 base: '/' 或 base: "/subpath"
        let basePattern = #"base\s*:\s*['"]([^'"]*)['"]"#
        if let regex = try? NSRegularExpression(pattern: basePattern),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            let base = String(content[range])
            if !base.isEmpty && base != "/" {
                let trimmedBase = config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let trimmedSub = base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                config.baseURL = trimmedBase + "/" + trimmedSub + "/"
            }
        }
        return config
    }

    private func splitKeyValue(_ line: String) -> (String, String)? {
        guard let idx = line.firstIndex(of: "=") else {
            return nil
        }
        let key = line[..<idx].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        return (String(key), String(value))
    }

    private func stripInlineComment(_ value: String) -> String {
        var inSingle = false
        var inDouble = false

        for (idx, ch) in value.enumerated() {
            if ch == "\"" && !inSingle {
                inDouble.toggle()
            } else if ch == "'" && !inDouble {
                inSingle.toggle()
            } else if ch == "#" && !inSingle && !inDouble {
                let cut = value.index(value.startIndex, offsetBy: idx)
                return String(value[..<cut])
            }
        }

        return value
    }

    // parseString, parseBool, parseArray, encodeString, encodeArray
    // are now provided by StringHelpers.
}

private struct ConfigLineEditor {
    private var lines: [String]

    init(raw: String) {
        var parsed = raw.components(separatedBy: .newlines)
        if parsed.last == "" {
            parsed.removeLast()
        }
        lines = parsed
    }

    mutating func set(key: String, value: String, section: String?, aliases: [String] = []) {
        let keys = Set([key] + aliases)
        if let lineIndex = findKeyLine(section: section, keys: keys) {
            let indent = leadingWhitespace(of: lines[lineIndex])
            lines[lineIndex] = "\(indent)\(key) = \(value)"
            return
        }

        if let section {
            let sectionRef = ensureSection(named: section)
            let indent = indentationForSection(sectionRef: sectionRef)
            let insertAt = insertionIndexForSection(sectionRef: sectionRef)
            lines.insert("\(indent)\(key) = \(value)", at: insertAt)
        } else {
            let insertAt = firstHeaderIndex() ?? lines.count
            lines.insert("\(key) = \(value)", at: insertAt)
        }
    }

    mutating func replaceArrayTable(name: String, blocks: [[String]], preferredAnchorSection: String?) {
        removeArrayTable(named: name)
        guard !blocks.isEmpty else {
            return
        }

        var insertAt: Int
        if let preferredAnchorSection,
           let sectionRef = sectionReference(named: preferredAnchorSection) {
            insertAt = insertionIndexForSection(sectionRef: sectionRef)
        } else if let parent = name.split(separator: ".").dropLast().first, !parent.isEmpty,
                  let sectionRef = sectionReference(named: String(parent)) {
            insertAt = insertionIndexForSection(sectionRef: sectionRef)
        } else {
            insertAt = lines.count
        }

        if insertAt > 0 && !lines[insertAt - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            lines.insert("", at: insertAt)
            insertAt += 1
        }

        for (idx, block) in blocks.enumerated() {
            lines.insert("[[\(name)]]", at: insertAt)
            insertAt += 1
            for row in block {
                lines.insert("  \(row)", at: insertAt)
                insertAt += 1
            }
            if idx < blocks.count - 1 {
                lines.insert("", at: insertAt)
                insertAt += 1
            }
        }
    }

    mutating func replaceSection(name: String, rows: [String], preferredAnchorSection: String?) {
        removeSections { $0 == name }
        guard !rows.isEmpty else {
            return
        }
        insertSections([(name, rows)], preferredAnchorSection: preferredAnchorSection)
    }

    mutating func replaceSections(prefix: String, sections: [(String, [String])], preferredAnchorSection: String?) {
        removeSections { $0.hasPrefix(prefix) }
        let filtered = sections.filter { !$0.1.isEmpty }
        guard !filtered.isEmpty else {
            return
        }
        insertSections(filtered, preferredAnchorSection: preferredAnchorSection)
    }

    func rendered() -> String {
        var output = lines
        while output.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            output.removeLast()
        }
        return output.joined(separator: "\n") + "\n"
    }

    private mutating func ensureSection(named name: String) -> SectionReference {
        if let existing = sectionReference(named: name) {
            return existing
        }

        if !lines.isEmpty, lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == false {
            lines.append("")
        }
        lines.append("[\(name)]")
        return SectionReference(headerIndex: lines.count - 1, endIndex: lines.count)
    }

    private func findKeyLine(section: String?, keys: Set<String>) -> Int? {
        var currentSection: String?
        var currentArraySection: String?

        for index in lines.indices {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if let header = parseHeader(from: trimmed) {
                if header.isArray {
                    currentArraySection = header.name
                    currentSection = nil
                } else {
                    currentSection = header.name
                    currentArraySection = nil
                }
                continue
            }

            if currentArraySection != nil {
                continue
            }

            if section == nil {
                if currentSection != nil {
                    continue
                }
            } else if currentSection != section {
                continue
            }

            guard let assignment = parseAssignment(from: trimmed) else {
                continue
            }
            if keys.contains(assignment.key) {
                return index
            }
        }

        return nil
    }

    private func firstHeaderIndex() -> Int? {
        lines.indices.first(where: { parseHeader(from: lines[$0].trimmingCharacters(in: .whitespaces)) != nil })
    }

    private func sectionReference(named name: String) -> SectionReference? {
        for idx in lines.indices {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            guard let header = parseHeader(from: trimmed), !header.isArray, header.name == name else {
                continue
            }

            var end = lines.count
            var cursor = idx + 1
            while cursor < lines.count {
                let line = lines[cursor].trimmingCharacters(in: .whitespaces)
                if parseHeader(from: line) != nil {
                    end = cursor
                    break
                }
                cursor += 1
            }
            return SectionReference(headerIndex: idx, endIndex: end)
        }
        return nil
    }

    private func indentationForSection(sectionRef: SectionReference) -> String {
        guard sectionRef.headerIndex < sectionRef.endIndex else {
            return "  "
        }
        for idx in (sectionRef.headerIndex + 1)..<sectionRef.endIndex {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }
            if parseHeader(from: trimmed) != nil {
                continue
            }
            if parseAssignment(from: trimmed) != nil {
                return leadingWhitespace(of: lines[idx])
            }
        }
        return "  "
    }

    private func insertionIndexForSection(sectionRef: SectionReference) -> Int {
        var insertAt = sectionRef.endIndex
        while insertAt > sectionRef.headerIndex + 1 {
            let previous = lines[insertAt - 1].trimmingCharacters(in: .whitespaces)
            if previous.isEmpty {
                insertAt -= 1
                continue
            }
            break
        }
        return insertAt
    }

    private mutating func insertSections(_ sections: [(String, [String])], preferredAnchorSection: String?) {
        var insertAt: Int
        if let preferredAnchorSection,
           let sectionRef = sectionReference(named: preferredAnchorSection) {
            insertAt = insertionIndexForSection(sectionRef: sectionRef)
        } else {
            insertAt = lines.count
        }

        if insertAt > 0 && !lines[insertAt - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            lines.insert("", at: insertAt)
            insertAt += 1
        }

        for (index, section) in sections.enumerated() {
            lines.insert("[\(section.0)]", at: insertAt)
            insertAt += 1
            for row in section.1 {
                lines.insert("  \(row)", at: insertAt)
                insertAt += 1
            }
            if index < sections.count - 1 {
                lines.insert("", at: insertAt)
                insertAt += 1
            }
        }
    }

    private mutating func removeArrayTable(named name: String) {
        var idx = 0
        while idx < lines.count {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            if let header = parseHeader(from: trimmed), header.isArray, header.name == name {
                let start = idx
                idx += 1
                while idx < lines.count {
                    let nextTrimmed = lines[idx].trimmingCharacters(in: .whitespaces)
                    if parseHeader(from: nextTrimmed) != nil {
                        break
                    }
                    idx += 1
                }
                lines.removeSubrange(start..<idx)
                idx = start
                while idx > 0 && idx < lines.count
                    && lines[idx - 1].trimmingCharacters(in: .whitespaces).isEmpty
                    && lines[idx].trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.remove(at: idx)
                }
                continue
            }
            idx += 1
        }
    }

    private mutating func removeSections(where predicate: (String) -> Bool) {
        var idx = 0
        while idx < lines.count {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)
            if let header = parseHeader(from: trimmed), !header.isArray, predicate(header.name) {
                let start = idx
                idx += 1
                while idx < lines.count {
                    let nextTrimmed = lines[idx].trimmingCharacters(in: .whitespaces)
                    if parseHeader(from: nextTrimmed) != nil {
                        break
                    }
                    idx += 1
                }
                lines.removeSubrange(start..<idx)
                idx = start
                while idx > 0 && idx < lines.count
                    && lines[idx - 1].trimmingCharacters(in: .whitespaces).isEmpty
                    && lines[idx].trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.remove(at: idx)
                }
                if idx < lines.count && idx > 0
                    && lines[idx].trimmingCharacters(in: .whitespaces).isEmpty
                    && lines[idx - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                    lines.remove(at: idx)
                }
                continue
            }
            idx += 1
        }
    }

    private func parseHeader(from trimmedLine: String) -> (name: String, isArray: Bool)? {
        let headerCandidate = trimmedLine
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespaces) ?? trimmedLine

        if headerCandidate.hasPrefix("[[") && headerCandidate.hasSuffix("]]") {
            let name = String(headerCandidate.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
            return (name, true)
        }
        if headerCandidate.hasPrefix("[") && headerCandidate.hasSuffix("]") {
            let name = String(headerCandidate.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            return (name, false)
        }
        return nil
    }

    private func parseAssignment(from trimmedLine: String) -> (key: String, value: String)? {
        guard let idx = trimmedLine.firstIndex(of: "=") else {
            return nil
        }
        let key = trimmedLine[..<idx].trimmingCharacters(in: .whitespaces)
        let value = trimmedLine[trimmedLine.index(after: idx)...].trimmingCharacters(in: .whitespaces)
        return (String(key), String(value))
    }

    private func leadingWhitespace(of line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }
}

private struct SectionReference {
    var headerIndex: Int
    var endIndex: Int
}
