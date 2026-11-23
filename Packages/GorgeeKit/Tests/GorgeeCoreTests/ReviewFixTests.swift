import Foundation
import Testing
@testable import GorgeeCore

@Suite("Contournements par les réglages")
struct SettingsBypassTests {
    @Test("Abaisser le seuil « inutilisable » ne fait pas fondre la dette")
    func loweringThresholdKeepsDebt() {
        var engine = HydrationEngine.sample(now: TestClock.at(15), debt: 750)
        engine.settings.unusableML = 100
        engine.tick(now: TestClock.at(15), isActive: true)
        engine.tick(now: TestClock.at(15, 1), isActive: true)
        #expect(engine.state.debtML == 750)
        engine.settings.unusableML = 750
        #expect(engine.severity(at: TestClock.at(15, 1)) == 1)
    }

    @Test("Un réglage modifié s'applique le lendemain")
    func scheduledSettingsApplyTomorrow() {
        var engine = HydrationEngine.sample(now: TestClock.at(15), debt: 600)
        var looser = engine.settings
        looser.dayEndHour = 15
        engine.scheduleSettings(looser)
        #expect(engine.settings.dayEndHour == 22)
        #expect(engine.state.pendingSettings == looser)
        #expect(engine.severity(at: TestClock.at(15, 30)) > 0)
        engine.tick(now: TestClock.at(9, day: 24), isActive: true)
        #expect(engine.settings.dayEndHour == 15)
        #expect(engine.state.pendingSettings == nil)
    }

    @Test("Des réglages en attente survivent à un redémarrage")
    func pendingSettingsPersist() throws {
        var engine = HydrationEngine.sample(now: TestClock.at(15))
        var heavier = engine.settings
        heavier.weightKg = 90
        engine.scheduleSettings(heavier)
        let url = FileManager.default.temporaryDirectory.appending(path: "gorgee-pending-\(UUID().uuidString).json")
        let store = JSONFileStore<HydrationState>(url: url)
        try store.save(engine.state)
        #expect(store.load()?.pendingSettings == heavier)
    }
}

@Suite("Fuseaux horaires")
struct TimeZoneTests {
    @Test("Changer de fuseau dans la même journée ne remet pas la journée à zéro")
    func travellingWestKeepsTheDay() {
        var state = HydrationState.fresh(for: TestClock.at(9), calendar: TestClock.calendar, jokers: 2)
        state.debtML = 400
        state.jokersLeft = 1
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        var engine = HydrationEngine(settings: .sample, state: state, calendar: london)
        engine.tick(now: TestClock.at(11), isActive: true)
        #expect(engine.state.debtML == 400)
        #expect(engine.state.jokersLeft == 1)
    }
}

@Suite("Données jamais perdues en silence")
struct DataSafetyTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "gorgee-safety-\(UUID().uuidString)")

    @Test("Un fichier illisible est mis de côté avant d'être remplacé")
    func corruptedFileIsSetAside() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "state.json")
        try Data("{abîmé".utf8).write(to: url)
        #expect(JSONFileStore<HydrationState>(url: url).load() == nil)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.contains { $0.hasPrefix("state.corrupt-") })
        #expect(!files.contains("state.json"))
    }

    @Test("Après une ligne tronquée sans fin de ligne, la gorgée suivante n'est pas perdue")
    func appendAfterTornLineKeepsNextEvent() throws {
        let url = directory.appending(path: "drinks.jsonl")
        let log = DrinkLog(url: url)
        let first = DrinkEvent(date: TestClock.at(9), milliliters: 250, source: .camera)
        let second = DrinkEvent(date: TestClock.at(11), milliliters: 330, source: .camera)
        try log.append(first)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"date":"2026-11-23T"#.utf8))
        try handle.close()
        try log.append(second)
        #expect(try log.readAll() == [first, second])
    }
}
