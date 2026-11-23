import Foundation

/// Profil et règles du jeu, réglables par l'utilisateur.
public struct HydrationSettings: Codable, Equatable, Sendable {
    public var sex: Sex
    public var weightKg: Double
    /// Plage horaire où la dette peut monter, en heures pleines : [début, fin).
    public var dayStartHour: Int
    public var dayEndHour: Int
    /// Dette à partir de laquelle la sécheresse apparaît.
    public var firstSignsML: Double
    /// Dette à laquelle l'écran devient inutilisable ; c'est aussi le plafond de la dette.
    public var unusableML: Double
    public var jokersPerDay: Int
    public var jokerPauseMinutes: Double

    public init(
        sex: Sex,
        weightKg: Double,
        dayStartHour: Int = 8,
        dayEndHour: Int = 22,
        firstSignsML: Double = 250,
        unusableML: Double = 750,
        jokersPerDay: Int = 2,
        jokerPauseMinutes: Double = 15
    ) {
        self.sex = sex
        self.weightKg = weightKg
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.firstSignsML = firstSignsML
        self.unusableML = unusableML
        self.jokersPerDay = jokersPerDay
        self.jokerPauseMinutes = jokerPauseMinutes
    }

    public var dailyGoalML: Int {
        DailyGoal.milliliters(sex: sex, weightKg: weightKg)
    }

    /// L'objectif étalé sur la plage horaire : ce que la dette gagne par heure d'utilisation active.
    public var accrualPerHourML: Double {
        Double(dailyGoalML) / Double(max(1, dayEndHour - dayStartHour))
    }
}
