import Foundation

enum GorgeeJSON {
    static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date(text, strategy: dateStyle)
        }
        return decoder
    }
}

/// Une valeur sauvegardée dans un fichier JSON, écrit de façon atomique.
public struct JSONFileStore<Value: Codable>: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `nil` si le fichier est absent ou illisible : on repart alors d'un état neuf.
    /// Un fichier illisible est d'abord mis de côté (`nom.corrupt-<date>.json`), jamais écrasé.
    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let value = try? GorgeeJSON.decoder().decode(Value.self, from: data) { return value }
        let stamp = Int(Date().timeIntervalSince1970)
        let name = url.deletingPathExtension().lastPathComponent
        let aside = url.deletingLastPathComponent().appending(path: "\(name).corrupt-\(stamp).\(url.pathExtension)")
        try? FileManager.default.moveItem(at: url, to: aside)
        return nil
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try GorgeeJSON.encoder().encode(value).write(to: url, options: .atomic)
    }
}

/// Historique des gorgées, une ligne JSON par gorgée, en ajout seul.
public struct DrinkLog: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func append(_ event: DrinkEvent) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            fileManager.createFile(atPath: url.path, contents: nil)
        }
        let handle = try FileHandle(forUpdating: url)
        defer { try? handle.close() }
        let end = try handle.seekToEnd()
        var line = try GorgeeJSON.encoder().encode(event) + Data("\n".utf8)
        // Une écriture interrompue a pu laisser une ligne sans fin : on repart sur une ligne neuve.
        if end > 0 {
            try handle.seek(toOffset: end - 1)
            if try handle.read(upToCount: 1) != Data("\n".utf8) {
                line = Data("\n".utf8) + line
            }
            try handle.seekToEnd()
        }
        try handle.write(contentsOf: line)
    }

    /// Les lignes abîmées (écriture interrompue) sont ignorées.
    public func readAll() throws -> [DrinkEvent] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let decoder = GorgeeJSON.decoder()
        return try Data(contentsOf: url)
            .split(separator: UInt8(ascii: "\n"))
            .compactMap { try? decoder.decode(DrinkEvent.self, from: Data($0)) }
    }
}
