import Foundation
import OSLog

/// Relance automatique : un LaunchAgent utilisateur lance Gorgée au login et la relance si on la tue.
///
/// L'instance « officielle » est celle que lance launchd (variable `GORGEE_AGENT=1`). Une sortie
/// normale (code 0, « Quitter » protégé) n'est pas relancée ; un `kill` ou un plantage l'est.
enum LaunchAgent {
    static let label = "app.gorgee.Gorgee.agent"
    private static let environmentKey = "GORGEE_AGENT"
    private static let log = Logger(subsystem: "app.gorgee.Gorgee", category: "launch-agent")

    static var isRunningAsAgent: Bool {
        ProcessInfo.processInfo.environment[environmentKey] == "1"
    }

    static var plistURL: URL {
        URL.homeDirectory.appending(path: "Library/LaunchAgents/\(label).plist")
    }

    private static var domain: String { "gui/\(getuid())" }

    /// Installe l'agent pour cet exécutable et le démarre. `true` si l'instance launchd a pris le relais.
    static func handOver() -> Bool {
        guard let executable = Bundle.main.executableURL else { return false }
        do {
            try writePlist(executable: executable)
        } catch {
            log.error("Plist non écrite : \(error)")
            return false
        }
        // Recharger garantit que launchd lit le chemin courant (un nouveau build a pu bouger).
        launchctl(["bootout", "\(domain)/\(label)"])
        for attempt in 1...5 {
            if launchctl(["bootstrap", domain, plistURL.path]) == 0 { return true }
            log.info("bootstrap refusé (essai \(attempt)), nouvel essai")
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    /// Retire l'agent. Si l'instance courante est l'agent, launchd la termine.
    static func uninstall() {
        try? FileManager.default.removeItem(at: plistURL)
        launchctl(["bootout", "\(domain)/\(label)"])
    }

    private static func writePlist(executable: URL) throws {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable.path],
            "EnvironmentVariables": [environmentKey: "1"],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 5,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            log.error("launchctl \(arguments.joined(separator: " ")) : \(error)")
            return -1
        }
    }
}
