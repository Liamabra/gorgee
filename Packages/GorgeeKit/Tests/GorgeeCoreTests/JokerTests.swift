import Foundation
import Testing
@testable import GorgeeCore

@Suite("Jokers et suspensions")
struct JokerTests {
    @Test("Un joker suspend la sécheresse 15 minutes")
    func jokerPausesForFifteenMinutes() {
        var engine = HydrationEngine.sample(now: TestClock.at(15), debt: 750)
        let granted = engine.usePauseJoker(at: TestClock.at(15))
        #expect(granted)
        #expect(engine.state.jokersLeft == 1)
        #expect(engine.state.pausedUntil == TestClock.at(15, 15))
        #expect(engine.displaySeverity(at: TestClock.at(15, 14), cameraBusy: false) == 0)
        #expect(engine.displaySeverity(at: TestClock.at(15, 15), cameraBusy: false) == 1)
    }

    @Test("La dette continue de monter pendant la pause")
    func debtKeepsAccruingWhilePaused() {
        var engine = HydrationEngine.sample(now: TestClock.at(15), debt: 300)
        engine.usePauseJoker(at: TestClock.at(15))
        engine.runMinutes(10, from: TestClock.at(15), isActive: true)
        #expect(engine.state.debtML > 300)
    }

    @Test("Sans joker restant, pas de pause")
    func noJokerNoPause() {
        var engine = HydrationEngine.sample(now: TestClock.at(15), debt: 750)
        engine.usePauseJoker(at: TestClock.at(15))
        engine.usePauseJoker(at: TestClock.at(15, 20))
        #expect(engine.state.jokersLeft == 0)
        let granted = engine.usePauseJoker(at: TestClock.at(15, 40))
        #expect(!granted)
        #expect(engine.displaySeverity(at: TestClock.at(15, 40), cameraBusy: false) == 1)
    }

    @Test("Un joker ne se cumule pas avec une pause en cours")
    func noStackingWhilePaused() {
        var engine = HydrationEngine.sample(now: TestClock.at(15), debt: 750)
        engine.usePauseJoker(at: TestClock.at(15))
        let granted = engine.usePauseJoker(at: TestClock.at(15, 5))
        #expect(!granted)
        #expect(engine.state.jokersLeft == 1)
    }

    @Test("Une visio en cours suspend l'affichage sans arrêter la dette")
    func cameraBusySuspendsDisplay() {
        let engine = HydrationEngine.sample(now: TestClock.at(11), debt: 500)
        #expect(engine.displaySeverity(at: TestClock.at(11), cameraBusy: true) == 0)
        #expect(engine.displaySeverity(at: TestClock.at(11), cameraBusy: false) == 0.5)
    }
}
