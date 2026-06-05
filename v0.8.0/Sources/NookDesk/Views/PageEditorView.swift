import SwiftUI

struct PageEditorView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedPage: EditablePage = .home
    @State private var editingText: String = ""
    @State private var isLoading = false
    @State private var statusMessage: String = ""

    private let tsPostService = TypeScriptPostService()

    enum EditablePage: String, CaseIterable, Identifiable {
        case home = "Home.tsx"
        case posts = "posts.ts"
        case config = "vite.config.ts"
        case index = "index.html"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .posts: return "doc.text.fill"
            case .config: return "gearshape.fill"
            case .index: return "doc.richtext"
            }
        }

        var description: String {
            switch self {
            case .home: return "首页内容：个人信息、技能、统计、关于、FAQ"
            case .posts: return "文章数据：所有博客文章的 TypeScript 数据"
            case .config: return "Vite 构建配置：base 路径、插件、CSS 预处理"
            case .index: return "HTML 入口：页面标题、语言设置、meta 标签"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            pageSelector
            NookDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedPage == .posts {
                        postsPageEditor
                    } else {
                        fieldBasedEditor
                    }
                }
                .padding()
            }
        }
    }

    private var pageSelector: some View {
        HStack(spacing: 12) {
            ForEach(EditablePage.allCases) { page in
                Button {
                    selectedPage = page
                    if page == .posts {
                        loadPageContent()
                    } else {
                        loadFieldBasedContent()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: page.icon)
                            .font(.system(size: 12))
                        Text(page.rawValue)
                            .font(.custom("Nunito-SemiBold", size: 13))
                    }
                    .foregroundColor(selectedPage == page ? .white : .aiTextBody)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedPage == page ? Color.aiPrimary : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(selectedPage.description)
                .font(.custom("Nunito-Regular", size: 12))
                .foregroundColor(.aiTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.aiSecondaryBg)
        .onAppear { loadFieldBasedContent() }
    }

    // MARK: - Field-Based Editor

    private struct EditableField: Identifiable {
        let id = UUID()
        let name: String
        let currentValue: String
        let affects: String
        let description: String
        var filePath: String
        var lineHint: String
    }

    @State private var editableFields: [EditableField] = []
    @State private var editingValues: [UUID: String] = [:]

    private var fieldBasedEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerCard

            ForEach(groupedFields, id: \.0) { group, fields in
                NookCard(color: colorForGroup(group)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(group)
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(.aiTextHeader)

                        ForEach(fields) { field in
                            fieldRow(field)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                NookButton(.primary, size: .small, label: "保存全部更改") {
                    saveFieldChanges()
                }
                NookButton(.default, size: .small, label: "重新加载") {
                    loadFieldBasedContent()
                }
                Spacer()
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextMuted)
                }
            }
        }
    }

    private var headerCard: some View {
        NookCard(color: .appBlue) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(NookColor.appYellow.color)
                    Text("傻瓜式编辑器")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)
                }
                Text("每个字段都有说明，告诉你它在哪个文件的哪个位置。修改后点击「保存全部更改」即可写入文件。")
                    .font(.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.aiTextSecondary)
            }
        }
    }

    private func fieldRow(_ field: EditableField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.name)
                        .font(.custom("Nunito-Bold", size: 14))
                        .foregroundColor(.aiTextHeader)

                    Text(field.description)
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.aiPrimary)
                        Text(field.affects)
                            .font(.custom("Nunito-Regular", size: 11))
                            .foregroundColor(.aiPrimary)
                    }
                }

                Spacer()
            }

            if field.currentValue.count > 80 {
                TextEditor(text: Binding(
                    get: { editingValues[field.id] ?? field.currentValue },
                    set: { editingValues[field.id] = $0 }
                ))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 60, maxHeight: 120)
                .padding(4)
                .background(Color.aiBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                TextField(field.currentValue, text: Binding(
                    get: { editingValues[field.id] ?? field.currentValue },
                    set: { editingValues[field.id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.custom("Nunito-Medium", size: 13))
            }
        }
        .padding(.vertical, 4)
    }

    private var groupedFields: [(String, [EditableField])] {
        Dictionary(grouping: editableFields, by: { $0.filePath })
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private func colorForGroup(_ group: String) -> NookColor {
        switch group {
        case "Home.tsx": return .appBlue
        case "posts.ts": return .appGreen
        case "vite.config.ts": return .appOrange
        case "index.html": return .appYellow
        default: return .nookDefault
        }
    }

    private func loadFieldBasedContent() {
        editableFields = []
        editingValues = [:]
        statusMessage = ""

        let root = viewModel.project.rootURL

        switch selectedPage {
        case .home:
            loadHomeFields(root: root)
        case .config:
            loadConfigFields(root: root)
        case .index:
            loadIndexFields(root: root)
        case .posts:
            break
        }
    }

    private func loadHomeFields(root: URL) {
        let homePath = root.appendingPathComponent("src/pages/Home/Home.tsx")
        guard let content = try? String(contentsOf: homePath, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }

        var fields: [EditableField] = []

        fields.append(EditableField(
            name: "站点标题",
            currentValue: extractBetween(content, after: "blog-logo-title\">", before: "</div>") ?? "sexyfeifan 的小岛",
            affects: "→ Home.tsx blog-logo-title",
            description: "显示在博客左上角的品牌名称",
            filePath: "Home.tsx",
            lineHint: "blog-logo-title"
        ))

        fields.append(EditableField(
            name: "站点副标题",
            currentValue: extractBetween(content, after: "blog-logo-sub\">", before: "</div>") ?? "code, tools & random thoughts",
            affects: "→ Home.tsx blog-logo-sub",
            description: "品牌名称下方的小字描述",
            filePath: "Home.tsx",
            lineHint: "blog-logo-sub"
        ))

        fields.append(EditableField(
            name: "英雄区打字文本",
            currentValue: extractBetween(content, after: "Typewriter", before: "</Typewriter>")?.replacingOccurrences(of: ">\n                            ", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            affects: "→ Home.tsx Typewriter 组件",
            description: "首页大标题的打字机动画文本",
            filePath: "Home.tsx",
            lineHint: "Typewriter"
        ))

        fields.append(EditableField(
            name: "英雄区描述",
            currentValue: extractBetween(content, after: "blog-hero-sub\">", before: "</p>")?.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            affects: "→ Home.tsx blog-hero-sub",
            description: "英雄区标题下方的描述段落",
            filePath: "Home.tsx",
            lineHint: "blog-hero-sub"
        ))

        fields.append(EditableField(
            name: "关于区头像 Emoji",
            currentValue: extractBetween(content, after: "blog-avatar\">", before: "</div>") ?? "🦊",
            affects: "→ Home.tsx blog-avatar",
            description: "「关于我」区域的头像 emoji",
            filePath: "Home.tsx",
            lineHint: "blog-avatar"
        ))

        fields.append(EditableField(
            name: "关于区姓名/身份",
            currentValue: extractBetween(content, after: "<h3>", before: "</h3>") ?? "",
            affects: "→ Home.tsx 关于区 h3",
            description: "「关于我」区域的姓名和身份描述",
            filePath: "Home.tsx",
            lineHint: "about h3"
        ))

        fields.append(EditableField(
            name: "关于区描述",
            currentValue: extractBetween(content, after: "关于我</h2>", before: "</Card>")?.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            affects: "→ Home.tsx 关于区 p",
            description: "「关于我」区域的详细介绍",
            filePath: "Home.tsx",
            lineHint: "about p"
        ))

        fields.append(EditableField(
            name: "页面标题 (title tag)",
            currentValue: extractBetween(content, after: "<title>", before: "</title>") ?? "",
            affects: "→ index.html <title>",
            description: "浏览器标签页上显示的标题",
            filePath: "index.html",
            lineHint: "title"
        ))

        editableFields = fields
        statusMessage = "已加载 Home.tsx 的 \(fields.count) 个可编辑字段。"
    }

    private func loadConfigFields(root: URL) {
        let configPath = root.appendingPathComponent("vite.config.ts")
        guard let content = try? String(contentsOf: configPath, encoding: .utf8) else {
            statusMessage = "无法读取 vite.config.ts"
            return
        }

        var fields: [EditableField] = []

        let baseValue = extractBetween(content, after: "base:", before: ",")?.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "") ?? "/"
        fields.append(EditableField(
            name: "Base 路径",
            currentValue: baseValue,
            affects: "→ vite.config.ts base",
            description: "部署 URL 的基础路径。GitHub Pages 用户页通常是 /，项目页是 /repo-name/",
            filePath: "vite.config.ts",
            lineHint: "base"
        ))

        let hasLess = content.contains("less")
        fields.append(EditableField(
            name: "Less 预处理器",
            currentValue: hasLess ? "已启用" : "未启用",
            affects: "→ vite.config.ts css.preprocessorOptions.less",
            description: "是否启用 Less CSS 预处理器",
            filePath: "vite.config.ts",
            lineHint: "less"
        ))

        let hasSvgr = content.contains("svgr")
        fields.append(EditableField(
            name: "SVGR 插件",
            currentValue: hasSvgr ? "已启用" : "未启用",
            affects: "→ vite.config.ts plugins",
            description: "是否启用 SVG 作为 React 组件的插件",
            filePath: "vite.config.ts",
            lineHint: "svgr"
        ))

        editableFields = fields
        statusMessage = "已加载 vite.config.ts 的 \(fields.count) 个可编辑字段。"
    }

    private func loadIndexFields(root: URL) {
        let indexPath = root.appendingPathComponent("index.html")
        guard let content = try? String(contentsOf: indexPath, encoding: .utf8) else {
            statusMessage = "无法读取 index.html"
            return
        }

        var fields: [EditableField] = []

        fields.append(EditableField(
            name: "页面标题",
            currentValue: extractBetween(content, after: "<title>", before: "</title>") ?? "",
            affects: "→ index.html <title>",
            description: "浏览器标签页上显示的标题，也用于搜索引擎结果",
            filePath: "index.html",
            lineHint: "title"
        ))

        let lang = extractBetween(content, after: "<html lang=\"", before: "\"") ?? "ja"
        fields.append(EditableField(
            name: "语言设置",
            currentValue: lang,
            affects: "→ index.html <html lang>",
            description: "页面语言代码，如 zh-CN（中文）、ja（日语）、en（英语）",
            filePath: "index.html",
            lineHint: "lang"
        ))

        let charset = content.contains("UTF-8") ? "UTF-8" : "未知"
        fields.append(EditableField(
            name: "字符编码",
            currentValue: charset,
            affects: "→ index.html <meta charset>",
            description: "页面字符编码（通常保持 UTF-8）",
            filePath: "index.html",
            lineHint: "charset"
        ))

        editableFields = fields
        statusMessage = "已加载 index.html 的 \(fields.count) 个可编辑字段。"
    }

    private func saveFieldChanges() {
        let root = viewModel.project.rootURL
        var changedFiles = Set<String>()

        for field in editableFields {
            guard let newValue = editingValues[field.id], newValue != field.currentValue else { continue }

            let filePath: URL
            switch field.filePath {
            case "Home.tsx":
                filePath = root.appendingPathComponent("src/pages/Home/Home.tsx")
            case "vite.config.ts":
                filePath = root.appendingPathComponent("vite.config.ts")
            case "index.html":
                filePath = root.appendingPathComponent("index.html")
            default:
                continue
            }

            guard var content = try? String(contentsOf: filePath, encoding: .utf8) else { continue }

            switch field.name {
            case "站点标题":
                content = replaceInHTML(content, cssClass: "blog-logo-title", newInner: newValue)
            case "站点副标题":
                content = replaceInHTML(content, cssClass: "blog-logo-sub", newInner: newValue)
            case "关于区头像 Emoji":
                content = replaceInHTML(content, cssClass: "blog-avatar", newInner: newValue)
            case "页面标题", "页面标题 (title tag)":
                content = replaceBetween(content, after: "<title>", before: "</title>", with: newValue)
            case "语言设置":
                content = content.replacingOccurrences(
                    of: "<html lang=\"\(field.currentValue)\">",
                    with: "<html lang=\"\(newValue)\">"
                )
            case "Base 路径":
                content = content.replacingOccurrences(
                    of: "base: \"\(field.currentValue)\"",
                    with: "base: \"\(newValue)\""
                )
                if content.contains("base: '\(field.currentValue)'") {
                    content = content.replacingOccurrences(
                        of: "base: '\(field.currentValue)'",
                        with: "base: '\(newValue)'"
                    )
                }
            default:
                break
            }

            do {
                try content.write(to: filePath, atomically: true, encoding: .utf8)
                changedFiles.insert(field.filePath)
            } catch {
                statusMessage = "保存失败：\(error.localizedDescription)"
                return
            }
        }

        if changedFiles.isEmpty {
            statusMessage = "没有更改需要保存。"
        } else {
            statusMessage = "已保存到：\(changedFiles.sorted().joined(separator: ", "))"
            editingValues = [:]
            loadFieldBasedContent()
        }
    }

    // MARK: - Posts Page Editor

    private var postsPageEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            NookCard(color: .appGreen) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("posts.ts 文章管理")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)

                    Text("管理博客文章数据。文章存储在 src/pages/Home/posts.ts 中。请切换到「写作」标签页使用完整的文章编辑功能。")
                        .font(.custom("Nunito-Medium", size: 13))
                        .foregroundColor(.aiTextSecondary)

                    TextEditor(text: $editingText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 400)
                        .padding(8)
                        .background(Color.aiBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 8) {
                        NookButton(.primary, size: .small, label: "保存") {
                            savePageContent()
                        }
                        NookButton(.default, size: .small, label: "重新加载") {
                            loadPageContent()
                        }
                        Spacer()
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.custom("Nunito-Regular", size: 12))
                                .foregroundColor(.aiTextMuted)
                        }
                    }
                }
            }
        }
        .onAppear { loadPageContent() }
    }

    // MARK: - File Operations

    private func loadPageContent() {
        isLoading = true
        statusMessage = ""

        let filePath = filePathForSelectedPage()
        if let content = try? String(contentsOf: filePath, encoding: .utf8) {
            editingText = content
            statusMessage = "已加载 \(selectedPage.rawValue)"
        } else {
            editingText = "// 文件未找到: \(filePath.path)"
            statusMessage = "文件未找到"
        }
        isLoading = false
    }

    private func savePageContent() {
        let filePath = filePathForSelectedPage()
        do {
            try FileManager.default.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try editingText.write(to: filePath, atomically: true, encoding: .utf8)
            statusMessage = "已保存 \(selectedPage.rawValue)"
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func filePathForSelectedPage() -> URL {
        let root = viewModel.project.rootURL
        switch selectedPage {
        case .home:
            return root.appendingPathComponent("src/pages/Home/Home.tsx")
        case .posts:
            return root.appendingPathComponent("src/pages/Home/posts.ts")
        case .config:
            return root.appendingPathComponent("vite.config.ts")
        case .index:
            return root.appendingPathComponent("index.html")
        }
    }

    // MARK: - String Helpers

    private func extractBetween(_ text: String, after: String, before: String) -> String? {
        guard let startRange = text.range(of: after) else { return nil }
        let afterStart = text[startRange.upperBound...]
        guard let endRange = afterStart.range(of: before) else { return nil }
        return String(afterStart[..<endRange.lowerBound])
    }

    private func replaceBetween(_ text: String, after: String, before: String, with replacement: String) -> String {
        guard let startRange = text.range(of: after) else { return text }
        let afterStart = text[startRange.upperBound...]
        guard let endRange = afterStart.range(of: before) else { return text }
        var result = text
        let replaceRange = startRange.upperBound..<endRange.lowerBound
        result.replaceSubrange(replaceRange, with: replacement)
        return result
    }

    private func replaceInHTML(_ text: String, cssClass: String, newInner: String) -> String {
        let pattern = "(<[^>]*class=\"[^\"]*\(cssClass)[^\"]*\"[^>]*>)([^<]*)(</[^>]+>)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 3 {
            let openTag = ns.substring(with: match.range(at: 1))
            let closeTag = ns.substring(with: match.range(at: 3))
            let replacement = "\(openTag)\(newInner)\(closeTag)"
            return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
        }
        return text
    }
}
