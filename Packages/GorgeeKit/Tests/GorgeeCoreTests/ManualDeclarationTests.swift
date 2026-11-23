import Foundation
import Testing
@testable import GorgeeCore

@Suite("Refus et déclaration manuelle")
struct ManualDeclarationTests {
    @Test("Trois refus d'affilée ouvrent la déclaration manuelle")
    func threeRefusalsUnlockManual() {
        var engine = HydrationEngine.sample(now: TestClock.at(10), debt: 400)
        engine.recordRefusal(at: TestClock.at(10))
        engine.recordRefusal(at: TestClock.at(10, 1))
        #expect(!engine.canDeclareManually(at: TestClock.at(10, 2), cameraAvailable: true))
        engine.recordRefusal(at: TestClock.at(10, 2))
        #expect(engine.canDeclareManually(at: TestClock.at(10, 3), cameraAvailable: true))
    }

    @Test("Sans caméra, la déclaration manuelle est possible tout de suite")
    func noCameraUnlocksManual() {
        let engine = HydrationEngine.sample(now: TestClock.at(10), debt: 400)
        #expect(engine.canDeclareManually(at: TestClock.at(10), cameraAvailable: false))
    }

    @Test("Déclarer à la main coûte un joker et rembourse la dette")
    func manualCostsAJoker() {
        var engine = HydrationEngine.sample(now: TestClock.at(10), debt: 400)
        let event = engine.declareManually(250, at: TestClock.at(10), cameraAvailable: false)
        #expect(event == DrinkEvent(date: TestClock.at(10), milliliters: 250, source: .manual))
        #expect(engine.state.jokersLeft == 1)
        #expect(engine.state.debtML == 150)
    }

    @Test("Sans joker, pas de déclaration manuelle")
    func noJokerNoManual() {
        var engine = HydrationEngine.sample(now: TestClock.at(10), debt: 400)
        engine.declareManually(250, at: TestClock.at(10), cameraAvailable: false)
        engine.declareManually(250, at: TestClock.at(10, 5), cameraAvailable: false)
        let third = engine.declareManually(250, at: TestClock.at(10, 10), cameraAvailable: false)
        #expect(third == nil)
        #expect(engine.state.jokersLeft == 0)
        #expect(engine.state.drankTodayML == 500)
    }

    @Test("Avec la caméra et sans refus, la déclaration manuelle est refusée")
    func manualNeedsRefusalsWhenCameraWorks() {
        var engine = HydrationEngine.sample(now: TestClock.at(10), debt: 400)
        let declared = engine.declareManually(250, at: TestClock.at(10), cameraAvailable: true)
        #expect(declared == nil)
        #expect(engine.state.jokersLeft == 2)
    }

    @Test("Une gorgée vérifiée ou déclarée remet le compteur de refus à zéro", arguments: [DrinkSource.camera, .manual])
    func drinkResetsRefusals(source: DrinkSource) {
        var engine = HydrationEngine.sample(now: TestClock.at(10), debt: 400)
        for minute in 0..<3 { engine.recordRefusal(at: TestClock.at(10, minute)) }
        if source == .camera {
            engine.recordDrink(250, source: .camera, at: TestClock.at(10, 5))
        } else {
            engine.declareManually(250, at: TestClock.at(10, 5), cameraAvailable: true)
        }
        #expect(engine.state.consecutiveRefusals == 0)
    }

    @Test("Le changement de jour remet les refus à zéro")
    func rolloverResetsRefusals() {
        var engine = HydrationEngine.sample(now: TestClock.at(21), debt: 0)
        for minute in 0..<3 { engine.recordRefusal(at: TestClock.at(21, minute)) }
        engine.tick(now: TestClock.at(9, day: 24), isActive: true)
        #expect(engine.state.consecutiveRefusals == 0)
    }

    @Test("Un ancien fichier d'état, sans compteur de refus, reste lisible")
    func olderStateFileStillLoads() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "gorgee-old-\(UUID().uuidString).json")
        let json = #"{"day":"2026-11-22T23:00:00.000Z","debtML":120.5,"drankTodayML":750,"jokersLeft":1}"#
        try Data(json.utf8).write(to: url)
        let state = try #require(JSONFileStore<HydrationState>(url: url).load())
        #expect(state.debtML == 120.5)
        #expect(state.consecutiveRefusals == 0)
    }
}
