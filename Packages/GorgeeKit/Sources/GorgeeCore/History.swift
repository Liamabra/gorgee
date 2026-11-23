import Foundation

public struct DailyTotal: Equatable, Sendable, Identifiable {
    /// Début du jour.
    public var day: Date
    public var milliliters: Int

    public var id: Date { day }
}

/// Ce que disent les gorgées passées : totaux par jour et série de jours réussis.
///
/// « Bu ailleurs » compte dans les totaux. La série se mesure avec l'objectif actuel.
public struct HydrationHistory: Sendable {
    public let calendar: Calendar
    private let totalsByDay: [Date: Int]

    public init(events: [DrinkEvent], calendar: Calendar = .current) {
        self.calendar = calendar
        var totals: [Date: Int] = [:]
        for event in events {
            totals[calendar.startOfDay(for: event.date), default: 0] += event.milliliters
        }
        totalsByDay = totals
    }

    public func total(on date: Date) -> Int {
        totalsByDay[calendar.startOfDay(for: date)] ?? 0
    }

    /// Les `days` derniers jours jusqu'à `today` inclus, du plus ancien au plus récent.
    public func dailyTotals(days: Int, endingOn today: Date) -> [DailyTotal] {
        let end = calendar.startOfDay(for: today)
        return (0..<max(0, days)).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: end) else { return nil }
            return DailyTotal(day: day, milliliters: totalsByDay[day] ?? 0)
        }
    }

    /// Jours d'affilée avec l'objectif atteint. Aujourd'hui ne compte que s'il est déjà réussi.
    public func streak(goal: Int, today: Date) -> Int {
        guard goal > 0 else { return 0 }
        var day = calendar.startOfDay(for: today)
        if (totalsByDay[day] ?? 0) < goal {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while (totalsByDay[day] ?? 0) >= goal {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

/// Export de l'historique des gorgées.
public enum DrinkExport {
    public static func csv(_ events: [DrinkEvent], timeZone: TimeZone = .current) -> String {
        let style = Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: timeZone)
        var lines = ["date,milliliters,source"]
        for event in events.sorted(by: { $0.date < $1.date }) {
            lines.append("\(event.date.formatted(style)),\(event.milliliters),\(event.source.rawValue)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func json(_ events: [DrinkEvent]) throws -> Data {
        let encoder = GorgeeJSON.encoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(events.sorted { $0.date < $1.date })
    }

    public static func decodeJSON(_ data: Data) throws -> [DrinkEvent] {
        try GorgeeJSON.decoder().decode([DrinkEvent].self, from: data)
    }
}
