import SwiftUI

struct PageEditorView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var statusMessage: String = ""

    @State private var astroSiteTitle = "我的无人岛"
    @State private var astroSiteDescription = "记录生活，分享技术，学习成长"
    @State private var astroProjects: [AstroProjectItem] = []
    @State private var astroFriends: [AstroFriendItem] = []

    struct AstroProjectItem: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var emoji: String
        var url: String
        var tech: String
    }

    struct AstroFriendItem: Identifiable {
        let id = UUID()
        var name: String
        var description: String
        var avatar: String
        var url: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                siteConfigSection
                projectsSection
                friendsSection

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextMuted)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .onAppear { loadSections() }
    }

    // MARK: - Header

    private var headerCard: some View {
        NookCard(color: .appBlue) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(NookColor.appBlue.color)
                    Text("页面编辑器")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)
                    Spacer()
                }
                Text("修改博客的站点配置、项目展示和友链。每个区域修改后点击「保存」即可写入文件。")
                    .font(.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.aiTextSecondary)
            }
        }
    }

    // MARK: - Site Config

    private var siteConfigSection: some View {
        NookCard(color: .appYellow) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("站点配置", icon: "gearshape.fill")
                NookDivider()

                fieldRow("站点标题") {
                    TextField("站点标题", text: $astroSiteTitle)
                        .textFieldStyle(.roundedBorder)
                }
                fieldRow("站点描述") {
                    TextField("站点描述", text: $astroSiteDescription)
                        .textFieldStyle(.roundedBorder)
                }

                saveButton { saveSiteConfig() }
            }
        }
    }

    // MARK: - Projects

    private var projectsSection: some View {
        NookCard(color: .appGreen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader("项目展示", icon: "rocket.fill")
                    Spacer()
                    NookButton(.default, size: .small, label: "+ 添加") {
                        astroProjects.append(AstroProjectItem(name: "新项目", description: "项目描述", emoji: "🚀", url: "", tech: ""))
                    }
                }
                NookDivider()

                ForEach(astroProjects.indices, id: \.self) { idx in
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            TextField("emoji", text: $astroProjects[idx].emoji)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            TextField("项目名", text: $astroProjects[idx].name)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                astroProjects.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle").foregroundColor(.aiError)
                            }
                            .buttonStyle(.plain)
                        }
                        TextField("描述", text: $astroProjects[idx].description)
                            .textFieldStyle(.roundedBorder)
                        HStack(spacing: 6) {
                            TextField("URL", text: $astroProjects[idx].url)
                                .textFieldStyle(.roundedBorder)
                            TextField("技术栈(逗号分隔)", text: $astroProjects[idx].tech)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(8)
                    .background(Color.aiBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                saveButton { saveProjects() }
            }
        }
    }

    // MARK: - Friends

    private var friendsSection: some View {
        NookCard(color: .appPink) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader("友情链接", icon: "person.2.fill")
                    Spacer()
                    NookButton(.default, size: .small, label: "+ 添加") {
                        astroFriends.append(AstroFriendItem(name: "新友链", description: "描述", avatar: "🤝", url: ""))
                    }
                }
                NookDivider()

                ForEach(astroFriends.indices, id: \.self) { idx in
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            TextField("🤝", text: $astroFriends[idx].avatar)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                            TextField("名称", text: $astroFriends[idx].name)
                                .textFieldStyle(.roundedBorder)
                            TextField("描述", text: $astroFriends[idx].description)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                astroFriends.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle").foregroundColor(.aiError)
                            }
                            .buttonStyle(.plain)
                        }
                        TextField("URL", text: $astroFriends[idx].url)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(6)
                    .background(Color.aiBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                saveButton { saveFriends() }
            }
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.aiPrimary)
            Text(title)
                .font(.custom("Nunito-Bold", size: 15))
                .foregroundColor(.aiTextHeader)
        }
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.custom("Nunito-SemiBold", size: 13))
                .foregroundColor(.aiTextSecondary)
                .frame(width: 80, alignment: .trailing)
            content()
        }
    }

    private func saveButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            NookButton(.primary, size: .small, label: "保存") { action() }
        }
    }

    // MARK: - Load

    private func loadSections() {
        let root = viewModel.project.rootURL

        if let content = try? String(contentsOf: root.appendingPathComponent("src/layouts/Base.astro"), encoding: .utf8) {
            if let titleMatch = extractText(in: content, pattern: #"<title>([^<]+)</title>"#) {
                astroSiteTitle = titleMatch
            }
            if let descMatch = extractText(in: content, pattern: #"content="([^"]+)"[^>]*name="description""#) {
                astroSiteDescription = descMatch
            }
        }

        if let content = try? String(contentsOf: root.appendingPathComponent("src/pages/projects.astro"), encoding: .utf8) {
            astroProjects = parseProjects(from: content)
        }

        if let content = try? String(contentsOf: root.appendingPathComponent("src/pages/friends.astro"), encoding: .utf8) {
            astroFriends = parseFriends(from: content)
        }

        statusMessage = "已加载页面数据。"
    }

    // MARK: - Save

    private func saveSiteConfig() {
        let root = viewModel.project.rootURL
        let layoutURL = root.appendingPathComponent("src/layouts/Base.astro")
        guard var content = try? String(contentsOf: layoutURL, encoding: .utf8) else {
            statusMessage = "无法读取 Base.astro"
            return
        }

        content = replaceText(in: content, pattern: #"<title>[^<]+</title>"#, replacement: "<title>\(astroSiteTitle)</title>")

        do {
            try content.write(to: layoutURL, atomically: true, encoding: .utf8)
            statusMessage = "站点配置已保存。"
            viewModel.hasUnsavedPageChanges = true
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func saveProjects() {
        let root = viewModel.project.rootURL
        let fileURL = root.appendingPathComponent("src/pages/projects.astro")
        guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            statusMessage = "无法读取 projects.astro"
            return
        }

        let newItems = astroProjects.map { p in
            let techArray = p.tech.split(separator: ",").map { "'\($0.trimmingCharacters(in: .whitespaces))'" }.joined(separator: ", ")
            return """
                {
                    name: '\(p.name)',
                    description: '\(p.description)',
                    emoji: '\(p.emoji)',
                    url: '\(p.url)',
                    tech: [\(techArray)],
                }
            """
        }.joined(separator: ",\n")

        let newArray = "const projects = [\n\(newItems),\n];"

        if let oldBlock = extractArrayBlock(in: content, marker: "const projects") {
            content = content.replacingOccurrences(of: oldBlock, with: newArray)
        }

        writeBack(content, fileURL: fileURL, section: "项目展示")
    }

    private func saveFriends() {
        let root = viewModel.project.rootURL
        let fileURL = root.appendingPathComponent("src/pages/friends.astro")
        guard var content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            statusMessage = "无法读取 friends.astro"
            return
        }

        let newItems = astroFriends.map { f in
            """
                {
                    name: '\(f.name)',
                    description: '\(f.description)',
                    avatar: '\(f.avatar)',
                    url: '\(f.url)',
                }
            """
        }.joined(separator: ",\n")

        let newArray = "const friends = [\n\(newItems),\n];"

        if let oldBlock = extractArrayBlock(in: content, marker: "const friends") {
            content = content.replacingOccurrences(of: oldBlock, with: newArray)
        }

        writeBack(content, fileURL: fileURL, section: "友情链接")
    }

    // MARK: - Helpers

    private func extractText(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    private func replaceText(in text: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        return regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: ns.length), withTemplate: replacement)
    }

    private func extractArrayBlock(in content: String, marker: String) -> String? {
        guard let start = content.range(of: marker) else { return nil }
        let afterStart = content[start.lowerBound...]
        guard let closeBracket = afterStart.range(of: "];") else { return nil }
        return String(content[start.lowerBound..<closeBracket.upperBound])
    }

    private func parseProjects(from content: String) -> [AstroProjectItem] {
        guard let block = extractArrayBlock(in: content, marker: "const projects") else { return [] }
        var items: [AstroProjectItem] = []
        let pattern = #"name:\s*'([^']+)'[\s\S]*?description:\s*'([^']+)'[\s\S]*?emoji:\s*'([^']+)'[\s\S]*?url:\s*'([^']+)'"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = block as NSString
        for match in regex.matches(in: block, range: NSRange(location: 0, length: ns.length)) {
            if match.numberOfRanges > 4 {
                items.append(AstroProjectItem(
                    name: ns.substring(with: match.range(at: 1)),
                    description: ns.substring(with: match.range(at: 2)),
                    emoji: ns.substring(with: match.range(at: 3)),
                    url: ns.substring(with: match.range(at: 4)),
                    tech: ""
                ))
            }
        }
        return items
    }

    private func parseFriends(from content: String) -> [AstroFriendItem] {
        guard let block = extractArrayBlock(in: content, marker: "const friends") else { return [] }
        var items: [AstroFriendItem] = []
        let pattern = #"name:\s*'([^']+)'[\s\S]*?description:\s*'([^']+)'[\s\S]*?avatar:\s*'([^']+)'[\s\S]*?url:\s*'([^']+)'"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = block as NSString
        for match in regex.matches(in: block, range: NSRange(location: 0, length: ns.length)) {
            if match.numberOfRanges > 4 {
                items.append(AstroFriendItem(
                    name: ns.substring(with: match.range(at: 1)),
                    description: ns.substring(with: match.range(at: 2)),
                    avatar: ns.substring(with: match.range(at: 3)),
                    url: ns.substring(with: match.range(at: 4))
                ))
            }
        }
        return items
    }

    private func writeBack(_ content: String, fileURL: URL, section: String) {
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            statusMessage = "「\(section)」已保存。"
            viewModel.hasUnsavedPageChanges = true
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }
}
