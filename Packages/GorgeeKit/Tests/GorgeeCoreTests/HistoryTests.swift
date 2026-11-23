import Foundation
import Testing
@testable import GorgeeCore

@Suite("Historique et statistiques")
struct HistoryTests {
    static func event(day: Int, hour: Int, _ milliliters: Int, _ source: DrinkSource = .camera) -> DrinkEvent {
        DrinkEvent(date: TestClock.at(hour, day: day), milliliters: milliliters, source: source)
    }

    static func history(_ events: [DrinkEvent]) -> HydrationHistory {
        HydrationHistory(events: events, calendar: TestClock.calendar)
    }

    @Test("Les totaux par jour couvrent toute la période, jours vides compris")
    func dailyTotalsAreZeroFilled() {
        let history = Self.history([
            Self.event(day: 21, hour: 9, 250),
            Self.event(day: 21, hour: 15, 500, .elsewhere),
            Self.event(day: 23, hour: 10, 330),
            Self.event(day: 12, hour: 10, 999),
        ])
        let totals = history.dailyTotals(days: 3, endingOn: TestClock.at(18, day: 23))
        #expect(totals.map(\.milliliters) == [750, 0, 330])
        #expect(totals.map(\.day) == [21, 22, 23].map { TestClock.calendar.startOfDay(for: TestClock.at(12, day: $0)) })
    }

    @Test("La série compte les jours d'affilée où l'objectif est atteint")
    func streakCountsConsecutiveGoalDays() {
        let met = [20, 21, 22].map { Self.event(day: $0, hour: 12, 2000) }
        #expect(Self.history(met).streak(goal: 2000, today: TestClock.at(10, day: 23)) == 3)
        let withToday = met + [Self.event(day: 23, hour: 9, 2100)]
        #expect(Self.history(withToday).streak(goal: 2000, today: TestClock.at(10, day: 23)) == 4)
    }

    @Test("Un jour manqué casse la série")
    func missedDayBreaksStreak() {
        let events = [
            Self.event(day: 20, hour: 12, 2000),
            Self.event(day: 21, hour: 12, 1500),
            Self.event(day: 22, hour: 12, 2000),
        ]
        #expect(Self.history(events).streak(goal: 2000, today: TestClock.at(10, day: 23)) == 1)
        #expect(Self.history([]).streak(goal: 2000, today: TestClock.at(10, day: 23)) == 0)
    }
}

@Suite("Export")
struct ExportTests {
    static let events = [
        DrinkEvent(date: TestClock.at(13, 40, day: 23), milliliters: 500, source: .elsewhere),
        DrinkEvent(date: TestClock.at(9, 12, day: 23), milliliters: 250, source: .camera),
    ]

    @Test("Le CSV liste les gorgées dans l'ordre, à l'heure locale")
    func csvIsChronologicalInLocalTime() {
        let csv = DrinkExport.csv(Self.events, timeZone: TestClock.calendar.timeZone)
        #expect(csv == """
            date,milliliters,source
            2026-11-23T09:12:00+01:00,250,camera
            2026-11-23T13:40:00+01:00,500,elsewhere

            """)
    }

    @Test("Le JSON se relit tel quel")
    func jsonRoundTrips() throws {
        let data = try DrinkExport.json(Self.events)
        let decoded = try DrinkExport.decodeJSON(data)
        #expect(decoded == Self.events.sorted { $0.date < $1.date })
    }
}
