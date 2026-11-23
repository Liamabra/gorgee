import Foundation
import Testing
@testable import GorgeeCore

@Suite("Gorgées")
struct DrinkTests {
    @Test("Une gorgée vérifiée rembourse la dette et compte dans le total", arguments: [DrinkSource.camera, .manual])
    func verifiedDrinkRepaysDebt(source: DrinkSource) {
        var engine = HydrationEngine.sample(now: TestClock.at(10), debt: 500)
        let event = engine.recordDrink(300, source: source, at: TestClock.at(10))
        #expect(engine.state.debtML == 200)
        #expect(engine.state.drankTodayML == 300)
        #expect(event == DrinkEvent(date: TestClock.at(10), milliliters: 300, source: source))
    }

    @Test("La dette ne descend jamais sous zéro")
    func debtFloorsAtZero() {
        var engine = HydrationEngine.sample(now: TestClock.at(10), debt: 100)
        engine.recordDrink(330, source: .camera, at: TestClock.at(10))
        #expect(engine.state.debtML == 0)
        #expect(engine.state.drankTodayML == 330)
    }

    @Test("« Bu ailleurs » compte dans le total sans rembourser la dette")
    func elsewhereDoesNotRepay() {
        var engine = HydrationEngine.sample(now: TestClock.at(13), debt: 400)
        engine.recordDrink(500, source: .elsewhere, at: TestClock.at(13))
        #expect(engine.state.debtML == 400)
        #expect(engine.state.drankTodayML == 500)
    }
}

@Suite("Changement de jour")
struct DayRolloverTests {
    static func yesterdayEngine() -> HydrationEngine {
        var state = HydrationState.fresh(for: TestClock.at(12, day: 22), calendar: TestClock.calendar, jokers: 0)
        state.debtML = 600
        state.drankTodayML = 1500
        state.lastTick = TestClock.at(21, 59, day: 22)
        return HydrationEngine(settings: .sample, state: state, calendar: TestClock.calendar)
    }

    @Test("Le premier tick du matin remet dette, total et jokers à zéro")
    func tickOnNewDayResets() {
        var engine = Self.yesterdayEngine()
        engine.tick(now: TestClock.at(9), isActive: true)
        #expect(TestClock.calendar.isDate(engine.state.day, inSameDayAs: TestClock.at(9)))
        #expect(engine.state.debtML == 0)
        #expect(engine.state.drankTodayML == 0)
        #expect(engine.state.jokersLeft == 2)
    }

    @Test("Le changement de jour ne crédite pas la nuit comme du temps actif")
    func rolloverKeepsBaseline() {
        var engine = Self.yesterdayEngine()
        engine.tick(now: TestClock.at(9), isActive: true)
        #expect(engine.state.lastTick == TestClock.at(9))
        #expect(engine.state.debtML == 0)
    }

    @Test("Une gorgée le lendemain compte pour le nouveau jour")
    func drinkOnNewDayCountsForNewDay() {
        var engine = Self.yesterdayEngine()
        engine.recordDrink(250, source: .elsewhere, at: TestClock.at(8, 30))
        #expect(engine.state.drankTodayML == 250)
        #expect(engine.state.debtML == 0)
    }

    @Test("Un état resté sur la veille n'assèche pas l'écran")
    func staleStateHasNoSeverity() {
        let engine = Self.yesterdayEngine()
        #expect(engine.severity(at: TestClock.at(9)) == 0)
    }
}
