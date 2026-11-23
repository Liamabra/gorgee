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
    }

    /// Filet de sécurité si la caméra cesse d'envoyer des images.
    static let maximumDuration: Duration = .seconds(90)

    private(set) var status: Status = .idle
    private(set) var drinkProgress = 0.0
    private(set) var lastVerdict: ContainerVerdict?
    /// Volume crédité par la dernière preuve validée.
    private(set) var creditedMilliliters = 0
    let gestureOnly = !GlassJudge.isAvailable

    @ObservationIgnored let camera = CameraController()
    /// Volume crédité pour des niveaux avant et après donnés, en quarts.
    @ObservationIgnored var credit: (Int, Int) -> Int = { _, _ in 0 }
    @ObservationIgnored var onVerified: (Int) -> Void = { _ in }
    @ObservationIgnored var onRefused: () -> Void = {}
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(subsystem: "app.gorgee.Gorgee", category: "proof")

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
        status = .starting
        task = Task { [weak self] in await self?.run() }
    }

    func cancel() {
        task?.cancel()
        task = nil
        camera.stop()
        if isActive { status = .idle }
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
                sink.yield(ProofUpdate(step: step, progress: active.machine.drinkProgress, verdict: active.lastVerdict))
                if active.machine.isFinished || Task.isCancelled { break }
            }
            sink.finish()
        }
        let watchdog = Task {
            try? await Task.sleep(for: Self.maximumDuration)
            worker.cancel()
            sink.finish()
        }

        var finalStep = SipStep.showContainer
        for await update in updates {
            guard !Task.isCancelled else { break }
            finalStep = update.step
            drinkProgress = update.progress
            lastVerdict = update.verdict
            status = .running(update.step)
        }
        worker.cancel()
        watchdog.cancel()
        camera.stop()
        guard !Task.isCancelled else { return }

        // Images coupées avant la fin : on refuse sur l'étape où l'on s'est arrêté.
        switch finalStep {
        case .showContainer: finalStep = .refused(.noContainer)
        case .drink: finalStep = .refused(.noDrinkSeen)
        case .lower: finalStep = .refused(.notLowered)
        case .showContainerAgain: finalStep = .refused(.containerLost)
        case .verified, .refused: break
        }
        status = .finished(finalStep)
        if case .verified(let before, let after) = finalStep {
            creditedMilliliters = credit(before, after)
            onVerified(creditedMilliliters)
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
}
