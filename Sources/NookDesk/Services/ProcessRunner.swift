import Foundation

struct ProcessResult {
    let command: String
    let arguments: [String]
    let workingDirectory: String
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let startedAt: Date
    let finishedAt: Date

    var commandLine: String {
        ([command] + arguments).joined(separator: " ")
    }

    var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }

    var output: String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

enum ProcessRunnerError: LocalizedError {
    case commandFailed(command: String, code: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(command, code, output):
            return "Command failed (\(code)): \(command)\n\(output)"
        }
    }
}

final class ProcessRunner {
    /// Extra PATH segments prepended before the existing environment PATH.
    /// Default includes common Unix locations; callers can override via `init(extraPATH:)`.
    var extraPATHComponents: [String]

    init(extraPATHComponents: [String]? = nil) {
        #if os(macOS)
        let defaultComponents = ["/opt/homebrew/bin", "/opt/homebrew/sbin", "/usr/local/bin"]
        #else
        let defaultComponents: [String] = []
        #endif
        self.extraPATHComponents = extraPATHComponents ?? defaultComponents
    }

    func enrichedEnvironment(cwd: URL? = nil, _ extra: [String: String] = [:]) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        var extraPaths = extraPATHComponents
        if let cwd = cwd {
            let nodeModulesBin = cwd.appendingPathComponent("node_modules/.bin").path
            extraPaths.insert(nodeModulesBin, at: 0)
        }
        let systemPaths = "/usr/bin:/bin:/usr/sbin:/sbin"
        if !extraPaths.isEmpty {
            let combined = extraPaths.joined(separator: ":") + ":" + systemPaths
            if let existing = env["PATH"] {
                env["PATH"] = "\(combined):\(existing)"
            } else {
                env["PATH"] = combined
            }
        } else {
            if let existing = env["PATH"] {
                env["PATH"] = "\(systemPaths):\(existing)"
            } else {
                env["PATH"] = systemPaths
            }
        }
        for (k, v) in extra { env[k] = v }
        return env
    }

    func run(
        command: String,
        arguments: [String],
        in cwd: URL,
        environment: [String: String] = [:]
    ) throws -> ProcessResult {
        let process = Process()
        let fm = FileManager.default
        process.currentDirectoryURL = cwd
        if !environment.isEmpty {
            process.environment = enrichedEnvironment(cwd: cwd, environment)
        } else {
            process.environment = enrichedEnvironment(cwd: cwd)
        }

        if command.contains("/") {
            process.executableURL = URL(fileURLWithPath: command)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
        }

        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let stdoutURL = tempRoot.appendingPathComponent("nookdesk-\(UUID().uuidString)-stdout.log", isDirectory: false)
        let stderrURL = tempRoot.appendingPathComponent("nookdesk-\(UUID().uuidString)-stderr.log", isDirectory: false)
        fm.createFile(atPath: stdoutURL.path, contents: Data())
        fm.createFile(atPath: stderrURL.path, contents: Data())
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        defer {
            try? stdoutHandle.close()
            try? stderrHandle.close()
            try? fm.removeItem(at: stdoutURL)
            try? fm.removeItem(at: stderrURL)
        }
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        let startedAt = Date()
        try process.run()
        process.waitUntilExit()
        try stdoutHandle.synchronize()
        try stderrHandle.synchronize()
        let finishedAt = Date()

        let stdoutData = try Data(contentsOf: stdoutURL)
        let stderrData = try Data(contentsOf: stderrURL)

        let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let result = ProcessResult(
            command: command,
            arguments: arguments,
            workingDirectory: cwd.path,
            exitCode: process.terminationStatus,
            stdout: stdout,
            stderr: stderr,
            startedAt: startedAt,
            finishedAt: finishedAt
        )

        if process.terminationStatus != 0 {
            throw ProcessRunnerError.commandFailed(
                command: result.commandLine,
                code: process.terminationStatus,
                output: result.output
            )
        }

        return result
    }
}
