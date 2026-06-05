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

    private let tsPostService = TypeScriptPostService()
    @State private var tsPosts: [TypeScriptPostService.TSPPost] = []
    @State private var selectedTSPostID: String?
    @State private var editingTSPost: TypeScriptPostService.TSPPost?
    @State private var tsStatusMessage = ""
    @State private var showTSDeleteConfirm = false
    @State private var newTSTitle = ""

    private var isViteBackend: Bool {
        viewModel.project.backendName.contains("Vite")
    }

    var body: some View {
        if isViteBackend {
            tsWritingBody
        } else {
            hugoWritingBody
        }
    }

    private var tsWritingBody: some View {
        NavigationSplitView {
            tsSidebarContent
                .navigationTitle("文章")
                .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 340)
        } detail: {
            tsDetailContent
                .onAppear { loadTSPosts() }
                .alert("确认删除？", isPresented: $showTSDeleteConfirm) {
                    Button("删除", role: .destructive) { deleteSelectedTSPost() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text(editingTSPost?.title ?? "")
                }
                .sheet(isPresented: $showingAIWritingSheet) {
                    aiWritingSheet
                }
        }
    }

    private var hugoWritingBody: some View {
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

    // MARK: - TypeScript Post Sidebar

    private var tsSidebarContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("文章列表")
                    .font(.custom("Nunito-Bold", size: 13))
                    .foregroundColor(.aiTextSecondary)
                Spacer()
                NookButton(.primary, size: .small, label: "+ 新文章") {
                    let newPost = tsPostService.makeNewPost(title: "未命名文章")
                    do {
                        tsPosts = try tsPostService.addPost(newPost, to: viewModel.project)
                        selectedTSPostID = newPost.id
                        editingTSPost = newPost
                        tsStatusMessage = "已创建新文章。"
                    } catch {
                        tsStatusMessage = "创建失败：\(error.localizedDescription)"
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            HStack(spacing: 6) {
                NookButton(.default, size: .small, label: "读取本地") {
                    loadTSPosts()
                }
                NookButton(.default, size: .small, label: "从 GitHub 拉取") {
                    Task {
                        do {
                            try viewModel.syncRemoteForPosts()
                            loadTSPosts()
                            tsStatusMessage = "已拉取最新代码并刷新文章列表。"
                        } catch {
                            tsStatusMessage = "拉取失败：\(error.localizedDescription)"
                        }
                    }
                }
                NookButton(.default, size: .small, label: "从 Git 恢复") {
                    do {
                        tsPosts = try tsPostService.restoreFromGit(project: viewModel.project)
                        if let first = tsPosts.first {
                            selectedTSPostID = first.id
                            editingTSPost = first
                        }
                        tsStatusMessage = "已从 Git 恢复 \(tsPosts.count) 篇文章。"
                    } catch {
                        tsStatusMessage = "恢复失败：\(error.localizedDescription)"
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            NookDivider()

            if tsPosts.isEmpty {
                NookEmptyState(
                    icon: .design,
                    title: "还没有文章",
                    subtitle: "点击上方按钮创建第一篇文章"
                )
            } else {
                List(tsPosts, selection: $selectedTSPostID) { post in
                    Button {
                        selectedTSPostID = post.id
                        editingTSPost = post
                    } label: {
                        HStack(spacing: 8) {
                            Text(post.cover.isEmpty ? "📄" : post.cover)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.title.isEmpty ? "未命名" : post.title)
                                    .font(.custom("Nunito-SemiBold", size: 13))
                                    .foregroundColor(post.id == selectedTSPostID ? .aiTextHeader : .aiTextBody)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(post.date)
                                        .font(.custom("Nunito-Regular", size: 10))
                                    if !post.tag.isEmpty {
                                        Text("#\(post.tag)")
                                            .font(.custom("Nunito-Regular", size: 10))
                                    }
                                }
                                .foregroundColor(.aiTextMuted)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(post.id == selectedTSPostID ? Color.aiPrimary.opacity(0.12) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .tag(post.id)
                }
            }

            Spacer()

            if !tsStatusMessage.isEmpty {
                Text(tsStatusMessage)
                    .font(.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.aiTextMuted)
                    .padding(8)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - TypeScript Post Detail

    private var tsDetailContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                tsNewPostCard
                NookWaveDivider()

                if let post = editingTSPost {
                    GeometryReader { proxy in
                        let compact = proxy.size.width < 1100
                        if compact {
                            VStack(spacing: 12) {
                                tsEditorArea(post: post)
                                tsInspector(post: post)
                            }
                        } else {
                            HStack(alignment: .top, spacing: 12) {
                                tsEditorArea(post: post)
                                    .frame(minWidth: 600, maxWidth: .infinity, alignment: .topLeading)
                                tsInspector(post: post)
                                    .frame(width: min(max(proxy.size.width * 0.3, 320), 400), alignment: .topLeading)
                            }
                        }
                    }
                    .frame(minHeight: 600)
                } else {
                    NookEmptyState(
                        icon: .design,
                        title: "选择一篇文章",
                        subtitle: "从左侧列表选择或创建新文章"
                    )
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var tsNewPostCard: some View {
        NookCard(color: .appBlue) {
            VStack(alignment: .leading, spacing: 10) {
                Text("新建文章")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(.aiTextHeader)
                HStack(spacing: 10) {
                    NookInput("文章标题", text: $newTSTitle)
                    NookButton(.primary, size: .small, label: "创建") {
                        let title = newTSTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let newPost = tsPostService.makeNewPost(title: title.isEmpty ? "未命名文章" : title)
                        do {
                            tsPosts = try tsPostService.addPost(newPost, to: viewModel.project)
                            selectedTSPostID = newPost.id
                            editingTSPost = newPost
                            newTSTitle = ""
                            tsStatusMessage = "已创建：\(newPost.title)"
                        } catch {
                            tsStatusMessage = "创建失败：\(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }

    private func tsEditorArea(post: TypeScriptPostService.TSPPost) -> some View {
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
                    .frame(width: 240)
                }

                if editorImplementation == .vditor {
                    VditorEditorView(
                        text: bindingTSBody(),
                        statusMessage: $tsStatusMessage,
                        bridge: vditorBridge,
                        onRequestImageImport: importImageFromPanel
                    )
                    .frame(minHeight: 480)
                    .background(Color.aiBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    TextEditor(text: bindingTSBody())
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 480)
                        .padding(8)
                        .background(Color.aiBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                NookDivider()

                HStack(spacing: 10) {
                    NookButton(.primary, size: .small, label: "保存") {
                        saveSelectedTSPost()
                    }
                    NookButton(.default, size: .small, label: "保存并构建") {
                        saveSelectedTSPost()
                        ensureNodeModulesThenBuild()
                    }
                    NookButton(.default, size: .small, label: "AI 写作") {
                        if editorImplementation == .vditor { vditorBridge.rememberSelection() }
                        viewModel.loadAIWritingHistory()
                        showingAIWritingSheet = true
                    }
                    Spacer()
                    NookButton(.danger, size: .small, label: "删除") {
                        showTSDeleteConfirm = true
                    }
                    Text("posts.ts")
                        .font(.custom("Nunito-Regular", size: 11))
                        .foregroundColor(.aiTextMuted)
                }
            }
        }
    }

    private func tsInspector(post: TypeScriptPostService.TSPPost) -> some View {
        NookCard(color: .appYellow) {
            VStack(alignment: .leading, spacing: 12) {
                Text("文章属性")
                    .font(.custom("Nunito-Bold", size: 16))
                    .foregroundColor(.aiTextHeader)
                NookDivider()

                VStack(alignment: .leading, spacing: 10) {
                    tsInspectorField("标题") {
                        TextField("标题", text: bindingTSTitle())
                            .textFieldStyle(.roundedBorder)
                    }
                    tsInspectorField("摘要") {
                        TextField("摘要", text: bindingTSExcerpt(), axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    }
                    tsInspectorField("日期") {
                        TextField("yyyy-MM-dd", text: bindingTSDate())
                            .textFieldStyle(.roundedBorder)
                    }
                    tsInspectorField("标签") {
                        TextField("标签", text: bindingTSTag())
                            .textFieldStyle(.roundedBorder)
                    }
                    tsInspectorField("颜色") {
                        Picker("", selection: bindingTSColor()) {
                            ForEach(NookColor.allCases.filter { $0 != .nookDefault }) { nc in
                                HStack(spacing: 6) {
                                    Circle().fill(nc.color).frame(width: 12, height: 12)
                                    Text(nc.blogValue)
                                }
                                .tag(nc.blogValue)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                    tsInspectorField("阅读时间") {
                        TextField("如: 5 分钟", text: bindingTSReadTime())
                            .textFieldStyle(.roundedBorder)
                    }
                    tsInspectorField("封面图标") {
                        TextField("emoji", text: bindingTSCover())
                            .textFieldStyle(.roundedBorder)
                    }
                }

                NookDivider()
                tsSectionsEditor
                NookDivider()
                tsTakeawaysEditor
            }
        }
    }

    private var tsSectionsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("章节")
                    .font(.custom("Nunito-SemiBold", size: 13))
                    .foregroundColor(.aiTextHeader)
                Spacer()
                NookButton(.default, size: .small, label: "+ 章节") {
                    guard var post = editingTSPost else { return }
                    post.sections.append(TypeScriptPostService.TSPSection(heading: "新章节", paragraphs: [""]))
                    editingTSPost = post
                }
            }

            if let post = editingTSPost {
                ForEach(Array(post.sections.enumerated()), id: \.offset) { idx, section in
                    NookCard(color: .appTeal) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("章节标题", text: Binding(
                                    get: { section.heading },
                                    set: { newHeading in
                                        guard var p = editingTSPost else { return }
                                        p.sections[idx].heading = newHeading
                                        editingTSPost = p
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.custom("Nunito-SemiBold", size: 13))

                                Spacer()
                                Button {
                                    guard var p = editingTSPost else { return }
                                    p.sections.remove(at: idx)
                                    editingTSPost = p
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.aiError)
                                }
                                .buttonStyle(.plain)
                            }

                            ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { pIdx, para in
                                HStack(alignment: .top) {
                                    TextField("段落", text: Binding(
                                        get: { para },
                                        set: { newVal in
                                            guard var p = editingTSPost else { return }
                                            p.sections[idx].paragraphs[pIdx] = newVal
                                            editingTSPost = p
                                        }
                                    ), axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...6)
                                    .font(.custom("Nunito-Regular", size: 12))

                                    Button {
                                        guard var p = editingTSPost else { return }
                                        p.sections[idx].paragraphs.remove(at: pIdx)
                                        editingTSPost = p
                                    } label: {
                                        Image(systemName: "minus.circle")
                                            .font(.system(size: 11))
                                            .foregroundColor(.aiError)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            NookButton(.default, size: .small, label: "+ 段落") {
                                guard var p = editingTSPost else { return }
                                p.sections[idx].paragraphs.append("")
                                editingTSPost = p
                            }
                        }
                    }
                }
            }
        }
    }

    private var tsTakeawaysEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("要点")
                    .font(.custom("Nunito-SemiBold", size: 13))
                    .foregroundColor(.aiTextHeader)
                Spacer()
                NookButton(.default, size: .small, label: "+ 要点") {
                    guard var post = editingTSPost else { return }
                    post.takeaways.append("")
                    editingTSPost = post
                }
            }

            if let post = editingTSPost {
                ForEach(Array(post.takeaways.enumerated()), id: \.offset) { idx, takeaway in
                    HStack {
                        TextField("要点 \(idx + 1)", text: Binding(
                            get: { takeaway },
                            set: { newVal in
                                guard var p = editingTSPost else { return }
                                p.takeaways[idx] = newVal
                                editingTSPost = p
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.custom("Nunito-Regular", size: 12))

                        Button {
                            guard var p = editingTSPost else { return }
                            p.takeaways.remove(at: idx)
                            editingTSPost = p
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.aiError)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func tsInspectorField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Nunito-SemiBold", size: 12))
                .foregroundColor(.aiTextSecondary)
            content()
        }
    }

    // MARK: - TS Bindings

    private func bindingTSBody() -> Binding<String> {
        Binding(
            get: { editingTSPost?.body ?? "" },
            set: { newVal in editingTSPost?.body = newVal }
        )
    }

    private func bindingTSTitle() -> Binding<String> {
        Binding(
            get: { editingTSPost?.title ?? "" },
            set: { newVal in editingTSPost?.title = newVal }
        )
    }

    private func bindingTSExcerpt() -> Binding<String> {
        Binding(
            get: { editingTSPost?.excerpt ?? "" },
            set: { newVal in editingTSPost?.excerpt = newVal }
        )
    }

    private func bindingTSDate() -> Binding<String> {
        Binding(
            get: { editingTSPost?.date ?? "" },
            set: { newVal in editingTSPost?.date = newVal }
        )
    }

    private func bindingTSTag() -> Binding<String> {
        Binding(
            get: { editingTSPost?.tag ?? "" },
            set: { newVal in editingTSPost?.tag = newVal }
        )
    }

    private func bindingTSColor() -> Binding<String> {
        Binding(
            get: { editingTSPost?.color ?? "app-blue" },
            set: { newVal in editingTSPost?.color = newVal }
        )
    }

    private func bindingTSReadTime() -> Binding<String> {
        Binding(
            get: { editingTSPost?.readTime ?? "" },
            set: { newVal in editingTSPost?.readTime = newVal }
        )
    }

    private func bindingTSCover() -> Binding<String> {
        Binding(
            get: { editingTSPost?.cover ?? "" },
            set: { newVal in editingTSPost?.cover = newVal }
        )
    }

    // MARK: - TS Actions

    private func loadTSPosts() {
        do {
            tsPosts = try tsPostService.loadPosts(from: viewModel.project)
            if let first = tsPosts.first, selectedTSPostID == nil {
                selectedTSPostID = first.id
                editingTSPost = first
            }
            tsStatusMessage = "已加载 \(tsPosts.count) 篇文章。"
        } catch {
            tsPosts = []
            tsStatusMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func saveSelectedTSPost() {
        guard let post = editingTSPost else { return }
        do {
            tsPosts = try tsPostService.updatePost(post, in: viewModel.project)
            if let updated = tsPosts.first(where: { $0.id == post.id }) {
                editingTSPost = updated
            }
            tsStatusMessage = "已保存：\(post.title)"
        } catch {
            tsStatusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func ensureNodeModulesThenBuild() {
        let nodeModulesURL = viewModel.project.rootURL.appendingPathComponent("node_modules", isDirectory: true)
        if !FileManager.default.fileExists(atPath: nodeModulesURL.path) {
            Task {
                do {
                    let runner = ProcessRunner()
                    _ = try runner.run(command: "npm", arguments: ["install"], in: viewModel.project.rootURL)
                    tsStatusMessage = "依赖安装完成，开始构建…"
                    viewModel.runBuild()
                } catch {
                    tsStatusMessage = "npm install 失败：\(error.localizedDescription)"
                }
            }
        } else {
            viewModel.runBuild()
        }
    }

    private func deleteSelectedTSPost() {
        guard let id = editingTSPost?.id else { return }
        do {
            tsPosts = try tsPostService.deletePost(id: id, in: viewModel.project)
            editingTSPost = nil
            selectedTSPostID = tsPosts.first?.id
            if let first = tsPosts.first {
                editingTSPost = first
            }
            tsStatusMessage = "已删除文章。"
        } catch {
            tsStatusMessage = "删除失败：\(error.localizedDescription)"
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
                        Image(systemName: "doc.text")
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
                    .frame(width: 240)
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
        let target = post.fileURL.standardizedFileURL.path
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
    case native = "Markdown 模式"

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
