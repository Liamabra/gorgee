import AppKit
@preconcurrency import AVFoundation
import GorgeeCore
import SwiftUI

/// Petit panneau flottant en haut de l'écran : aperçu caméra et étapes de la preuve.
final class ProofPanelController {
    private var panel: NSPanel?
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        isVisible ? close() : show()
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameTopLeftPoint(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.maxY - 12))
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        if !model.proof.isActive, model.proof.status == .idle || isFinished {
            model.startProof()
        }
    }

    func close() {
        model.proof.cancel()
        panel?.orderOut(nil)
    }

    private var isFinished: Bool {
        if case .finished = model.proof.status { return true }
        return false
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = NSWindow.Level(rawValue: OverlayController.level.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: ProofView(model: model, close: { [weak self] in self?.close() }))
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentView = hosting
        return panel
    }
}

struct ProofView: View {
    let model: AppModel
    let close: () -> Void

    private var proof: ProofController { model.proof }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prouve ta gorgée").font(.title3.bold())

            CameraPreview(session: proof.camera.session)
                .frame(width: 328, height: 184)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                StepRow(title: "Montre ton verre d'eau à la caméra", state: stepState(0))
                StepRow(title: "Bois, tête inclinée", state: stepState(1), progress: proof.drinkProgress)
                StepRow(title: "Repose-le, puis remontre-le", state: stepState(2))
            }

            if proof.gestureOnly {
                Text("Apple Intelligence indisponible : seul le geste est vérifié.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(isSuccess ? .green : .orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Fermer", action: close)
                Spacer()
                if canRetry {
                    Button("Réessayer") { model.startProof() }
                }
                if model.canDeclareManually {
                    Menu("J'ai vraiment bu…") {
                        ForEach([150, 250, 330, 500], id: \.self) { amount in
                            Button("\(amount) mL (1 joker)") {
                                model.declareManually(amount)
                                close()
                            }
                        }
                    }
                    .fixedSize()
                }
            }
        }
        .padding(16)
        .frame(width: 360)
    }

    private enum StepState { case waiting, current, done }

    private func stepState(_ index: Int) -> StepState {
        let current: Int
        switch proof.status {
        case .running(let step), .finished(let step):
            switch step {
            case .showContainer: current = 0
            case .drink: current = 1
            case .lower, .showContainerAgain: current = 2
            case .verified: current = 3
            case .refused: return .waiting
            }
        default:
            current = 0
        }
        if index < current { return .done }
        return index == current ? .current : .waiting
    }

    private var isSuccess: Bool {
        if case .finished(.verified) = proof.status { return true }
        return false
    }

    private var canRetry: Bool {
        if case .finished(.refused) = proof.status { return true }
        return false
    }

    private var statusMessage: LocalizedStringKey? {
        switch proof.status {
        case .idle, .starting: return "La caméra démarre…"
        case .running(.showContainer):
            if proof.lastVerdict == .noContainer { return "Je ne vois pas encore de verre." }
            return nil
        case .running: return nil
        case .cameraDenied:
            return "Gorgée n'a pas accès à la caméra. Autorise-la dans Réglages Système › Confidentialité › Caméra."
        case .noCamera:
            return "Aucune caméra physique disponible. Tu peux déclarer ta gorgée contre un joker."
        case .finished(.verified):
            return "Gorgée validée : \(ProofController.creditedMilliliters) mL. L'eau revient !"
        case .finished(.refused(let reason)):
            return reason.message
        case .finished:
            return nil
        }
    }

    private struct StepRow: View {
        let title: LocalizedStringKey
        let state: StepState
        var progress: Double = 0

        var body: some View {
            HStack(spacing: 8) {
                switch state {
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .current:
                    if progress > 0 {
                        ProgressView(value: progress).progressViewStyle(.circular).controlSize(.small)
                    } else {
                        Image(systemName: "circle.dotted").foregroundStyle(.blue)
                    }
                case .waiting:
                    Image(systemName: "circle").foregroundStyle(.secondary)
                }
                Text(title).foregroundStyle(state == .waiting ? .secondary : .primary)
            }
        }
    }
}

extension SipRefusal {
    var message: LocalizedStringKey {
        switch self {
        case .noContainer: "Je ne vois pas de verre. Montre-le bien à la caméra."
        case .coloredLiquid: "Ce liquide a de la couleur : seule l'eau compte."
        case .opaqueLiquid: "Ce liquide est opaque : seule l'eau compte."
        case .emptyContainer: "Ce verre est vide."
        case .opaqueContainer: "Il faut un verre ou une bouteille transparents."
        case .noDrinkSeen: "Je ne t'ai pas vu boire. Porte le verre à ta bouche, tête inclinée."
        case .notLowered: "Repose ton verre après avoir bu."
        case .containerLost: "Remontre ton verre à la caméra après avoir bu."
        }
    }
}

/// Aperçu de la caméra, en miroir comme une glace.
private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
