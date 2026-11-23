import AppKit
import GorgeeCore
import UniformTypeIdentifiers
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
    /// Toutes les gorgées, chargées depuis le journal puis complétées au fil de l'eau.
    private(set) var drinkEvents: [DrinkEvent]

    /// Debug : accélère l'accumulation de la dette.
    var timeScale: Double = 1 {
        didSet { startTicking() }
    }

    /// Debug : raccourci de secours qui masque la sécheresse.
    var overlayHiddenForDebug = false {
        didSet { refreshOverlay() }
    }

    let proof = ProofController()
    let cameraMonitor = CameraBusyMonitor()

    @ObservationIgnored let overlay = OverlayController()
    @ObservationIgnored private(set) var proofPanel: ProofPanelController!
    @ObservationIgnored private var lastPhase: DroughtPhase?
    @ObservationIgnored private var savedSettings: HydrationSettings
    /// Première configuration : les réglages s'appliquent tout de suite, ensuite seulement le lendemain.
    private(set) var isOnboarding: Bool
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
        // Calendrier qui suit les changements de fuseau horaire.
        let calendar = Calendar.autoupdatingCurrent
        let state = files.state.load() ?? .fresh(for: .now, calendar: calendar, jokers: settings.jokersPerDay)
        engine = HydrationEngine(settings: settings, state: state, calendar: calendar)
        self.savedSettings = settings
        isOnboarding = savedSettings == nil
        hasProfile = savedSettings != nil
        protectionEnabled = Protection.isEnabled
        drinkEvents = (try? files.drinks.readAll()) ?? []
        #if DEBUG
        if let scale = DebugOptions.timeScale { timeScale = scale }
        #endif
        proofPanel = ProofPanelController(model: self)
        proof.credit = { [weak self] before, after in
            SipCredit.milliliters(
                capacity: self?.settings.containerCapacityML ?? 250,
                beforeQuarters: before,
                afterQuarters: after
            )
        }
        proof.onVerified = { [weak self] milliliters in self?.recordDrink(milliliters, source: .camera) }
        proof.onRefused = { [weak self] in self?.recordRefusal() }
    }

    func start() {
        tick()
        startTicking()
    }

    // MARK: - Lecture

    var settings: HydrationSettings { engine.settings }
    var debtML: Int { Int(engine.state.debtML.rounded()) }
    var debtFraction: Double { min(1, engine.state.debtML / max(1, settings.unusableML)) }
    /// Calculé depuis le journal, la seule source de vérité des gorgées.
    var drankTodayML: Int { HydrationHistory(events: drinkEvents, calendar: engine.calendar).total(on: now) }

    /// Les réglages tels qu'ils seront demain (en attente) ou tels qu'ils sont.
    var editedSettings: HydrationSettings { engine.state.pendingSettings ?? engine.settings }
    var hasPendingSettings: Bool { engine.state.pendingSettings != nil }
    var jokersLeft: Int { engine.state.jokersLeft }
    var pausedUntil: Date? { engine.isPaused(at: now) ? engine.state.pausedUntil : nil }
    var canUseJoker: Bool { jokersLeft > 0 && !engine.isPaused(at: now) }
    var canQuit: Bool { !protectionEnabled || quitAuthorized }

    /// Sans caméra utilisable, ou après 3 vrais refus, une gorgée peut se déclarer contre un joker.
    var canDeclareManually: Bool {
        let cameraAvailable = CameraController.hasAllowedCamera && !proof.proofImpossible
        return engine.canDeclareManually(at: now, cameraAvailable: cameraAvailable)
    }

    var displaySeverity: Double {
        #if DEBUG
        if let forced = DebugOptions.forcedSeverity { return forced }
        if overlayHiddenForDebug { return 0 }
        #endif
        return engine.displaySeverity(at: now, cameraBusy: cameraMonitor.isBusy)
    }

    var phase: DroughtPhase {
        if !engine.isInWindow(now) { return .outsideHours }
        if engine.isPaused(at: now) { return .paused }
        return DroughtPhase(severity: engine.severity(at: now))
    }

    // MARK: - Actions

    /// Modifie les réglages. Hors première configuration, ils ne s'appliquent que le lendemain :
    /// on ne desserre pas l'étau en pleine sécheresse.
    func updateSettings(_ change: (inout HydrationSettings) -> Void) {
        var settings = editedSettings
        change(&settings)
        if isOnboarding {
            engine.settings = settings
        } else {
            engine.scheduleSettings(settings)
        }
        hasProfile = true
        persistState()
        refreshOverlay()
    }

    func finishOnboarding() {
        isOnboarding = false
    }

    func recordDrink(_ milliliters: Int, source: DrinkSource) {
        let before = displaySeverity
        let event = engine.recordDrink(milliliters, source: source, at: .now)
        journal(event)
        persistState()
        now = .now
        // « Bu ailleurs » ne rembourse pas la dette : pas d'eau qui ruisselle.
        if source != .elsewhere {
            overlay.wash(from: before, to: displaySeverity)
        }
    }

    private func journal(_ event: DrinkEvent) {
        drinkEvents.append(event)
        do { try files.drinks.append(event) } catch { log.error("Gorgée non journalisée : \(error)") }
    }

    func openHistory() {
        HistoryWindowController.shared.show(model: self)
    }

    /// Exporte l'historique en CSV ou en JSON, à l'endroit choisi par l'utilisateur.
    func exportHistory(as type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = type == .json ? "gorgee.json" : "gorgee.csv"
        panel.level = NSWindow.Level(rawValue: OverlayController.level.rawValue + 2)
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = type == .json
                ? try DrinkExport.json(drinkEvents)
                : Data(DrinkExport.csv(drinkEvents).utf8)
            try data.write(to: url, options: .atomic)
        } catch {
            log.error("Export impossible : \(error)")
        }
    }

    func startProof() {
        proof.begin()
    }

    func showProofPanel() {
        proofPanel.show()
    }

    func toggleProofPanel() {
        proofPanel.toggle()
    }

    func declareManually(_ milliliters: Int) {
        let before = displaySeverity
        let cameraAvailable = CameraController.hasAllowedCamera && !proof.proofImpossible
        guard let event = engine.declareManually(milliliters, at: .now, cameraAvailable: cameraAvailable) else { return }
        journal(event)
        persistState()
        now = .now
        overlay.wash(from: before, to: displaySeverity)
    }

    /// Un refus ne compte que si un récipient a été vu : mimer ou laisser filer la caméra ne débloque rien.
    private func recordRefusal() {
        guard case .finished(.refused(let reason)) = proof.status, reason != .noContainer else { return }
        engine.recordRefusal(at: .now)
        persistState()
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
        // Les réglages en attente deviennent actifs au changement de jour : on les enregistre alors.
        if engine.settings != savedSettings {
            do {
                try files.settings.save(engine.settings)
                savedSettings = engine.settings
            } catch {
                log.error("Réglages non sauvegardés : \(error)")
            }
        }
    }

    // MARK: - Horloge

    private func tick() {
        now = .now
        isUserActive = ActivityMonitor.isUserActive()
        #if DEBUG
        if DebugOptions.forceActive { isUserActive = true }
        #endif
        engine.tick(now: now, isActive: isUserActive, timeScale: timeScale)
        persistState()
        overlay.setAnimating(isUserActive)
        refreshOverlay()
        openProofIfDroughtWorsened()
    }

    /// La caméra s'ouvre d'elle-même quand la sécheresse franchit un palier (pas au lancement).
    private func openProofIfDroughtWorsened() {
        let current = phase
        defer { lastPhase = current }
        guard let previous = lastPhase, current.rank > previous.rank, current.rank > 0,
              !cameraMonitor.isBusy, !proofPanel.isVisible
        else { return }
        proofPanel.show(takeFocus: false)
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

    /// Gravité croissante de la sécheresse ; 0 hors sécheresse.
    var rank: Int {
        switch self {
        case .outsideHours, .paused, .intact: 0
        case .drying: 1
        case .drought: 2
        case .unusable: 3
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

    /// `-GorgeeForceActive YES` : considère l'utilisateur actif même sans saisie (tests automatisés).
    static var forceActive: Bool {
        UserDefaults.standard.bool(forKey: "GorgeeForceActive")
    }

    /// `-GorgeeTimeScale 60` au lancement accélère la dette.
    static var timeScale: Double? {
        UserDefaults.standard.string(forKey: "GorgeeTimeScale").flatMap(Double.init)
    }
}
#endif
