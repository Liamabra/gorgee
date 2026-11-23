import AppKit
import GorgeeCore
import Observation
import SwiftUI

@Observable
final class OverlayState {
    var severity: Double = 0
    var wash: Wash?
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
}

/// Une fenêtre transparente par écran, au-dessus de tout (plein écran compris), que les clics traversent.
final class OverlayController {
    /// Au niveau de la barre de menus : au-dessus des apps, du Dock et des panneaux,
    /// sous le menu de Gorgée et ses fenêtres.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue)

    let state = OverlayState()
    private var windows: [NSWindow] = []
    private var appliedBlurRadius = -1
    private var washEnd: Task<Void, Never>?

    init() {
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
            return
        }
        if windows.isEmpty { rebuildWindows() }
        for window in windows where !window.isVisible {
            window.orderFrontRegardless()
        }
        applyBlur()
    }

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map(makeWindow)
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
        let hosting = NSHostingView(rootView: DroughtView(state: state, tiling: tiling))
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setFrame(screen.frame, display: false)
        return window
    }

    private func applyBlur() {
        let radius = Self.blurRadius(for: state.severity)
        guard radius != appliedBlurRadius else { return }
        appliedBlurRadius = radius
        windows.forEach { WindowBlur.apply(radius: radius, to: $0) }
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
