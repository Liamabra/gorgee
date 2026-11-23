public enum Sex: String, Codable, Sendable, CaseIterable {
    case female
    case male
}

/// Objectif d'eau journalier : un plancher par sexe, ou un volume par kilo s'il est plus grand.
public enum DailyGoal {
    public static func milliliters(sex: Sex, weightKg: Double) -> Int {
        let floor: Double
        let perKilo: Double
        switch sex {
        case .female: (floor, perKilo) = (2000, 31)
        case .male: (floor, perKilo) = (2500, 35)
        }
        let raw = max(floor, weightKg * perKilo)
        return Int((raw / 50).rounded()) * 50
    }
}
