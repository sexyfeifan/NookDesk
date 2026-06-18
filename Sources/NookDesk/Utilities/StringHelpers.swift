import CoreFoundation
import Foundation

// MARK: - Shared String Parsing

enum StringHelpers {

    // MARK: Parse helpers

    /// Strip surrounding quotes (single or double) and unescape backslash sequences for double-quoted strings.
    static func parseString(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value.removeFirst()
            value.removeLast()
            value = decodeEscapes(value)
        } else if value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value
    }

    /// Interpret a raw config / front-matter value as a boolean (`true` only when the unquoted value is literally "true").
    static func parseBool(_ raw: String) -> Bool {
        parseString(raw).lowercased() == "true"
    }

    /// Parse a TOML/YAML-style array literal `[a, b, c]`, stripping quotes from each element.
    static func parseArray(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else {
            let single = parseString(trimmed)
            return single.isEmpty ? [] : [single]
        }
        let content = String(trimmed.dropFirst().dropLast())
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [] }
        return content
            .split(separator: ",")
            .map { parseString(String($0)) }
            .filter { !$0.isEmpty }
    }

    // MARK: Encoding helpers

    /// Produce a TOML-compatible double-quoted string with full escape handling.
    static func encodeString(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    /// Encode an array of strings as a TOML inline array.
    static func encodeArray(_ values: [String]) -> String {
        if values.isEmpty { return "[]" }
        return "[" + values.map { encodeString($0) }.joined(separator: ", ") + "]"
    }

    /// Produce a YAML-compatible double-quoted string with full escape handling.
    static func encodeYAML(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    // MARK: Slug / Identifier helpers

    /// Convert a human-readable string to a URL-safe slug. Supports CJK via pinyin transliteration.
    static func slugify(_ source: String) -> String {
        let pinyin = toPinyin(source)
        let lower = pinyin.lowercased()
        let filtered = lower.map { char -> Character in
            if char.isLetter || char.isNumber { return char }
            return "-"
        }
        let compact = String(filtered)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return compact.isEmpty ? "post-\(Int(Date().timeIntervalSince1970))" : compact
    }

    /// Produce a deterministic anchor slug from a heading, with diacritic folding.
    static func slugifyHeading(_ source: String) -> String {
        let lower = source
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let filtered = lower.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        return String(filtered)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Current timestamp formatted as `yyyyMMdd-HHmmss`.
    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }

    // MARK: GitHub repo helpers

    /// Parse `owner/repo` from a GitHub remote URL (HTTPS or SSH form).
    static func parseGitHubRepo(from remoteURL: String) throws -> (owner: String, name: String) {
        let trimmed = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("git@github.com:") {
            let rest = trimmed.replacingOccurrences(of: "git@github.com:", with: "")
            let parts = rest.split(separator: "/")
            guard parts.count == 2 else {
                throw GitHubRepoParseError.invalidRepositoryURL
            }
            let owner = String(parts[0])
            let repo = stripGitSuffix(String(parts[1]))
            return (owner, repo)
        }

        guard let url = URL(string: trimmed),
              url.host?.contains("github.com") == true else {
            throw GitHubRepoParseError.invalidRepositoryURL
        }
        let comps = url.pathComponents.filter { $0 != "/" }
        guard comps.count >= 2 else {
            throw GitHubRepoParseError.invalidRepositoryURL
        }
        let owner = comps[0]
        let repo = stripGitSuffix(comps[1])
        return (owner, repo)
    }

    /// Strip the trailing `.git` suffix from a repository name.
    static func stripGitSuffix(_ name: String) -> String {
        guard name.hasSuffix(".git") else { return name }
        return String(name.dropLast(4))
    }

    // MARK: - URL Safety

    /// Returns `true` when the URL uses http/https and does NOT point to a loopback or private-network address.
    static func isAllowedExternalURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        guard let host = url.host?.lowercased() else {
            return false
        }
        // Block obvious loopback / private targets
        let blocked: Set<String> = [
            "localhost",
            "127.0.0.1",
            "::1",
            "0.0.0.0",
            "[::1]",
        ]
        if blocked.contains(host) { return false }

        // RFC 1918 / link-local / metadata ranges
        if host.hasPrefix("10.") { return false }
        if host.hasPrefix("192.168.") { return false }
        if host.hasPrefix("172.") {
            // 172.16.0.0 – 172.31.255.255
            let parts = host.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), second >= 16 && second <= 31 {
                return false
            }
        }
        if host.hasPrefix("169.254.") { return false }
        if host == "metadata.google.internal" { return false }
        if host.hasSuffix(".local") { return false }

        return true
    }

    // MARK: - Private

    private static func decodeEscapes(_ text: String) -> String {
        var result = ""
        var escaping = false
        for ch in text {
            if escaping {
                switch ch {
                case "n": result.append("\n")
                case "r": result.append("\r")
                case "t": result.append("\t")
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                default: result.append(ch)
                }
                escaping = false
                continue
            }
            if ch == "\\" { escaping = true }
            else { result.append(ch) }
        }
        if escaping { result.append("\\") }
        return result
    }

    private static func toPinyin(_ source: String) -> String {
        let mutable = NSMutableString(string: source) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripCombiningMarks, false)
        return mutable as String
    }
}

// MARK: - Shared Error

enum GitHubRepoParseError: LocalizedError {
    case invalidRepositoryURL

    var errorDescription: String? {
        "无法解析 GitHub 仓库地址。"
    }
}
