import SwiftUI

@main
struct GorgeeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: delegate.model)
        } label: {
            Image(systemName: delegate.model.phase.symbolName)
        }
        .menuBarExtraStyle(.window)
    }
}
