import Foundation

enum AppVersion {
    static let codeVersion = "0.8.3"

    static var current: String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.isEmpty {
            return bundleVersion
        }
        return codeVersion
    }
}
