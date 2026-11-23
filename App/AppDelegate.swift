import AppKit
import Carbon.HIToolbox
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var hotKeys: [HotKey] = []
    private let log = Logger(subsystem: "app.gorgee.Gorgee", category: "lifecycle")

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        PreviewRenderer.runIfRequested()
        #endif

        if model.protectionEnabled, !LaunchAgent.isRunningAsAgent {
            // Lancée à la main : on passe le relais à l'instance gérée par launchd, qui se relance si on la tue.
            if LaunchAgent.handOver() {
                exit(0)
            }
            log.error("Relais au LaunchAgent impossible : Gorgée tourne sans relance automatique.")
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main
        ) { [model] _ in
            MainActor.assumeIsolated { model.authorizeSystemQuit() }
        }

        model.start()
        if !model.hasProfile {
            SettingsWindowController.shared.show(model: model)
        }

        #if DEBUG
        let emergency = HotKey(keyCode: kVK_ANSI_D, modifiers: controlKey | optionKey | shiftKey) { [model] in
            model.overlayHiddenForDebug.toggle()
        }
        hotKeys.append(emergency)
        #endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.canQuit ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.persistState()
    }
}
