import Foundation
import Testing
@testable import GorgeeCore

@Suite("Persistance")
struct PersistenceTests {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "gorgee-tests-\(UUID().uuidString)")
    }

    @Test("L'état se relit tel qu'il a été écrit")
    func stateRoundTrips() throws {
        let store = JSONFileStore<HydrationState>(url: directory.appending(path: "state.json"))
        var state = HydrationState.fresh(day: TestClock.calendar.startOfDay(for: TestClock.at(9)), jokers: 1)
        state.debtML = 432.5
        state.pausedUntil = TestClock.at(9, 15)
        state.lastTick = TestClock.at(9, 3, 27)
        try store.save(state)
        #expect(store.load() == state)
    }

    @Test("Un fichier absent donne rien, pas une erreur")
    func missingFileLoadsNil() {
        let store = JSONFileStore<HydrationSettings>(url: directory.appending(path: "absent.json"))
        #expect(store.load() == nil)
    }

    @Test("Un fichier corrompu donne rien, pour repartir proprement")
    func corruptedFileLoadsNil() throws {
        let url = directory.appending(path: "settings.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{pas du json".utf8).write(to: url)
        #expect(JSONFileStore<HydrationSettings>(url: url).load() == nil)
    }

    @Test("Le journal des gorgées s'allonge et se relit dans l'ordre")
    func drinkLogAppendsInOrder() throws {
        let log = DrinkLog(url: directory.appending(path: "drinks.jsonl"))
        let first = DrinkEvent(date: TestClock.at(9, 12), milliliters: 250, source: .camera)
        let second = DrinkEvent(date: TestClock.at(13, 40), milliliters: 500, source: .elsewhere)
        try log.append(first)
        try log.append(second)
        #expect(try log.readAll() == [first, second])
    }

    @Test("Une ligne abîmée du journal est ignorée, les autres restent")
    func drinkLogSkipsDamagedLines() throws {
        let url = directory.appending(path: "drinks.jsonl")
        let log = DrinkLog(url: url)
        let event = DrinkEvent(date: TestClock.at(10), milliliters: 330, source: .manual)
        try log.append(event)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{tronqué\n".utf8))
        try handle.close()
        #expect(try log.readAll() == [event])
    }
}
