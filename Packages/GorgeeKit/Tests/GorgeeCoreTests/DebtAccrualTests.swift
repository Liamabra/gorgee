import Foundation
import Testing
@testable import GorgeeCore

@Suite("Accumulation de la dette")
struct DebtAccrualTests {
    @Test("Le premier tick ne crée aucune dette")
    func firstTickIsBaseline() {
        var engine = HydrationEngine.sample(now: TestClock.at(9))
        engine.tick(now: TestClock.at(9), isActive: true)
        #expect(engine.state.debtML == 0)
    }

    @Test("Une heure d'utilisation active accumule le débit horaire")
    func oneActiveHourAccruesHourlyRate() {
        var engine = HydrationEngine.sample(now: TestClock.at(9))
        engine.runMinutes(60, from: TestClock.at(9), isActive: true)
        #expect(abs(engine.state.debtML - HydrationSettings.sampleRatePerHour) < 0.01)
    }

    @Test("L'inactivité gèle la dette")
    func inactivityFreezesDebt() {
        var engine = HydrationEngine.sample(now: TestClock.at(9), debt: 100)
        engine.runMinutes(60, from: TestClock.at(9), isActive: false)
        #expect(engine.state.debtML == 100)
    }

    @Test("Hors de la plage horaire, la dette ne monte pas", arguments: [6, 22, 23])
    func noAccrualOutsideWindow(hour: Int) {
        var engine = HydrationEngine.sample(now: TestClock.at(hour))
        engine.runMinutes(30, from: TestClock.at(hour), isActive: true)
        #expect(engine.state.debtML == 0)
    }

    @Test("Un long trou entre deux ticks (veille) compte au plus un pas")
    func longGapIsCapped() {
        var engine = HydrationEngine.sample(now: TestClock.at(9))
        engine.tick(now: TestClock.at(9), isActive: true)
        engine.tick(now: TestClock.at(11), isActive: true)
        let oneStep = HydrationSettings.sampleRatePerHour / 60
        #expect(abs(engine.state.debtML - oneStep) < 0.01)
    }

    @Test("Le facteur d'accélération multiplie l'accumulation")
    func timeScaleMultiplies() {
        var engine = HydrationEngine.sample(now: TestClock.at(9))
        engine.tick(now: TestClock.at(9), isActive: true)
        engine.tick(now: TestClock.at(9, 1), isActive: true, timeScale: 60)
        #expect(abs(engine.state.debtML - HydrationSettings.sampleRatePerHour) < 0.01)
    }

    @Test("La dette est plafonnée au seuil « inutilisable »")
    func debtIsCapped() {
        var engine = HydrationEngine.sample(now: TestClock.at(9), debt: 740)
        engine.tick(now: TestClock.at(9), isActive: true)
        engine.tick(now: TestClock.at(9, 1), isActive: true, timeScale: 1000)
        #expect(engine.state.debtML == 750)
    }
}

@Suite("Sévérité de la sécheresse")
struct SeverityTests {
    @Test("La sévérité suit la dette entre les deux seuils", arguments: [
        (0.0, 0.0), (250.0, 0.0), (500.0, 0.5), (625.0, 0.75), (750.0, 1.0),
    ])
    func severityFollowsDebt(debt: Double, expected: Double) {
        let engine = HydrationEngine.sample(now: TestClock.at(10), debt: debt)
        #expect(abs(engine.severity(at: TestClock.at(10)) - expected) < 0.0001)
    }

    @Test("Hors de la plage horaire, l'écran n'est pas asséché")
    func noSeverityOutsideWindow() {
        let engine = HydrationEngine.sample(now: TestClock.at(23), debt: 750)
        #expect(engine.severity(at: TestClock.at(23)) == 0)
    }
}
