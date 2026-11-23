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
    /// Contenance du verre ou de la bouteille habituels.
    public var containerCapacityML: Int

    public init(
        sex: Sex,
        weightKg: Double,
        dayStartHour: Int = 8,
        dayEndHour: Int = 22,
        firstSignsML: Double = 250,
        unusableML: Double = 750,
        jokersPerDay: Int = 2,
        jokerPauseMinutes: Double = 15,
        containerCapacityML: Int = 250
    ) {
        self.sex = sex
        self.weightKg = weightKg
        self.dayStartHour = dayStartHour
        self.dayEndHour = dayEndHour
        self.firstSignsML = firstSignsML
        self.unusableML = unusableML
        self.jokersPerDay = jokersPerDay
        self.jokerPauseMinutes = jokerPauseMinutes
        self.containerCapacityML = containerCapacityML
    }

    public var dailyGoalML: Int {
        DailyGoal.milliliters(sex: sex, weightKg: weightKg)
    }

    /// L'objectif étalé sur la plage horaire : ce que la dette gagne par heure d'utilisation active.
    public var accrualPerHourML: Double {
        Double(dailyGoalML) / Double(max(1, dayEndHour - dayStartHour))
    }
}

extension HydrationSettings {
    /// Lecture tolérante : un réglage ajouté après coup prend sa valeur par défaut dans un ancien fichier.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = HydrationSettings(sex: .female, weightKg: 60)
        self.init(
            sex: try container.decode(Sex.self, forKey: .sex),
            weightKg: try container.decode(Double.self, forKey: .weightKg),
            dayStartHour: try container.decodeIfPresent(Int.self, forKey: .dayStartHour) ?? defaults.dayStartHour,
            dayEndHour: try container.decodeIfPresent(Int.self, forKey: .dayEndHour) ?? defaults.dayEndHour,
            firstSignsML: try container.decodeIfPresent(Double.self, forKey: .firstSignsML) ?? defaults.firstSignsML,
            unusableML: try container.decodeIfPresent(Double.self, forKey: .unusableML) ?? defaults.unusableML,
            jokersPerDay: try container.decodeIfPresent(Int.self, forKey: .jokersPerDay) ?? defaults.jokersPerDay,
            jokerPauseMinutes: try container.decodeIfPresent(Double.self, forKey: .jokerPauseMinutes) ?? defaults.jokerPauseMinutes,
            containerCapacityML: try container.decodeIfPresent(Int.self, forKey: .containerCapacityML) ?? defaults.containerCapacityML
        )
    }
}
