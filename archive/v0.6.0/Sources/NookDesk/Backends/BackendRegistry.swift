import Foundation

final class BackendRegistry: @unchecked Sendable {
    static let shared = BackendRegistry()

    let backends: [SSGBuildBackend] = [
        HugoBackend(),
        ViteBackend()
    ]

    private init() {}

    func detectBackend(in directory: URL) -> SSGBuildBackend? {
        backends.first { $0.detectProject(in: directory) }
    }

    func backend(named name: String) -> SSGBuildBackend? {
        backends.first { $0.displayName == name }
    }
}
