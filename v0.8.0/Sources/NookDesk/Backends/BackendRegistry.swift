import Foundation

final class BackendRegistry: @unchecked Sendable {
    static let shared = BackendRegistry()

    let backends: [SSGBuildBackend] = [
        AstroBackend()
    ]

    private init() {}

    func detectBackend(in directory: URL) -> SSGBuildBackend? {
        backends.first { $0.detectProject(in: directory) }
    }

    func backend(named name: String) -> SSGBuildBackend? {
        backends.first { $0.displayName == name }
    }
}
