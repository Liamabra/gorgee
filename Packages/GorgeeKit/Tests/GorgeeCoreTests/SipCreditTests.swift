import Foundation
import Testing
@testable import GorgeeCore

@Suite("Volume crédité")
struct SipCreditTests {
    @Test("Le volume crédité suit la baisse du niveau")
    func creditFollowsLevelDrop() {
        #expect(SipCredit.milliliters(capacity: 300, beforeQuarters: 4, afterQuarters: 2) == 150)
        #expect(SipCredit.milliliters(capacity: 300, beforeQuarters: 3, afterQuarters: 2) == 75)
    }

    @Test("Un verre vidé crédite tout ce qu'il contenait")
    func emptiedGlassCreditsItsContent() {
        #expect(SipCredit.milliliters(capacity: 300, beforeQuarters: 4, afterQuarters: 0) == 300)
        #expect(SipCredit.milliliters(capacity: 300, beforeQuarters: 3, afterQuarters: 0) == 225)
    }

    @Test("Sans baisse visible, une gorgée vaut un quart de verre", arguments: [(4, 4), (2, 3)])
    func noVisibleDropCreditsAQuarter(before: Int, after: Int) {
        #expect(SipCredit.milliliters(capacity: 300, beforeQuarters: before, afterQuarters: after) == 75)
    }

    @Test("Des niveaux hors bornes sont ramenés entre 0 et 4")
    func levelsAreClamped() {
        #expect(SipCredit.milliliters(capacity: 300, beforeQuarters: 9, afterQuarters: -2) == 300)
    }

    @Test("Un ancien fichier de réglages, sans contenance, garde ses valeurs et prend 250 mL")
    func olderSettingsFileStillLoads() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "gorgee-settings-\(UUID().uuidString).json")
        let json = #"{"dayEndHour":21,"dayStartHour":9,"firstSignsML":300,"jokerPauseMinutes":15,"jokersPerDay":2,"sex":"male","unusableML":900,"weightKg":82}"#
        try Data(json.utf8).write(to: url)
        let settings = try #require(JSONFileStore<HydrationSettings>(url: url).load())
        #expect(settings.weightKg == 82)
        #expect(settings.dayStartHour == 9)
        #expect(settings.containerCapacityML == 250)
    }
}
