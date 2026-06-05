import SwiftUI

struct PageEditorView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var statusMessage: String = ""

    @State private var brandTitle = ""
    @State private var brandSubtitle = ""
    @State private var heroTypewriter = ""
    @State private var heroDescription = ""

    @State private var skills: [SkillItem] = []
    @State private var stats: [StatItem] = []
    @State private var aboutName = ""
    @State private var aboutDescription = ""
    @State private var faqs: [FAQItem] = []

    @State private var tsPostCount: Int = 0

    private let tsPostService = TypeScriptPostService()

    struct SkillItem: Identifiable {
        let id = UUID()
        var name: String
        var color: String
    }

    struct StatItem: Identifiable {
        let id = UUID()
        var label: String
        var value: String
        var color: String
    }

    struct FAQItem: Identifiable {
        let id = UUID()
        var question: String
        var answer: String
    }

    private var homeURL: URL {
        viewModel.project.rootURL.appendingPathComponent("src/pages/Home/Home.tsx")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                brandSection
                heroSection
                skillsSection
                statsSection
                aboutSection
                faqSection

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextMuted)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .onAppear { loadAllSections() }
    }

    private var headerCard: some View {
        NookCard(color: .appBlue) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "paintbrush.fill")
                        .foregroundColor(NookColor.appBlue.color)
                    Text("首页编辑器")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.aiPrimary)
                        Text("posts.ts 文章数：\(tsPostCount)")
                            .font(.custom("Nunito-SemiBold", size: 12))
                            .foregroundColor(.aiTextHeader)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.aiPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text("在这里修改博客首页的各个区域，无需接触代码。每个区域修改后点击「保存」即可写入文件。")
                    .font(.custom("Nunito-Regular", size: 13))
                    .foregroundColor(.aiTextSecondary)
            }
        }
    }

    // MARK: - Brand Section

    private var brandSection: some View {
        NookCard(color: .appYellow) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("品牌标识", icon: "flag.fill")
                NookDivider()

                fieldRow("站点标题") {
                    TextField("站点标题", text: $brandTitle)
                        .textFieldStyle(.roundedBorder)
                }
                fieldRow("站点副标题") {
                    TextField("站点副标题", text: $brandSubtitle)
                        .textFieldStyle(.roundedBorder)
                }

                saveButton {
                    saveBrand()
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        NookCard(color: .appPink) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("英雄区", icon: "text.bubble.fill")
                NookDivider()

                fieldRow("打字机动画文字") {
                    TextField("打字机动画文字", text: $heroTypewriter, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }
                fieldRow("描述文字") {
                    TextField("描述文字", text: $heroDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                saveButton {
                    saveHero()
                }
            }
        }
    }

    // MARK: - Skills Section

    private var skillsSection: some View {
        NookCard(color: .appBlue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader("技能标签", icon: "star.fill")
                    Spacer()
                    NookButton(.default, size: .small, label: "+ 添加") {
                        skills.append(SkillItem(name: "新技能", color: "app-blue"))
                    }
                }
                NookDivider()

                ForEach(skills.indices, id: \.self) { idx in
                    HStack(spacing: 8) {
                        TextField("技能名", text: $skills[idx].name)
                            .textFieldStyle(.roundedBorder)
                        Picker("", selection: $skills[idx].color) {
                            ForEach(blogColors, id: \.self) { color in
                                Text(color).tag(color)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 130)

                        Button {
                            skills.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(.aiError)
                        }
                        .buttonStyle(.plain)
                    }
                }

                saveButton {
                    saveSkills()
                }
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        NookCard(color: .appOrange) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader("统计数据", icon: "chart.bar.fill")
                    Spacer()
                    NookButton(.default, size: .small, label: "+ 添加") {
                        stats.append(StatItem(label: "新统计", value: "0", color: "app-yellow"))
                    }
                }
                NookDivider()

                ForEach(stats.indices, id: \.self) { idx in
                    HStack(spacing: 8) {
                        TextField("标签", text: $stats[idx].label)
                            .textFieldStyle(.roundedBorder)
                        TextField("数值", text: $stats[idx].value)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Picker("", selection: $stats[idx].color) {
                            ForEach(blogColors, id: \.self) { color in
                                Text(color).tag(color)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 130)

                        Button {
                            stats.remove(at: idx)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 13))
                                .foregroundColor(.aiError)
                        }
                        .buttonStyle(.plain)
                    }
                }

                saveButton {
                    saveStats()
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        NookCard(color: .appGreen) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("关于我", icon: "person.fill")
                NookDivider()

                fieldRow("姓名 / 身份") {
                    TextField("姓名 / 身份", text: $aboutName)
                        .textFieldStyle(.roundedBorder)
                }
                fieldRow("个人描述") {
                    TextField("个人描述", text: $aboutDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }

                saveButton {
                    saveAbout()
                }
            }
        }
    }

    // MARK: - FAQ Section

    private var faqSection: some View {
        NookCard(color: .appTeal) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    sectionHeader("常见问题", icon: "bubble.left.and.bubble.right.fill")
                    Spacer()
                    NookButton(.default, size: .small, label: "+ 添加") {
                        faqs.append(FAQItem(question: "新问题？", answer: "新回答"))
                    }
                }
                NookDivider()

                ForEach(faqs.indices, id: \.self) { idx in
                    NookCard(color: .nookDefault) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("问题 \(idx + 1)")
                                    .font(.custom("Nunito-SemiBold", size: 13))
                                    .foregroundColor(.aiTextHeader)
                                Spacer()
                                Button {
                                    faqs.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .font(.system(size: 13))
                                        .foregroundColor(.aiError)
                                }
                                .buttonStyle(.plain)
                            }
                            TextField("问题", text: $faqs[idx].question)
                                .textFieldStyle(.roundedBorder)
                            TextField("回答", text: $faqs[idx].answer, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                saveButton {
                    saveFAQs()
                }
            }
        }
    }

    // MARK: - UI Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.aiPrimary)
            Text(title)
                .font(.custom("Nunito-Bold", size: 16))
                .foregroundColor(.aiTextHeader)
        }
    }

    private func fieldRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
            content()
        }
    }

    private func saveButton(action: @escaping () -> Void) -> some View {
        HStack {
            Spacer()
            NookButton(.primary, size: .small, label: "保存") {
                action()
            }
        }
    }

    private let blogColors = [
        "app-pink", "purple", "app-blue", "app-yellow", "app-orange",
        "app-teal", "app-green", "app-red", "lime-green", "yellow-green",
        "brown", "warm-peach-pink",
    ]

    // MARK: - Load

    private func loadAllSections() {
        guard let content = try? String(contentsOf: homeURL, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }

        brandTitle = extractText(in: content, after: "blog-logo-title\">", before: "</div>") ?? ""
        brandSubtitle = extractText(in: content, after: "blog-logo-sub\">", before: "</div>") ?? ""

        heroTypewriter = extractTypewriterText(from: content) ?? ""
        heroDescription = extractHeroDescription(from: content) ?? ""

        skills = parseSkills(from: content)
        stats = parseStats(from: content)
        aboutName = extractText(in: content, after: "<h3>", before: "</h3>") ?? ""
        aboutDescription = extractAboutDescription(from: content) ?? ""
        faqs = parseFAQs(from: content)

        if let tsPosts = try? tsPostService.loadPosts(from: viewModel.project) {
            tsPostCount = tsPosts.count
        }

        statusMessage = "已加载首页数据。文章数：\(tsPostCount)。"
    }

    // MARK: - Save Brand

    private func saveBrand() {
        guard var content = try? String(contentsOf: homeURL, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }
        let oldTitle = extractText(in: content, after: "blog-logo-title\">", before: "</div>") ?? ""
        let oldSub = extractText(in: content, after: "blog-logo-sub\">", before: "</div>") ?? ""

        if !oldTitle.isEmpty && oldTitle != brandTitle {
            content = content.replacingOccurrences(
                of: "blog-logo-title\">\(oldTitle)</div>",
                with: "blog-logo-title\">\(brandTitle)</div>"
            )
        }
        if !oldSub.isEmpty && oldSub != brandSubtitle {
            content = content.replacingOccurrences(
                of: "blog-logo-sub\">\(oldSub)</div>",
                with: "blog-logo-sub\">\(brandSubtitle)</div>"
            )
        }

        writeBack(content, section: "品牌标识")
    }

    // MARK: - Save Hero

    private func saveHero() {
        guard var content = try? String(contentsOf: homeURL, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }

        let oldTypewriter = extractTypewriterText(from: content) ?? ""
        if !oldTypewriter.isEmpty && oldTypewriter != heroTypewriter {
            content = content.replacingOccurrences(of: oldTypewriter, with: heroTypewriter)
        }

        let oldDesc = extractHeroDescription(from: content) ?? ""
        if !oldDesc.isEmpty && oldDesc != heroDescription {
            content = content.replacingOccurrences(of: oldDesc, with: heroDescription)
        }

        writeBack(content, section: "英雄区")
    }

    // MARK: - Save Skills

    private func saveSkills() {
        guard var content = try? String(contentsOf: homeURL, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }

        let oldBlock = extractArrayBlock(in: content, marker: "const skills:")
        let newItems = skills.map { "    { name: \"\($0.name)\", color: \"\($0.color)\" }" }.joined(separator: ",\n")
        let newBlock = "const skills: { name: string; color: BlogColor }[] = [\n\(newItems),\n];"

        if let old = oldBlock {
            content = content.replacingOccurrences(of: old, with: newBlock)
        }

        writeBack(content, section: "技能标签")
    }

    // MARK: - Save Stats

    private func saveStats() {
        guard var content = try? String(contentsOf: homeURL, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }

        let oldBlock = extractArrayBlock(in: content, marker: "const stats:")
        let newItems = stats.map { "    { label: \"\($0.label)\", value: \"\($0.value)\", color: \"\($0.color)\" }" }.joined(separator: ",\n")
        let newBlock = "const stats: { label: string; value: string; color: BlogColor }[] = [\n\(newItems),\n];"

        if let old = oldBlock {
            content = content.replacingOccurrences(of: old, with: newBlock)
        }

        writeBack(content, section: "统计数据")
    }

    // MARK: - Save About

    private func saveAbout() {
        guard var content = try? String(contentsOf: homeURL, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }

        let oldName = extractText(in: content, after: "<h3>", before: "</h3>") ?? ""
        if !oldName.isEmpty && oldName != aboutName {
            content = content.replacingOccurrences(of: "<h3>\(oldName)</h3>", with: "<h3>\(aboutName)</h3>")
        }

        let oldDesc = extractAboutDescription(from: content) ?? ""
        if !oldDesc.isEmpty && oldDesc != aboutDescription {
            content = content.replacingOccurrences(of: oldDesc, with: aboutDescription)
        }

        writeBack(content, section: "关于我")
    }

    // MARK: - Save FAQs

    private func saveFAQs() {
        guard var content = try? String(contentsOf: homeURL, encoding: .utf8) else {
            statusMessage = "无法读取 Home.tsx"
            return
        }

        let oldFAQs = parseFAQs(from: content)
        for (idx, faq) in faqs.enumerated() {
            guard idx < oldFAQs.count else { break }
            let old = oldFAQs[idx]
            if old.question != faq.question {
                content = content.replacingOccurrences(
                    of: "question=\"\(old.question)\"",
                    with: "question=\"\(faq.question)\""
                )
            }
            if old.answer != faq.answer {
                content = content.replacingOccurrences(
                    of: "answer=\"\(old.answer)\"",
                    with: "answer=\"\(faq.answer)\""
                )
            }
        }

        if faqs.count > oldFAQs.count {
            let insertMarker = "</div>\n            </section>\n\n            <Divider type=\"line-yellow\""
            let newFAQs = faqs[oldFAQs.count...].map { faq in
                """
                            <Collapse
                                question=\"\(faq.question)\"
                                answer=\"\(faq.answer)\"
                            />
                """
            }.joined(separator: "\n")
            if let range = content.range(of: insertMarker) {
                content.insert(contentsOf: newFAQs + "\n", at: range.lowerBound)
            }
        }

        writeBack(content, section: "常见问题")
    }

    // MARK: - Write Back

    private func writeBack(_ content: String, section: String) {
        do {
            try content.write(to: homeURL, atomically: true, encoding: .utf8)
            statusMessage = "「\(section)」已保存。"
            viewModel.hasUnsavedPageChanges = true
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    // MARK: - Parsing Helpers

    private func extractText(in text: String, after: String, before: String) -> String? {
        guard let startRange = text.range(of: after) else { return nil }
        let afterStart = text[startRange.upperBound...]
        guard let endRange = afterStart.range(of: before) else { return nil }
        return String(afterStart[..<endRange.lowerBound])
    }

    private func extractTypewriterText(from content: String) -> String? {
        guard let start = content.range(of: "<Typewriter"),
              let end = content.range(of: "</Typewriter>") else { return nil }
        let inner = content[start.upperBound..<end.lowerBound]
        if let gt = inner.range(of: ">") {
            return String(inner[gt.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractHeroDescription(from content: String) -> String? {
        guard let start = content.range(of: "blog-hero-sub\">"),
              let end = content.range(of: "</p>", range: start.upperBound..<content.endIndex) else { return nil }
        let raw = String(content[start.upperBound..<end.lowerBound])
        return raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractAboutDescription(from content: String) -> String? {
        guard let h3End = content.range(of: "</h3>"),
              let pStart = content.range(of: "<p>", range: h3End.upperBound..<content.endIndex),
              let pEnd = content.range(of: "</p>", range: pStart.upperBound..<content.endIndex) else { return nil }
        return String(content[pStart.upperBound..<pEnd.lowerBound])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractArrayBlock(in content: String, marker: String) -> String? {
        guard let start = content.range(of: marker) else { return nil }
        let afterStart = content[start.lowerBound...]
        guard let openBracket = afterStart.range(of: "["), let closeBracket = afterStart.range(of: "];") else { return nil }
        return String(content[start.lowerBound..<closeBracket.upperBound])
    }

    private func parseSkills(from content: String) -> [SkillItem] {
        guard let block = extractArrayBlock(in: content, marker: "const skills:") else { return [] }
        var items: [SkillItem] = []
        let pattern = #"\{\s*name:\s*"([^"]+)"\s*,\s*color:\s*"([^"]+)"\s*\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = block as NSString
        for match in regex.matches(in: block, range: NSRange(location: 0, length: ns.length)) {
            if match.numberOfRanges > 2 {
                items.append(SkillItem(
                    name: ns.substring(with: match.range(at: 1)),
                    color: ns.substring(with: match.range(at: 2))
                ))
            }
        }
        return items
    }

    private func parseStats(from content: String) -> [StatItem] {
        guard let block = extractArrayBlock(in: content, marker: "const stats:") else { return [] }
        var items: [StatItem] = []
        let pattern = #"\{\s*label:\s*"([^"]+)"\s*,\s*value:\s*"([^"]+)"\s*,\s*color:\s*"([^"]+)"\s*\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = block as NSString
        for match in regex.matches(in: block, range: NSRange(location: 0, length: ns.length)) {
            if match.numberOfRanges > 3 {
                items.append(StatItem(
                    label: ns.substring(with: match.range(at: 1)),
                    value: ns.substring(with: match.range(at: 2)),
                    color: ns.substring(with: match.range(at: 3))
                ))
            }
        }
        return items
    }

    private func parseFAQs(from content: String) -> [FAQItem] {
        var items: [FAQItem] = []
        let pattern = #"question="([^"]+)"\s*\n\s*answer="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = content as NSString
        for match in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
            if match.numberOfRanges > 2 {
                items.append(FAQItem(
                    question: ns.substring(with: match.range(at: 1)),
                    answer: ns.substring(with: match.range(at: 2))
                ))
            }
        }
        return items
    }
}

extension Notification.Name {
    static let switchToWritingTab = Notification.Name("switchToWritingTab")
}
