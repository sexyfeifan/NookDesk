import Foundation

final class BackendRegistry: @unchecked Sendable {
    static let shared = BackendRegistry()

    // [NookDesk 修复] 注册 HugoBackend，使应用能检测和管理 Hugo 项目
    let backends: [SSGBuildBackend] = [
        AstroBackend(),
        HugoBackend()
    ]

    private init() {}

    func detectBackend(in directory: URL) -> SSGBuildBackend? {
        backends.first { $0.detectProject(in: directory) }
    }

    func backend(named name: String) -> SSGBuildBackend? {
        backends.first { $0.displayName == name }
    }
}
