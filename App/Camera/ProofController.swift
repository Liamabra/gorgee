import AppKit
import GorgeeCore
import GorgeeDetection
import Observation
import OSLog

/// Une preuve de gorgée devant la caméra : du démarrage de la caméra au verdict.
@Observable
final class ProofController {
    enum Status: Equatable {
        case idle
        case starting
        case running(SipStep)
        case finished(SipStep)
        case cameraDenied
        case noCamera
        /// Le modèle d'Apple ne répond pas : la preuve est impossible, pas refusée.
        case judgeUnavailable
    }

    /// Filet de sécurité si la caméra cesse d'envoyer des images.
    static let maximumDuration: Duration = .seconds(90)
    /// Sans première image dans ce délai, la caméra est considérée indisponible.
    static let firstFrameTimeout: Duration = .seconds(8)

    private(set) var status: Status = .idle
    private(set) var drinkProgress = 0.0
    private(set) var lastVerdict: ContainerVerdict?
    /// Volume déclaré pour la dernière preuve validée.
    private(set) var creditedMilliliters = 0
    /// Preuve validée : on attend que l'utilisateur dise combien il a bu.
    private(set) var awaitingAmount = false
    /// Sans Apple Intelligence, seul le geste est vérifié ; réévalué à chaque preuve.
    private(set) var gestureOnly = !GlassJudge.isAvailable

    @ObservationIgnored let camera = CameraController()
    @ObservationIgnored var onVerified: (Int) -> Void = { _ in }
    @ObservationIgnored var onRefused: () -> Void = {}
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "app.gorgee.Gorgee", category: "proof")
    @ObservationIgnored private var framesReceived = 0

    var isActive: Bool {
        switch status {
        case .starting, .running: true
        default: false
        }
    }

    func begin() {
        guard !isActive else { return }
        drinkProgress = 0
        lastVerdict = nil
        awaitingAmount = false
        framesReceived = 0
        gestureOnly = !GlassJudge.isAvailable
        status = .starting
        task = Task { [weak self] in await self?.run() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        camera.stop()
        awaitingAmount = false
        status = .idle
    }

    /// La quantité bue, choisie par l'utilisateur après une preuve validée.
    func confirmAmount(_ milliliters: Int) {
        guard awaitingAmount else { return }
        awaitingAmount = false
        creditedMilliliters = milliliters
        onVerified(milliliters)
    }

    /// La caméra ou le juge manquent : déclarer à la main (contre un joker) devient possible.
    var proofImpossible: Bool {
        switch status {
        case .cameraDenied, .noCamera, .judgeUnavailable: true
        default: false
        }
    }

    private func run() async {
        let frames: AsyncStream<CameraFrame>
        do {
            frames = try await camera.start()
        } catch CameraError.denied {
            status = .cameraDenied
            return
        } catch {
            log.error("Caméra indisponible : \(error)")
            status = .noCamera
            return
        }

        let judge = Self.makeJudge(gestureOnly: gestureOnly)
        let (updates, sink) = AsyncStream.makeStream(of: ProofUpdate.self)
        let worker = Task.detached {
            var runner: ProofRunner?
            for await frame in frames {
                let active = runner ?? ProofRunner(startedAt: frame.time, judge: judge)
                runner = active
                let step = await active.process(frame.pixelBuffer, at: frame.time)
                sink.yield(ProofUpdate(
                    step: step,
                    progress: active.machine.drinkProgress,
                    verdict: active.lastVerdict,
                    judgeFailures: active.judgeFailures
                ))
                if active.machine.isFinished || Task.isCancelled { break }
            }
            sink.finish()
        }
        let watchdog = Task {
            try? await Task.sleep(for: Self.maximumDuration)
            worker.cancel()
            sink.finish()
        }
        let firstFrameWatch = Task { [weak self] in
            try? await Task.sleep(for: Self.firstFrameTimeout)
            guard !Task.isCancelled, self?.framesReceived == 0 else { return }
            worker.cancel()
            sink.finish()
        }

        var finalStep = SipStep.showContainer
        var judgeFailures = 0
        for await update in updates {
            guard !Task.isCancelled else { break }
            framesReceived += 1
            judgeFailures = update.judgeFailures
            finalStep = update.step
            drinkProgress = update.progress
            lastVerdict = update.verdict
            status = .running(update.step)
        }
        worker.cancel()
        watchdog.cancel()
        firstFrameWatch.cancel()
        camera.stop()
        guard !Task.isCancelled else { return }

        if framesReceived == 0 {
            status = .noCamera
            return
        }
        if judgeFailures > 0, lastVerdict == nil {
            log.error("Le juge d'images a échoué \(judgeFailures) fois sans verdict.")
            status = .judgeUnavailable
            return
        }

        // Images coupées avant la fin : on refuse sur l'étape où l'on s'est arrêté.
        switch finalStep {
        case .showContainer: finalStep = .refused(.noContainer)
        case .drink: finalStep = .refused(.noDrinkSeen)
        case .lower: finalStep = .refused(.notLowered)
        case .showContainerAgain: finalStep = .refused(.containerLost)
        case .verified, .refused: break
        }
        status = .finished(finalStep)
        if case .verified = finalStep {
            // La caméra a vérifié qu'il s'agit d'eau ; la quantité est déclarée (lecture du niveau trop imprécise).
            awaitingAmount = true
        } else {
            onRefused()
        }
    }

    /// Sans Apple Intelligence, seul le geste est vérifié : tout récipient montré est accepté.
    nonisolated private static func makeJudge(gestureOnly: Bool) -> @Sendable (CVPixelBuffer) async throws -> ContainerVerdict {
        if gestureOnly {
            return { _ in .clearLiquid(fillQuarters: 4) }
        }
        let judge = GlassJudge()
        return { pixelBuffer in try await judge.judge(pixelBuffer) }
    }
}

nonisolated private struct ProofUpdate: Sendable {
    var step: SipStep
    var progress: Double
    var verdict: ContainerVerdict?
    var judgeFailures: Int
}
