import SwiftUI

@main
struct NookDeskApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("NookDesk 博客工作台") {
            RootView(viewModel: viewModel)
                .frame(minWidth: 1200, minHeight: 760)
        }
    }
}
