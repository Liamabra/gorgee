import Foundation

/// Ce qui est persisté entre deux lancements.
public struct HydrationState: Codable, Equatable, Sendable {
    /// Début du jour auquel se rapportent les compteurs.
    public var day: Date
    public var debtML: Double
    public var drankTodayML: Int
    public var jokersLeft: Int
    public var pausedUntil: Date?
    public var lastTick: Date?
    /// Preuves refusées d'affilée ; à 3, on peut déclarer à la main contre un joker.
    public var consecutiveRefusals: Int

    public static func fresh(day: Date, jokers: Int) -> HydrationState {
        HydrationState(
            day: day, debtML: 0, drankTodayML: 0, jokersLeft: jokers,
            pausedUntil: nil, lastTick: nil, consecutiveRefusals: 0
        )
    }
}

extension HydrationState {
    /// Lecture tolérante : un champ ajouté après coup prend sa valeur par défaut dans un ancien fichier.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Date.self, forKey: .day)
        debtML = try container.decode(Double.self, forKey: .debtML)
        drankTodayML = try container.decode(Int.self, forKey: .drankTodayML)
        jokersLeft = try container.decode(Int.self, forKey: .jokersLeft)
        pausedUntil = try container.decodeIfPresent(Date.self, forKey: .pausedUntil)
        lastTick = try container.decodeIfPresent(Date.self, forKey: .lastTick)
        consecutiveRefusals = try container.decodeIfPresent(Int.self, forKey: .consecutiveRefusals) ?? 0
    }
}

/// Le cœur du jeu : la dette monte pendant l'utilisation active et assèche l'écran.
public struct HydrationEngine: Sendable {
    public var settings: HydrationSettings
    public private(set) var state: HydrationState
    public let calendar: Calendar

    /// Au-delà, un écart entre deux ticks (veille, minuteur bloqué) ne compte que pour ce pas.
    public static let maxTickStep: TimeInterval = 60

    public init(settings: HydrationSettings, state: HydrationState, calendar: Calendar = .current) {
        self.settings = settings
        self.state = state
        self.calendar = calendar
    }

    public func isInWindow(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= settings.dayStartHour && hour < settings.dayEndHour
    }

    /// À appeler à intervalle régulier ; `isActive` dit si l'utilisateur se sert du Mac.
    public mutating func tick(now: Date, isActive: Bool, timeScale: Double = 1) {
        rollOverIfNeeded(now)
        defer { state.lastTick = now }
        guard let last = state.lastTick, now > last, isActive, isInWindow(now) else { return }
        let elapsed = min(now.timeIntervalSince(last), Self.maxTickStep) * timeScale
        let accrued = settings.accrualPerHourML * elapsed / 3600
        state.debtML = min(settings.unusableML, state.debtML + accrued)
    }

    /// Une gorgée vérifiée (caméra) ou déclarée (joker) rembourse la dette ; « bu ailleurs » non.
    @discardableResult
    public mutating func recordDrink(_ milliliters: Int, source: DrinkSource, at now: Date) -> DrinkEvent {
        rollOverIfNeeded(now)
        state.drankTodayML += milliliters
        if source.repaysDebt {
            state.debtML = max(0, state.debtML - Double(milliliters))
            state.consecutiveRefusals = 0
        }
        return DrinkEvent(date: now, milliliters: milliliters, source: source)
    }

    /// Une preuve par caméra a échoué.
    public mutating func recordRefusal(at now: Date) {
        rollOverIfNeeded(now)
        state.consecutiveRefusals += 1
    }

    /// Sans caméra utilisable, ou après 3 refus d'affilée, on peut déclarer à la main contre un joker.
    public func canDeclareManually(at now: Date, cameraAvailable: Bool) -> Bool {
        let refusals = calendar.isDate(state.day, inSameDayAs: now) ? state.consecutiveRefusals : 0
        let jokers = calendar.isDate(state.day, inSameDayAs: now) ? state.jokersLeft : settings.jokersPerDay
        return jokers > 0 && (!cameraAvailable || refusals >= Self.refusalsBeforeManual)
    }

    public static let refusalsBeforeManual = 3

    /// Déclare une gorgée sans preuve, payée par un joker. `nil` si ce n'est pas permis.
    @discardableResult
    public mutating func declareManually(_ milliliters: Int, at now: Date, cameraAvailable: Bool) -> DrinkEvent? {
        rollOverIfNeeded(now)
        guard canDeclareManually(at: now, cameraAvailable: cameraAvailable) else { return nil }
        state.jokersLeft -= 1
        return recordDrink(milliliters, source: .manual, at: now)
    }

    /// 0 = écran intact, 1 = inutilisable.
    public func severity(at now: Date) -> Double {
        guard calendar.isDate(state.day, inSameDayAs: now), isInWindow(now) else { return 0 }
        let span = settings.unusableML - settings.firstSignsML
        guard span > 0 else { return state.debtML >= settings.unusableML ? 1 : 0 }
        return min(1, max(0, (state.debtML - settings.firstSignsML) / span))
    }

    /// Ce que l'overlay doit montrer : rien pendant une pause joker ou une visio, la dette continuant de monter.
    public func displaySeverity(at now: Date, cameraBusy: Bool) -> Double {
        guard !cameraBusy, !isPaused(at: now) else { return 0 }
        return severity(at: now)
    }

    public func isPaused(at now: Date) -> Bool {
        guard let pausedUntil = state.pausedUntil else { return false }
        return now < pausedUntil
    }

    /// Dépense un joker pour suspendre la sécheresse. Refusé sans joker ou pendant une pause.
    @discardableResult
    public mutating func usePauseJoker(at now: Date) -> Bool {
        rollOverIfNeeded(now)
        guard state.jokersLeft > 0, !isPaused(at: now) else { return false }
        state.jokersLeft -= 1
        state.pausedUntil = now.addingTimeInterval(settings.jokerPauseMinutes * 60)
        return true
    }

    /// Chaque matin, on repart de zéro ; la nuit ne compte pas comme du temps actif.
    private mutating func rollOverIfNeeded(_ now: Date) {
        guard !calendar.isDate(state.day, inSameDayAs: now) else { return }
        state = .fresh(day: calendar.startOfDay(for: now), jokers: settings.jokersPerDay)
    }
}
