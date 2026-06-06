import Foundation

enum AppVersion {
    static let codeVersion = "1.1.3"

    static var current: String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.isEmpty {
            return bundleVersion
        }
        return codeVersion
    }
}
