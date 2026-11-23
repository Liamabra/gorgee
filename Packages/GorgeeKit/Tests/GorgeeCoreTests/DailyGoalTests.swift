import Testing
@testable import GorgeeCore

@Suite("Objectif journalier")
struct DailyGoalTests {
    @Test("Une femme légère reçoit le plancher de 2 L")
    func lightFemaleGetsFloor() {
        #expect(DailyGoal.milliliters(sex: .female, weightKg: 60) == 2000)
    }

    @Test("Un homme lourd reçoit 35 mL par kilo")
    func heavyMaleGetsPerKilo() {
        #expect(DailyGoal.milliliters(sex: .male, weightKg: 80) == 2800)
    }

    @Test("Une femme lourde reçoit 31 mL par kilo")
    func heavyFemaleGetsPerKilo() {
        // 75 × 31 = 2325 → 46,5 paliers de 50 → arrondi à 47 → 2350
        #expect(DailyGoal.milliliters(sex: .female, weightKg: 75) == 2350)
    }

    @Test("Le résultat est arrondi aux 50 mL les plus proches")
    func roundsToNearestFifty() {
        // 72,2 × 35 = 2527 → 2550 ; 71 × 35 = 2485 → max(2500, 2485) = 2500
        #expect(DailyGoal.milliliters(sex: .male, weightKg: 72.2) == 2550)
        #expect(DailyGoal.milliliters(sex: .male, weightKg: 71) == 2500)
        // 70 × 31 = 2170 → 2150
        #expect(DailyGoal.milliliters(sex: .female, weightKg: 70) == 2150)
    }
}
