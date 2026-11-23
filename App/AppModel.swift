import AppKit
import GorgeeCore
import Observation
import OSLog

/// Relie le moteur de dette aux capteurs (activité), à l'affichage (overlay) et au disque.
@Observable
final class AppModel {
    private(set) var engine: HydrationEngine
    private(set) var hasProfile: Bool
    private(set) var now = Date.now
    private(set) var isUserActive = true
    private(set) var protectionEnabled: Bool

    /// Debug : accélère l'accumulation de la dette.
    var timeScale: Double = 1 {
        didSet { startTicking() }
    }

    /// Debug : raccourci de secours qui masque la sécheresse.
    var overlayHiddenForDebug = false {
        didSet { refreshOverlay() }
    }

    @ObservationIgnored let overlay = OverlayController()
    @ObservationIgnored private let files: AppFiles
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var quitAuthorized = false
    @ObservationIgnored private let log = Logger(subsystem: "app.gorgee.Gorgee", category: "model")

    static let defaultSettings = HydrationSettings(sex: .female, weightKg: 60)
    static let tickInterval: Duration = .seconds(5)

    init(files: AppFiles = AppFiles()) {
        self.files = files
        let savedSettings = files.settings.load()
        let settings = savedSettings ?? Self.defaultSettings
        let state = files.state.load()
            ?? .fresh(day: Calendar.current.startOfDay(for: .now), jokers: settings.jokersPerDay)
        engine = HydrationEngine(settings: settings, state: state)
        hasProfile = savedSettings != nil
        protectionEnabled = Protection.isEnabled
    }

    func start() {
        tick()
        startTicking()
    }

    // MARK: - Lecture

    var settings: HydrationSettings { engine.settings }
    var debtML: Int { Int(engine.state.debtML.rounded()) }
    var debtFraction: Double { min(1, engine.state.debtML / max(1, settings.unusableML)) }
    var drankTodayML: Int { engine.state.drankTodayML }
    var jokersLeft: Int { engine.state.jokersLeft }
    var pausedUntil: Date? { engine.isPaused(at: now) ? engine.state.pausedUntil : nil }
    var canUseJoker: Bool { jokersLeft > 0 && !engine.isPaused(at: now) }
    var canQuit: Bool { !protectionEnabled || quitAuthorized }

    var displaySeverity: Double {
        #if DEBUG
        if let forced = DebugOptions.forcedSeverity { return forced }
        if overlayHiddenForDebug { return 0 }
        #endif
        return engine.displaySeverity(at: now, cameraBusy: false)
    }

    var phase: DroughtPhase {
        if !engine.isInWindow(now) { return .outsideHours }
        if engine.isPaused(at: now) { return .paused }
        return DroughtPhase(severity: engine.severity(at: now))
    }

    // MARK: - Actions

    func updateSettings(_ change: (inout HydrationSettings) -> Void) {
        var settings = engine.settings
        change(&settings)
        engine.settings = settings
        hasProfile = true
        do { try files.settings.save(settings) } catch { log.error("Réglages non sauvegardés : \(error)") }
        refreshOverlay()
    }

    func recordDrink(_ milliliters: Int, source: DrinkSource) {
        let before = displaySeverity
        let event = engine.recordDrink(milliliters, source: source, at: .now)
        do { try files.drinks.append(event) } catch { log.error("Gorgée non journalisée : \(error)") }
        persistState()
        now = .now
        overlay.wash(from: before, to: displaySeverity)
    }

    func usePauseJoker() {
        guard engine.usePauseJoker(at: .now) else { return }
        persistState()
        now = .now
        refreshOverlay()
    }

    func openSettings() {
        SettingsWindowController.shared.show(model: self)
    }

    // MARK: - Quitter et protection

    func authorizeSystemQuit() {
        quitAuthorized = true
    }

    func quit() {
        quitAuthorized = true
        persistState()
        NSApp.terminate(nil)
    }

    /// Active la relance automatique ; l'app redémarre sous launchd.
    func enableProtection() {
        Protection.isEnabled = true
        protectionEnabled = true
        persistState()
        if !LaunchAgent.isRunningAsAgent, LaunchAgent.handOver() {
            exit(0)
        }
    }

    /// Retire la relance automatique et ferme l'app.
    func disableProtectionAndQuit() {
        Protection.isEnabled = false
        quitAuthorized = true
        persistState()
        LaunchAgent.uninstall()
        NSApp.terminate(nil)
    }

    func persistState() {
        do { try files.state.save(engine.state) } catch { log.error("État non sauvegardé : \(error)") }
    }

    // MARK: - Horloge

    private func tick() {
        now = .now
        isUserActive = ActivityMonitor.isUserActive()
        engine.tick(now: now, isActive: isUserActive, timeScale: timeScale)
        persistState()
        refreshOverlay()
    }

    private func startTicking() {
        tickTask?.cancel()
        let interval = timeScale > 1 ? Duration.seconds(1) : Self.tickInterval
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                self?.tick()
            }
        }
    }

    private func refreshOverlay() {
        overlay.show(severity: displaySeverity)
    }
}

enum DroughtPhase {
    case outsideHours, paused, intact, drying, drought, unusable

    init(severity: Double) {
        switch severity {
        case ...0: self = .intact
        case ..<0.5: self = .drying
        case ..<1: self = .drought
        default: self = .unusable
        }
    }

    var symbolName: String {
        switch self {
        case .outsideHours: "moon.zzz"
        case .paused: "pause.circle"
        case .intact: "drop.fill"
        case .drying: "drop.halffull"
        case .drought: "drop"
        case .unusable: "drop.triangle"
        }
    }
}

/// Fichiers de données ; le build Debug a son propre dossier pour ne pas toucher à la vraie dette.
struct AppFiles {
    let directory: URL

    init(directory: URL = AppFiles.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        #if DEBUG
        URL.applicationSupportDirectory.appending(path: "Gorgee-Debug")
        #else
        URL.applicationSupportDirectory.appending(path: "Gorgee")
        #endif
    }

    var settings: JSONFileStore<HydrationSettings> { JSONFileStore(url: directory.appending(path: "settings.json")) }
    var state: JSONFileStore<HydrationState> { JSONFileStore(url: directory.appending(path: "state.json")) }
    var drinks: DrinkLog { DrinkLog(url: directory.appending(path: "drinks.jsonl")) }
}

enum Protection {
    private static let key = "protectionEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    #if DEBUG
    private static let defaultValue = false
    #else
    private static let defaultValue = true
    #endif
}

#if DEBUG
enum DebugOptions {
    /// `-GorgeeDebugSeverity 0.6` au lancement force la sécheresse affichée.
    static var forcedSeverity: Double? {
        UserDefaults.standard.string(forKey: "GorgeeDebugSeverity").flatMap(Double.init)
    }
}
#endif
