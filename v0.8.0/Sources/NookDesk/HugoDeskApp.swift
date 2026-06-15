import AppKit
import SwiftUI

@main
struct NookDeskApp: App {
    @StateObject private var viewModel = AppViewModel()

    init() {
        NSApp.appearance = NSAppearance(named: .aqua)
    }

    var body: some Scene {
        WindowGroup("NookDesk 博客工作台 v\(AppVersion.current)") {
            RootView(viewModel: viewModel)
                .frame(minWidth: 1200, minHeight: 760)
                .preferredColorScheme(.light)
        }
    }
}
