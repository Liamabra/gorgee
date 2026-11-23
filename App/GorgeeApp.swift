import SwiftUI
import GorgeeCore

@main
struct GorgeeApp: App {
    var body: some Scene {
        MenuBarExtra("Gorgée", systemImage: "drop.fill") {
            Text("Objectif : \(DailyGoal.milliliters(sex: .female, weightKg: 60)) mL")
            Divider()
            Button("Quitter") { NSApp.terminate(nil) }
        }
    }
}
