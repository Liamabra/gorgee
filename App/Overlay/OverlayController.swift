import AppKit
import GorgeeCore
import Observation
import OSLog
import SwiftUI

@Observable
final class OverlayState {
    var severity: Double = 0
    var wash: Wash?
    /// La poussière ne s'anime que si quelqu'un regarde : pas d'animation pendant l'absence.
    var animating = true
    /// Vrai quand l'écran capturé est réellement déformé ; sinon l'argile est peinte par-dessus.
    var deformationActive = false
}

/// L'eau qui ruisselle après une gorgée, de l'ancienne sévérité à la nouvelle.
struct Wash: Equatable {
    static let duration: TimeInterval = 2.4

    var start: Date
    var from: Double
    var to: Double

    func progress(at date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(start) / Self.duration))
    }

    /// La sécheresse recule vite puis ralentit, pendant que l'eau ruisselle.
    func severity(at date: Date) -> Double {
        let eased = 1 - pow(1 - progress(at: date), 3)
        return from + (to - from) * eased
    }
}

/// Une fenêtre transparente par écran, au-dessus de tout (plein écran compris), que les clics traversent.
final class OverlayController {
    /// Au niveau de la barre de menus : au-dessus des apps, du Dock et des panneaux,
    /// sous le menu de Gorgée et ses fenêtres.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue)

    let state = OverlayState()
    private let log = Logger(subsystem: "app.gorgee.Gorgee", category: "overlay")
    private var windows: [NSWindow] = []
    private var distortionViews: [DistortionView] = []
    private var appliedBlurRadius = -1
    private var washEnd: Task<Void, Never>?
    private let capture = ScreenCaptureManager()
    private let renderer = DistortionRenderer()

    init() {
        capture.onReady = { [weak self] in self?.setDeformation(active: true) }
        capture.onFailure = { [weak self] in self?.setDeformation(active: false) }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        }
    }

    func show(severity: Double) {
        guard severity != state.severity else { return }
        state.severity = severity
        syncWindows()
    }

    func setAnimating(_ animating: Bool) {
        guard state.animating != animating else { return }
        state.animating = animating
        // Personne ne regarde : la copie déformée se rafraîchit à peine.
        distortionViews.forEach { $0.preferredFramesPerSecond = animating ? 30 : 4 }
    }

    /// La déformation réelle est possible : Metal disponible et enregistrement de l'écran autorisé.
    var canDeform: Bool { renderer != nil && ScreenCaptureManager.hasPermission }

    private func setDeformation(active: Bool) {
        state.deformationActive = active
        distortionViews.forEach { $0.isPaused = !(active && isVisible) }
        appliedBlurRadius = -1
        applyBlur()
    }

    func wash(from: Double, to: Double) {
        state.severity = to
        state.wash = Wash(start: .now, from: from, to: to)
        syncWindows()
        washEnd?.cancel()
        washEnd = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Wash.duration))
            guard !Task.isCancelled else { return }
            self?.state.wash = nil
            self?.syncWindows()
        }
    }

    private var isVisible: Bool { state.severity > 0 || state.wash != nil }

    private func syncWindows() {
        guard isVisible else {
            windows.forEach { $0.orderOut(nil) }
            capture.stop()
            setDeformation(active: false)
            return
        }
        if windows.isEmpty { rebuildWindows() }
        for window in windows where !window.isVisible {
            window.orderFrontRegardless()
        }
        if canDeform, !capture.isRunning { capture.start() }
        applyBlur()
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        distortionViews = []
        let restartCapture = capture.isRunning
        capture.stop()
        setDeformation(active: false)
        windows = NSScreen.screens.map(makeWindow)
        if restartCapture, canDeform { capture.start() }
        appliedBlurRadius = -1
        if isVisible {
            windows.forEach { $0.orderFrontRegardless() }
            applyBlur()
        }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = Self.level
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none

        let tiling = MudTiling(width: screen.frame.width, height: screen.frame.height, seed: UInt64(screen.displayID))
        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        let container = NSView(frame: bounds)
        // Dessous : la copie déformée de l'écran ; dessus : poussière, eau, ou argile peinte en repli.
        let displayID = screen.displayID
        if let renderer, let distortion = DistortionView(
            frame: bounds, renderer: renderer, tiling: tiling, state: state,
            frameSource: { [weak self] in self?.capture.latestFrame(for: displayID) }
        ) {
            distortion.autoresizingMask = [.width, .height]
            container.addSubview(distortion)
            distortionViews.append(distortion)
        }
        let hosting = NSHostingView(rootView: DroughtView(state: state, tiling: tiling))
        hosting.sizingOptions = []
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        window.contentView = container
        window.setFrame(screen.frame, display: false)
        return window
    }

    private func applyBlur() {
        // La déformation réelle brouille déjà le contenu : pas de flou par-dessus.
        let radius = state.deformationActive ? 0 : Self.blurRadius(for: state.severity)
        guard radius != appliedBlurRadius else { return }
        appliedBlurRadius = radius
        for window in windows {
            let applied = WindowBlur.apply(radius: radius, to: window)
            log.notice("Flou \(radius) sur la fenêtre \(window.windowNumber) : \(applied ? "appliqué" : "refusé", privacy: .public)")
        }
    }

    /// Le flou n'arrive qu'en deuxième moitié de sécheresse, jusqu'à rendre le texte illisible.
    static func blurRadius(for severity: Double) -> Int {
        severity <= 0.35 ? 0 : Int(((severity - 0.35) / 0.65 * 20).rounded())
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 1
    }
}
