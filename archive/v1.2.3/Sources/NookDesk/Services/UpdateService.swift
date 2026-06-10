import AppKit
import Foundation

struct UpdateInfo {
    let version: String
    let downloadURL: String
    let releaseNotes: String
    let publishedAt: String
}

enum UpdateServiceError: LocalizedError {
    case invalidURL
    case networkError(String)
    case decodingError
    case noDownloadAsset

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无法构建 GitHub API 请求地址。"
        case let .networkError(msg):
            return "网络请求失败：\(msg)"
        case .decodingError:
            return "无法解析 GitHub 返回的 release 数据。"
        case .noDownloadAsset:
            return "该 release 未包含 .dmg 下载文件。"
        }
    }
}

final class UpdateService: @unchecked Sendable {
    private let apiURL = "https://api.github.com/repos/sexyfeifan/NookDesk/releases/latest"
    
    // 其他用户 fork 后可修改此地址指向自己的仓库
    // 或在设置中配置更新源

    func checkForUpdates(currentVersion: String) async throws -> UpdateInfo? {
        guard let url = URL(string: apiURL) else {
            throw UpdateServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NookDesk/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UpdateServiceError.networkError(error.localizedDescription)
        }

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard 200..<300 ~= statusCode else {
            throw UpdateServiceError.networkError("HTTP \(statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            throw UpdateServiceError.decodingError
        }

        let remoteVersion = normalizeVersion(tagName)
        guard isNewerVersion(remoteVersion, than: currentVersion) else {
            return nil
        }

        let body = json["body"] as? String ?? ""
        let publishedAt = json["published_at"] as? String ?? ""

        var downloadURL = ""
        if let assets = json["assets"] as? [[String: Any]] {
            for asset in assets {
                if let name = asset["name"] as? String, name.hasSuffix(".dmg"),
                   let browserURL = asset["browser_download_url"] as? String {
                    downloadURL = browserURL
                    break
                }
            }
        }

        return UpdateInfo(
            version: remoteVersion,
            downloadURL: downloadURL,
            releaseNotes: body,
            publishedAt: publishedAt
        )
    }

    func downloadAndInstall(update: UpdateInfo) async throws {
        guard !update.downloadURL.isEmpty else {
            throw UpdateServiceError.noDownloadAsset
        }

        guard let url = URL(string: update.downloadURL) else {
            throw UpdateServiceError.invalidURL
        }

        let (tempURL, response) = try await URLSession.shared.download(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard 200..<300 ~= statusCode else {
            throw UpdateServiceError.networkError("HTTP \(statusCode)")
        }

        let fileName = url.lastPathComponent.isEmpty ? "NookDesk-\(update.version).dmg" : url.lastPathComponent
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destination = downloadsDir.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)

        await NSWorkspace.shared.open(destination)
    }

    private func normalizeVersion(_ tag: String) -> String {
        var v = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("v") || v.hasPrefix("V") {
            v = String(v.dropFirst())
        }
        return v
    }

    func isNewerVersion(_ remote: String, than current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(remoteParts.count, currentParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }
}
