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

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .posts: return "doc.text.fill"
            }
        }

        var description: String {
            switch self {
            case .home: return "首页内容：个人信息、技能、统计、关于、FAQ"
            case .posts: return "文章数据：所有博客文章的 TypeScript 数据"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            pageSelector
            NookDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageContent
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
                    loadPageContent()
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
    }

    @ViewBuilder
    private var pageContent: some View {
        switch selectedPage {
        case .home:
            homePageEditor
        case .posts:
            postsPageEditor
        }
    }

    // MARK: - Home Page Editor

    private var homePageEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            NookCard(color: .appBlue) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Home.tsx 编辑器")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)

                    Text("编辑首页内容。修改后点击保存，更改将写入 src/pages/Home/Home.tsx。")
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

    // MARK: - Posts Page Editor

    private var postsPageEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            NookCard(color: .appGreen) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("posts.ts 文章管理")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.aiTextHeader)

                    Text("管理 animal-island-blog 的文章数据。文章存储在 src/pages/Home/posts.ts 中。")
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
        }
    }
}
