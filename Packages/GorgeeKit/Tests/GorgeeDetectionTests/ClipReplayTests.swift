import Foundation
import GorgeeCore
import Testing
@testable import GorgeeDetection

/// Rejoue les clips de `Fixtures/clips/` (privés, ignorés par git) dans le pipeline complet.
///
/// Nom de fichier : `ok-…` pour une vraie gorgée, `refus-<raison>-…` pour une triche,
/// où `<raison>` est une valeur de `SipRefusal` (par exemple `refus-coloredLiquid-cola.mov`).
@Suite("Clips rejoués", .enabled(if: ClipFixtures.available, "aucun clip dans Fixtures/clips"))
struct ClipReplayTests {
    @Test("Chaque clip donne le verdict annoncé par son nom", arguments: ClipFixtures.all)
    func clipMatchesExpectation(clip: URL) async throws {
        let result = try await ClipReplay.run(clip)
        let name = clip.deletingPathExtension().lastPathComponent
        let expected = ClipFixtures.expectation(for: name)
        print("\(name) → \(result.step) (\(result.frames) images, \(String(format: "%.1f", result.duration)) s)")
        switch (expected, result.step) {
        case (.verified, .verified):
            break
        case (.refused(let reason), .refused(let actual)):
            #expect(actual == reason, "\(name) : refus attendu \(reason), obtenu \(actual)")
        default:
            Issue.record("\(name) : attendu \(expected), obtenu \(result.step)")
        }
    }
}

enum ClipFixtures {
    enum Expectation: CustomStringConvertible {
        case verified
        case refused(SipRefusal)
        case unknown

        var description: String {
            switch self {
            case .verified: "validée"
            case .refused(let reason): "refus \(reason.rawValue)"
            case .unknown: "nom de clip non reconnu"
            }
        }
    }

    /// `GORGEE_CLIPS_DIR` permet de rejouer un autre dossier.
    static let directory = ProcessInfo.processInfo.environment["GORGEE_CLIPS_DIR"].map { URL(filePath: $0) } ?? URL(filePath: #filePath)
        .deletingLastPathComponent() // GorgeeDetectionTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // GorgeeKit
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // racine du dépôt
        .appending(path: "Fixtures/clips")

    static var all: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { ["mov", "mp4", "m4v"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static var available: Bool { !all.isEmpty }

    static func expectation(for name: String) -> Expectation {
        let parts = name.split(separator: "-")
        guard let kind = parts.first else { return .unknown }
        if kind == "ok" { return .verified }
        if kind == "refus", parts.count > 1, let reason = SipRefusal(rawValue: String(parts[1])) {
            return .refused(reason)
        }
        return .unknown
    }
}
