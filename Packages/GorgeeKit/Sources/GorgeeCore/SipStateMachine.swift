/// Ce que le juge d'images voit dans la main de l'utilisateur.
public enum ContainerVerdict: Equatable, Sendable {
    /// Récipient transparent, liquide incolore ; niveau en quarts (0 vide, 4 plein).
    case clearLiquid(fillQuarters: Int)
    case coloredLiquid
    case opaqueLiquid
    case emptyContainer
    case opaqueContainer
    case noContainer
}

public enum SipRefusal: String, Equatable, Sendable, Codable {
    case noContainer
    case coloredLiquid
    case opaqueLiquid
    case emptyContainer
    case opaqueContainer
    case noDrinkSeen
    case notLowered
    case containerLost
}

public enum SipStep: Equatable, Sendable {
    case showContainer
    case drink
    case lower
    case showContainerAgain
    case verified(beforeQuarters: Int, afterQuarters: Int)
    case refused(SipRefusal)
}

/// Une image analysée : l'utilisateur a-t-il le récipient à la bouche, tête inclinée ?
public struct SipFrame: Equatable, Sendable {
    public var time: Double
    public var drinkingPose: Bool

    public init(time: Double, drinkingPose: Bool) {
        self.time = time
        self.drinkingPose = drinkingPose
    }
}

/// Le déroulé d'une preuve : montrer le verre, boire, le reposer, le remontrer.
///
/// Les temps sont en secondes, sur l'horloge des images (caméra ou clip rejoué).
public struct SipStateMachine: Sendable {
    public struct Timing: Sendable {
        public var showContainer: Double = 20
        public var drink: Double = 30
        public var lower: Double = 20
        public var showContainerAgain: Double = 15
        /// Durée continue du geste « boire » pour valider la gorgée.
        public var holdAtMouth: Double = 1.5
        /// Trou de détection toléré pendant le geste.
        public var gapTolerance: Double = 0.35
        /// Durée hors de la bouche pour considérer le verre reposé.
        public var lowerHold: Double = 0.4

        public static let standard = Timing()
    }

    public private(set) var step: SipStep = .showContainer
    private let timing: Timing
    private var stepStartedAt: Double
    private var beforeQuarters = 0
    private var holdStart: Double?
    private var lastDrinkingTime: Double?
    private var awayFromMouthSince: Double?

    public init(startedAt: Double, timing: Timing = .standard) {
        self.timing = timing
        self.stepStartedAt = startedAt
    }

    public var wantsJudgement: Bool {
        step == .showContainer || step == .showContainerAgain
    }

    public var isFinished: Bool {
        switch step {
        case .verified, .refused: true
        default: false
        }
    }

    /// Avancement du geste « boire », pour l'interface.
    public var drinkProgress: Double {
        switch step {
        case .showContainer: return 0
        case .drink:
            guard let holdStart, let lastDrinkingTime else { return 0 }
            return min(1, (lastDrinkingTime - holdStart) / timing.holdAtMouth)
        default: return 1
        }
    }

    public mutating func observe(_ frame: SipFrame) {
        guard !isFinished else { return }
        expireIfNeeded(at: frame.time)
        switch step {
        case .drink:
            if frame.drinkingPose {
                let continuing = lastDrinkingTime.map { frame.time - $0 <= timing.gapTolerance } ?? false
                if !continuing || holdStart == nil { holdStart = frame.time }
                lastDrinkingTime = frame.time
                if let holdStart, frame.time - holdStart >= timing.holdAtMouth {
                    enter(.lower, at: frame.time)
                }
            } else if let lastDrinkingTime, frame.time - lastDrinkingTime > timing.gapTolerance {
                holdStart = nil
            }
        case .lower:
            if frame.drinkingPose {
                awayFromMouthSince = nil
            } else {
                let since = awayFromMouthSince ?? frame.time
                awayFromMouthSince = since
                if frame.time - since >= timing.lowerHold {
                    enter(.showContainerAgain, at: frame.time)
                }
            }
        default:
            break
        }
    }

    public mutating func judge(_ verdict: ContainerVerdict, at time: Double) {
        guard !isFinished else { return }
        expireIfNeeded(at: time)
        switch (step, verdict) {
        case (.showContainer, .clearLiquid(let quarters)):
            beforeQuarters = quarters
            enter(.drink, at: time)
        case (.showContainerAgain, .clearLiquid(let quarters)):
            step = .verified(beforeQuarters: beforeQuarters, afterQuarters: quarters)
        case (.showContainerAgain, .emptyContainer):
            step = .verified(beforeQuarters: beforeQuarters, afterQuarters: 0)
        case (.showContainer, .noContainer), (.showContainerAgain, .noContainer):
            break
        case (.showContainer, _), (.showContainerAgain, _):
            step = .refused(Self.refusal(for: verdict))
        default:
            break
        }
    }

    private mutating func enter(_ next: SipStep, at time: Double) {
        step = next
        stepStartedAt = time
    }

    private mutating func expireIfNeeded(at time: Double) {
        let elapsed = time - stepStartedAt
        switch step {
        case .showContainer where elapsed > timing.showContainer:
            step = .refused(.noContainer)
        case .drink where elapsed > timing.drink:
            step = .refused(.noDrinkSeen)
        case .lower where elapsed > timing.lower:
            step = .refused(.notLowered)
        case .showContainerAgain where elapsed > timing.showContainerAgain:
            step = .refused(.containerLost)
        default:
            break
        }
    }

    private static func refusal(for verdict: ContainerVerdict) -> SipRefusal {
        switch verdict {
        case .coloredLiquid: .coloredLiquid
        case .opaqueLiquid: .opaqueLiquid
        case .emptyContainer: .emptyContainer
        case .opaqueContainer: .opaqueContainer
        case .noContainer, .clearLiquid: .noContainer
        }
    }
}
