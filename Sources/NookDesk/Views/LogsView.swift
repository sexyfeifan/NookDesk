import SwiftUI

struct LogsView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedCategory: String = "全部"
    @State private var showClearConfirm = false

    private let categories = ["全部", "写作", "发布", "设置", "系统"]

    private var filteredLogs: [LogEntry] {
        if selectedCategory == "全部" {
            return viewModel.globalLogs
        }
        return viewModel.globalLogs.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                NookIcon.chat.image
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.aiPrimary)
                Text("运行日志")
                    .font(.custom("Nunito-Bold", size: 18))
                    .foregroundColor(.aiTextHeader)

                Spacer()

                NookButton(.danger, size: .small, label: "清除日志") {
                    showClearConfirm = true
                }
                .disabled(viewModel.globalLogs.isEmpty)
                .alert("确认清除", isPresented: $showClearConfirm) {
                    Button("取消", role: .cancel) {}
                    Button("清除", role: .destructive) { viewModel.globalLogs.removeAll() }
                } message: {
                    Text("确定要清除所有日志吗？此操作不可撤销。")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            NookDivider()

            HStack(spacing: 6) {
                ForEach(categories, id: \.self) { cat in
                    NookButton(selectedCategory == cat ? .primary : .default, size: .small, label: cat) {
                        selectedCategory = cat
                    }
                }
                Spacer()
                Text("共 \(filteredLogs.count) 条")
                    .font(.custom("Nunito-Regular", size: 11))
                    .foregroundColor(.aiTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            NookDivider()

            if filteredLogs.isEmpty {
                NookEmptyState(
                    icon: .chat,
                    title: "暂无日志",
                    subtitle: "执行操作后，日志将显示在这里"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredLogs) { entry in
                                logRow(entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: viewModel.globalLogs.count) { _ in
                        if let first = viewModel.globalLogs.first {
                            withAnimation {
                                proxy.scrollTo(first.id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.aiBackground)
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.success ? "✅" : "❌")
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.custom("Nunito-Regular", size: 11))
                        .foregroundColor(.aiTextMuted)
                    NookTag(entry.category, color: categoryColor(entry.category))
                    Text(entry.action)
                        .font(.custom("Nunito-SemiBold", size: 12))
                        .foregroundColor(.aiTextHeader)
                }
                Text(entry.detail)
                    .font(.custom("Nunito-Regular", size: 12))
                    .foregroundColor(.aiTextBody)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(entry.success ? Color.clear : Color.aiError.opacity(0.06))
        )
    }

    private func categoryColor(_ category: String) -> NookColor {
        switch category {
        case "写作": return .appBlue
        case "发布": return .appGreen
        case "设置": return .appOrange
        case "系统": return .purple
        default:     return .nookDefault
        }
    }
}
