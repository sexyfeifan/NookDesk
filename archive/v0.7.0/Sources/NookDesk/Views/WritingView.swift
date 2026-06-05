import AppKit
import SwiftUI

struct WritingView: View {
    @ObservedObject var viewModel: AppViewModel
    @StateObject private var vditorBridge = VditorEditorBridge()
    @SceneStorage("writing.columnVisibility") private var columnVisibilityRawValue = NavigationSplitViewVisibility.all.storageKey
    @State private var tagsInput = ""
    @State private var categoriesInput = ""
    @State private var editorSelection = NSRange(location: 0, length: 0)
    @State private var editorImplementation: EditorImplementation = .vditor
    @State private var imageAltText = ""
    @State private var showDeleteConfirm = false
    @State private var showingAIWritingSheet = false
    @State private var aiWritingSourceText = ""
    @State private var selectedWorkspacePickerCode = ""

    var body: some View {
        NavigationSplitView(columnVisibility: editorColumnVisibility) {
            sidebarContent
                .navigationTitle("内容")
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 340)
                .onChange(of: viewModel.selectedPostID) { _ in
                    viewModel.loadSelectedPost()
                    viewModel.cancelLivePreviewRefresh()
                    editorSelection = NSRange(location: 0, length: 0)
                    refreshInputsFromPost()
                }
        } detail: {
            detailContent
                .onAppear { refreshInputsFromPost() }
                .onDisappear { viewModel.cancelLivePreviewRefresh() }
                .onChange(of: viewModel.newPostTitle) { _ in viewModel.updateSuggestedFileName() }
                .onChange(of: viewModel.newPostCreationMode) { _ in viewModel.updateSuggestedFileName() }
                .onChange(of: viewModel.frontMatterEditorMode) { mode in
                    if mode == .raw {
                        applyInputsToPost()
                        viewModel.syncRawFrontMatterFromStructured()
                    } else {
                        viewModel.syncStructuredFieldsFromRaw()
                        refreshInputsFromPost()
                    }
                }
                .onChange(of: viewModel.editorPost.frontMatterFormat) { _ in
                    if viewModel.frontMatterEditorMode == .raw {
                        viewModel.syncRawFrontMatterFromStructured()
                    }
                }
                .alert("确认删除？", isPresented: $showDeleteConfirm) {
                    Button("删除", role: .destructive) {
                        viewModel.deleteCurrentPost()
                        editorSelection = NSRange(location: 0, length: 0)
                        refreshInputsFromPost()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text(viewModel.editorPost.displayFileName)
                }
                .sheet(isPresented: $showingAIWritingSheet) {
                    aiWritingSheet
                }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            workspaceBar

            NookDivider()

            if viewModel.posts.isEmpty {
                NookEmptyState(
                    icon: .design,
                    title: "还没有文章",
                    subtitle: "在右侧创建你的第一篇内容"
                )
            } else {
                List {
                    OutlineGroup(sidebarRoots, children: \.childNodes) { node in
                        sidebarRow(for: node)
                            .contextMenu {
                                if let post = node.post {
                                    Button("删除", role: .destructive) {
                                        selectAndDelete(post)
                                    }
                                }
                            }
                    }
                }
            }
        }
    }

