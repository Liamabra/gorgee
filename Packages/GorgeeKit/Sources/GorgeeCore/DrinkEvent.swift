import Foundation

public enum DrinkSource: String, Codable, Sendable, CaseIterable {
    /// Gorgée vérifiée par la caméra.
    case camera
    /// Gorgée déclarée à la main (payée par un joker).
    case manual
    /// Bu loin du Mac : compte dans le total, pas dans la dette.
    case elsewhere

    var repaysDebt: Bool { self != .elsewhere }
}

public struct DrinkEvent: Codable, Equatable, Sendable {
    public var date: Date
    public var milliliters: Int
    public var source: DrinkSource

    public init(date: Date, milliliters: Int, source: DrinkSource) {
        self.date = date
        self.milliliters = milliliters
        self.source = source
    }
}
