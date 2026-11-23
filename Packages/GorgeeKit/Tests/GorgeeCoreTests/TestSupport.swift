import Foundation
@testable import GorgeeCore

enum TestClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    /// Une date du 23 novembre 2026 (ou d'un autre jour) à l'heure de Paris.
    static func at(_ hour: Int, _ minute: Int = 0, _ second: Int = 0, day: Int = 23) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute, second: second))!
    }
}

extension HydrationSettings {
    /// Femme de 60 kg, 8 h – 22 h : objectif 2000 mL, soit 2000 / 14 mL par heure active.
    static let sample = HydrationSettings(sex: .female, weightKg: 60)
    static let sampleRatePerHour = 2000.0 / 14.0
}

extension HydrationEngine {
    static func sample(now: Date, debt: Double = 0) -> HydrationEngine {
        var state = HydrationState.fresh(for: now, calendar: TestClock.calendar, jokers: 2)
        state.debtML = debt
        return HydrationEngine(settings: .sample, state: state, calendar: TestClock.calendar)
    }

    /// Fait avancer l'horloge par pas d'une minute, comme le minuteur de l'app.
    mutating func runMinutes(_ minutes: Int, from start: Date, isActive: Bool) {
        for minute in 0...minutes {
            tick(now: start.addingTimeInterval(Double(minute) * 60), isActive: isActive)
        }
    }
}
