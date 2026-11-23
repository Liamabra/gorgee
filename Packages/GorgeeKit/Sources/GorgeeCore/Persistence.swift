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
    public func load() -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? GorgeeJSON.decoder().decode(Value.self, from: data)
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
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: GorgeeJSON.encoder().encode(event) + Data("\n".utf8))
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