    private var workspaceBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedWorkspacePickerCode) {
                ForEach(viewModel.languageWorkspaces) { workspace in
                    Text(workspace.title.isEmpty ? workspace.code : workspace.title)
                        .tag(workspace.code)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            Button {
                applyInputsToPost()
                viewModel.saveCurrentPost()
                viewModel.switchContentWorkspace(to: selectedWorkspacePickerCode)
                refreshInputsFromPost()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .disabled(selectedWorkspacePickerCode.isEmpty || selectedWorkspacePickerCode == viewModel.selectedWorkspaceCode)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sidebarRow(for node: WritingSidebarNode) -> some View {
        Group {
            if let post = node.post {
                Button {
                    openPost(post)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: post.usesPageBundle ? "folder.fill" : "doc.text")
                            .font(.system(size: 12))
                            .foregroundColor(post.id == viewModel.selectedPostID ? .aiPrimary : .aiTextMuted)
                            .frame(width: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.title.isEmpty ? post.displayFileName : post.title)
                                .font(.custom("Nunito-SemiBold", size: 13))
                                .foregroundColor(post.id == viewModel.selectedPostID ? .aiTextHeader : .aiTextBody)
                                .lineLimit(1)
                            Text(relativeDisplayPath(for: post))
                                .font(.custom("Nunito-Regular", size: 10))
                                .foregroundColor(.aiTextMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(post.id == viewModel.selectedPostID ? Color.aiPrimary.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.aiTextMuted)
                    Text(node.name)
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundColor(.aiTextSecondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 3)
            }
        }
    }

    // MARK: - Detail

    private var detailContent: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 1100

            ScrollView {
                VStack(spacing: 12) {
                    newContentCard

                    NookWaveDivider()

                    if compact {
                        VStack(spacing: 12) {
                            editorArea
                            inspectorPanel
                        }
                    } else {
                        HStack(alignment: .top, spacing: 12) {
                            editorArea
                                .frame(minWidth: 600, maxWidth: .infinity, alignment: .topLeading)

                            inspectorPanel
                                .frame(width: min(max(proxy.size.width * 0.28, 300), 380), alignment: .topLeading)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - New Content Card

    private var newContentCard: some View {
        NookCard(color: .appBlue) {
            VStack(alignment: .leading, spacing: 10) {
                Text("新建内容")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(.aiTextHeader)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        newContentFields
                        newContentActions
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        newContentFields
                        newContentActions
                    }
                }
            }
        }
    }

    private var newContentFields: some View {
        Group {
            NookInput("内容标题", text: $viewModel.newPostTitle)

            NookInput("文件名", text: $viewModel.newPostFileName)

            Picker("", selection: $viewModel.newPostCreationMode) {
                ForEach(ContentCreationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var newContentActions: some View {
        HStack(spacing: 8) {
            NookButton(.primary, size: .small, label: "创建") {
                viewModel.createPostFromForm()
                editorSelection = NSRange(location: 0, length: 0)
                refreshInputsFromPost()
            }
            Spacer()
        }
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        NookCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("正文编辑")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)
                    Spacer()

                    Picker("", selection: $editorImplementation) {
                        ForEach(EditorImplementation.allCases) { impl in
                            Text(impl.rawValue).tag(impl)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                if editorImplementation == .vditor {
                    VditorEditorView(
                        text: $viewModel.editorPost.body,
                        statusMessage: $viewModel.statusText,
                        bridge: vditorBridge,
                        onRequestImageImport: importImageFromPanel
                    )
                    .frame(minHeight: 480)
                    .background(Color.aiBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    MarkdownTextEditor(
                        text: $viewModel.editorPost.body,
                        selection: $editorSelection,
                        onMenuAction: applyMarkdownAction
                    )
                    .frame(minHeight: 480)
                    .background(Color.aiBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                NookDivider()

                HStack(spacing: 10) {
                    NookButton(.primary, size: .small, label: "保存") {
                        applyInputsToPost()
                        viewModel.saveCurrentPost()
                    }

                    NookButton(.default, size: .small, label: "保存并构建") {
                        applyInputsToPost()
                        viewModel.saveCurrentPost()
                        viewModel.runBuild()
                    }

                    NookButton(.default, size: .small, label: "AI 写作") {
                        openAIWritingSheet()
                    }

                    NookButton(.default, size: .small, label: "插入图片") {
                        importImageFromPanel()
                    }

                    Spacer()

                    NookButton(.danger, size: .small, label: "删除") {
                        showDeleteConfirm = true
                    }

                    Text(viewModel.editorPost.fileURL.lastPathComponent)
                        .font(.custom("Nunito-Regular", size: 11))
                        .foregroundColor(.aiTextMuted)
                }
            }
        }
    }

    // MARK: - Inspector

    private var inspectorPanel: some View {
        NookCard(color: .appYellow) {
            VStack(alignment: .leading, spacing: 12) {
                Text("文档属性")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(.aiTextHeader)

                NookDivider()

                VStack(alignment: .leading, spacing: 10) {
                    inspectorField("标题") {
                        TextField("标题", text: $viewModel.editorPost.title)
                            .textFieldStyle(.roundedBorder)
                    }

                    inspectorField("日期") {
                        DatePicker("", selection: $viewModel.editorPost.date, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }

                    inspectorField("摘要") {
                        TextField("摘要（可选）", text: $viewModel.editorPost.summary, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }

                    inspectorField("标签") {
                        tagsEditor
                    }

                    inspectorField("分类") {
                        categoriesEditor
                    }

                    inspectorField("Slug") {
                        NookInput("短链接", text: $viewModel.editorPost.slug)
                    }

                    Toggle("草稿", isOn: $viewModel.editorPost.draft)
                        .toggleStyle(.switch)
                        .font(.custom("Nunito-Medium", size: 13))
                }
            }
        }
    }

    private func inspectorField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
            content()
        }
    }

    private var tagsEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("标签，逗号分隔", text: $tagsInput)
                .textFieldStyle(.roundedBorder)

            let suggestions = taxonomySuggestions(for: "tags")
            if !suggestions.isEmpty {
                FlowWrap(spacing: 6) {
                    ForEach(suggestions.prefix(12), id: \.self) { term in
                        let isSelected = splitCSV(tagsInput).contains(term)
                        Button {
                            toggleTaxonomyTerm(term, key: "tags", input: $tagsInput)
                        } label: {
                            NookTag(term, color: isSelected ? .appBlue : .nookDefault)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var categoriesEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("分类，逗号分隔", text: $categoriesInput)
                .textFieldStyle(.roundedBorder)

            let suggestions = taxonomySuggestions(for: "categories")
            if !suggestions.isEmpty {
                FlowWrap(spacing: 6) {
                    ForEach(suggestions.prefix(8), id: \.self) { term in
                        let isSelected = splitCSV(categoriesInput).contains(term)
                        Button {
                            toggleTaxonomyTerm(term, key: "categories", input: $categoriesInput)
                        } label: {
                            NookTag(term, color: isSelected ? .appGreen : .nookDefault)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - AI Writing Sheet

    private var aiWritingSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 写作")
                        .font(.custom("Nunito-Bold", size: 18))
                        .foregroundColor(.aiTextHeader)
                    Text("对话保存在 NookDeskStorage/ai-writing-history.json")
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextSecondary)
                }
                Spacer()
                NookButton(.default, size: .small, label: "复制全部") { copyAIWritingTranscript() }
                    .disabled(viewModel.aiWritingMessages.isEmpty)
                NookButton(.default, size: .small, label: "清空") { viewModel.clearAIWritingHistory() }
                NookButton(.default, size: .small, label: "关闭") {
                    if !viewModel.isAIFormatting { showingAIWritingSheet = false }
                }
                .disabled(viewModel.isAIFormatting)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if viewModel.aiWritingMessages.isEmpty {
                            Text("还没有对话历史。")
                                .font(.custom("Nunito-Regular", size: 13))
                                .foregroundColor(.aiTextMuted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                        } else {
                            ForEach(viewModel.aiWritingMessages) { message in
                                aiMessageBubble(message).id(message.id)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 200, maxHeight: 280)
                .padding(8)
                .background(Color.aiBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onAppear {
                    if let last = viewModel.aiWritingMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.aiWritingMessages.count) { _ in
                    if let last = viewModel.aiWritingMessages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            TextEditor(text: $aiWritingSourceText)
                .font(.body.monospaced())
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.aiBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if viewModel.isAIFormatting {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: viewModel.aiFormattingProgress)
                        .progressViewStyle(.linear)
                    Text(viewModel.aiFormattingStatus)
                        .font(.custom("Nunito-Regular", size: 12))
                        .foregroundColor(.aiTextSecondary)
                }
            }

            HStack {
                NookButton(.default, size: .small, label: "粘贴剪贴板") {
                    if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
                        aiWritingSourceText = text
                    }
                }
                Spacer()
                NookButton(.primary, size: .medium, label: "发送并生成") {
                    runAIWriting()
                }
                .disabled(aiWritingSourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isAIFormatting)
            }
        }
        .padding(16)
        .frame(minWidth: 780, minHeight: 520)
    }

    private func aiMessageBubble(_ message: AIWritingMessage) -> some View {
        let isUser = message.role == .user
        let isSystem = message.role == .system
        return HStack(alignment: .top, spacing: 10) {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(message.role.displayName)
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundColor(.aiTextHeader)
                    Text(aiTimestamp(message.createdAt))
                        .font(.custom("Nunito-Regular", size: 10))
                        .foregroundColor(.aiTextMuted)
                }
                Text(message.content)
                    .font(.custom("Nunito-Medium", size: 13))
                    .foregroundColor(.aiTextBody)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    NookButton(.default, size: .small, label: "复制") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.content, forType: .string)
                    }
                    if message.role == .assistant {
                        NookButton(.primary, size: .small, label: "追加到正文") {
                            insertSnippetIntoEditor(message.content + "\n")
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isUser ? Color.aiPrimary.opacity(0.1) : (isSystem ? Color.aiWarning.opacity(0.1) : Color.aiContent))
            )
            if !isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Helpers

    private var sidebarRoots: [WritingSidebarNode] {
        WritingSidebarNode.buildTree(posts: viewModel.posts, relativePath: relativeDisplayPath(for:))
    }

    private func relativeDisplayPath(for post: BlogPost) -> String {
        let root = viewModel.project.contentURL.standardizedFileURL.path
        let target: String
        if post.usesPageBundle, let bundleRoot = post.bundleRootURL?.standardizedFileURL.path {
            target = bundleRoot
        } else {
            target = post.fileURL.standardizedFileURL.path
        }
        guard target.hasPrefix(root) else { return post.fileURL.lastPathComponent }
        var relative = String(target.dropFirst(root.count))
        if relative.hasPrefix("/") { relative.removeFirst() }
        return relative.isEmpty ? "." : relative
    }

    private func openPost(_ post: BlogPost) {
        viewModel.selectedPostID = post.id
        viewModel.loadSelectedPost()
        viewModel.cancelLivePreviewRefresh()
        editorSelection = NSRange(location: 0, length: 0)
        refreshInputsFromPost()
    }

    private func selectAndDelete(_ post: BlogPost) {
        viewModel.selectedPostID = post.id
        viewModel.loadSelectedPost()
        viewModel.deleteCurrentPost()
        editorSelection = NSRange(location: 0, length: 0)
        refreshInputsFromPost()
    }

    private func refreshInputsFromPost() {
        tagsInput = viewModel.editorPost.tags.joined(separator: ", ")
        categoriesInput = viewModel.editorPost.categories.joined(separator: ", ")
        selectedWorkspacePickerCode = viewModel.selectedWorkspaceCode
    }

    private func applyInputsToPost() {
        viewModel.editorPost.tags = normalizeTerms(splitCSV(tagsInput))
        viewModel.editorPost.categories = normalizeTerms(splitCSV(categoriesInput))
    }

    private func splitCSV(_ input: String) -> [String] {
        input
            .replacingOccurrences(of: "，", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizeTerms(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else { return nil }
            seen.insert(normalized)
            return normalized
        }
    }

    private func taxonomySuggestions(for key: String) -> [String] {
        var terms = Set<String>()
        for post in viewModel.posts {
            let candidates: [String]
            switch key {
            case "tags":       candidates = post.tags
            case "categories": candidates = post.categories
            default:           candidates = []
            }
            for term in candidates {
                let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty { terms.insert(normalized) }
            }
        }
        return terms.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private func toggleTaxonomyTerm(_ term: String, key: String, input: Binding<String>) {
        var values = splitCSV(input.wrappedValue)
        if let index = values.firstIndex(of: term) {
            values.remove(at: index)
        } else {
            values.append(term)
        }
        input.wrappedValue = values.joined(separator: ", ")
    }

    private func applyMarkdownAction(_ action: MarkdownAction) {
        let result = MarkdownEditing.apply(action: action, to: viewModel.editorPost.body, selection: editorSelection)
        viewModel.editorPost.body = result.text
        editorSelection = result.selection
    }

    private func importImageFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .heic, .tiff, .webP]
        panel.prompt = "选择"
        guard panel.runModal() == .OK, let imageURL = panel.url else { return }

        if editorImplementation == .native {
            let next = viewModel.importImageIntoPost(from: imageURL, altText: imageAltText, insertionRange: nil)
            editorSelection = next
        } else {
            do {
                vditorBridge.rememberSelection()
                let snippet = try viewModel.makeImportedImageMarkdown(from: imageURL, altText: imageAltText)
                vditorBridge.insertMarkdown(snippet)
                vditorBridge.focus()
            } catch {
                viewModel.statusText = error.localizedDescription
            }
        }
    }

    private func insertSnippetIntoEditor(_ snippet: String) {
        if editorImplementation == .vditor {
            vditorBridge.insertMarkdown(snippet)
            vditorBridge.focus()
            return
        }
        let insertionPoint = max(0, editorSelection.location + editorSelection.length)
        let next = viewModel.insertPostSnippet(snippet, at: NSRange(location: insertionPoint, length: 0))
        editorSelection = next
    }

    private func openAIWritingSheet() {
        if editorImplementation == .vditor { vditorBridge.rememberSelection() }
        viewModel.loadAIWritingHistory()
        showingAIWritingSheet = true
    }

    private func runAIWriting() {
        let source = aiWritingSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        viewModel.appendAIWritingMessage(role: .user, content: source)
        aiWritingSourceText = ""
        viewModel.generateWritingWithAI(
            sourceInput: source,
            onComplete: { generated in
                let reply = generated.trimmingCharacters(in: .whitespacesAndNewlines)
                if reply.isEmpty {
                    viewModel.appendAIWritingMessage(role: .system, content: "AI 返回为空。")
                } else {
                    viewModel.appendAIWritingMessage(role: .assistant, content: reply)
                }
            },
            onFailure: { errorText in
                viewModel.appendAIWritingMessage(role: .system, content: errorText)
            }
        )
    }

    private func copyAIWritingTranscript() {
        let text = viewModel.aiWritingTranscriptText()
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        viewModel.statusText = "已复制全部 AI 对话。"
    }

    private func aiTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private var editorColumnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { NavigationSplitViewVisibility(storedValue: columnVisibilityRawValue) },
            set: { columnVisibilityRawValue = $0.storageKey }
        )
    }
}

// MARK: - Sidebar Node (copied from EditorView for self-containment)

private struct WritingSidebarNode: Identifiable {
    let id: String
    let name: String
    let post: BlogPost?
    let children: [WritingSidebarNode]

    var childNodes: [WritingSidebarNode]? {
        children.isEmpty ? nil : children
    }

    static func buildTree(posts: [BlogPost], relativePath: (BlogPost) -> String) -> [WritingSidebarNode] {
        final class Box {
            let id: String
            let name: String
            var post: BlogPost?
            var children: [String: Box] = [:]
            init(id: String, name: String) { self.id = id; self.name = name }
        }

        let root = Box(id: "root", name: "root")
        for post in posts {
            let rawRelative = relativePath(post)
            let components = rawRelative.split(separator: "/").map(String.init)
            let pathComponents = post.usesPageBundle ? components : (components.isEmpty ? [post.displayFileName] : components)
            var current = root
            for (index, component) in pathComponents.enumerated() {
                let isLast = index == pathComponents.count - 1
                let key = current.id + "/" + component
                let node = current.children[component] ?? Box(id: key, name: component)
                current.children[component] = node
                if isLast { node.post = post }
                current = node
            }
        }

        func freeze(_ box: Box) -> [WritingSidebarNode] {
            box.children.values.map { child in
                WritingSidebarNode(id: child.id, name: child.name, post: child.post, children: freeze(child))
            }
            .sorted { left, right in
                if left.children.isEmpty != right.children.isEmpty {
                    return !left.children.isEmpty && right.children.isEmpty
                }
                let leftName = left.post?.title.isEmpty == false ? left.post!.title : left.name
                let rightName = right.post?.title.isEmpty == false ? right.post!.title : right.name
                return leftName.localizedStandardCompare(rightName) == .orderedAscending
            }
        }

        return freeze(root)
    }
}

// MARK: - Editor Implementation Enum

private enum EditorImplementation: String, CaseIterable, Identifiable {
    case vditor = "Vditor"
    case native = "兼容"

    var id: String { rawValue }
}

// MARK: - FlowWrap (local copy)

private struct FlowWrap<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 60), spacing: spacing)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
            content()
        }
    }
}

// MARK: - NavigationSplitViewVisibility extension

private extension NavigationSplitViewVisibility {
    init(storedValue: String) {
        switch storedValue {
        case Self.automatic.storageKey:   self = .automatic
        case Self.doubleColumn.storageKey: self = .doubleColumn
        case Self.detailOnly.storageKey:   self = .detailOnly
        default:                           self = .all
        }
    }

    var storageKey: String {
        switch self {
        case .automatic:   return "automatic"
        case .all:         return "all"
        case .doubleColumn: return "doubleColumn"
        case .detailOnly:  return "detailOnly"
        default:           return "all"
        }
    }
}
