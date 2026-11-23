import CoreVideo
import GorgeeCore

/// Une preuve de gorgée en cours : chaque image passe par Vision, le juge regarde le verre quand il le faut.
///
/// Sert à l'identique pour la caméra en direct et pour les clips rejoués dans les tests.
public final class ProofRunner {
    /// Intervalle minimal entre deux appels au juge, qui prend environ une seconde.
    public static let judgementInterval = 1.2

    public private(set) var machine: SipStateMachine
    public private(set) var lastVerdict: ContainerVerdict?
    private var poseDetector = DrinkingPoseDetector()
    private let analyzer = FrameAnalyzer()
    private let judge: (CVPixelBuffer) async throws -> ContainerVerdict
    private var lastJudgementAt = -Double.infinity

    public init(startedAt: Double, judge: @escaping (CVPixelBuffer) async throws -> ContainerVerdict = GlassJudge().judge) {
        machine = SipStateMachine(startedAt: startedAt)
        self.judge = judge
    }

    public var step: SipStep { machine.step }

    @discardableResult
    public func process(_ pixelBuffer: CVPixelBuffer, at time: Double) async -> SipStep {
        guard !machine.isFinished else { return machine.step }
        let snapshot = (try? await analyzer.analyze(pixelBuffer))
            ?? PoseSnapshot(mouth: nil, faceWidth: nil, pitchDegrees: nil, handPoints: [])
        let drinking = poseDetector.evaluate(snapshot, at: time)
        machine.observe(SipFrame(time: time, drinkingPose: drinking))

        if machine.wantsJudgement, time - lastJudgementAt >= Self.judgementInterval {
            lastJudgementAt = time
            let verdict = (try? await judge(pixelBuffer)) ?? .noContainer
            lastVerdict = verdict
            machine.judge(verdict, at: time)
        }
        return machine.step
    }
}
