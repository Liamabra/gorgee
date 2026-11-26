import GorgeeCore
import SwiftUI

struct MenuView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Gorgée").font(.headline)
                Spacer()
                Text(model.phase.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Dette : \(model.debtML) mL")
                ProgressView(value: model.debtFraction)
                    .tint(model.phase.tint)
            }

            Text("Bu aujourd'hui : \(Liters.format(model.drankTodayML)) sur \(Liters.format(model.settings.dailyGoalML))")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Jokers : \(model.jokersLeft)")
                    Spacer()
                    Button("Pause \(Int(model.settings.jokerPauseMinutes)) min") {
                        model.usePauseJoker()
                    }
                    .disabled(!model.canUseJoker)
                }
                if let pausedUntil = model.pausedUntil {
                    Text("En pause jusqu'à \(pausedUntil, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Button {
                    model.showProofPanel()
                } label: {
                    Label("Prouver une gorgée", systemImage: "camera")
                }
                Text("Raccourci : ⌃⌥G")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Menu("Bu ailleurs…") {
                    ForEach([150, 250, 330, 500], id: \.self) { amount in
                        Button("\(amount) mL") { model.recordDrink(amount, source: .elsewhere) }
                    }
                }
                .fixedSize()
                Text("Compte dans ton total, pas dans la dette.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.cameraMonitor.isBusy {
                    Text("Visio en cours : la sécheresse attend.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !model.screenCaptureAllowed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Déformation de l'écran désactivée").font(.caption.bold())
                    Text("Autorise l'enregistrement de l'écran pour que la sécheresse avale vraiment ton écran. Les images ne sont ni gardées ni envoyées.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Autoriser…") { model.openScreenCaptureSettings() }
                        Button("Redémarrer Gorgée") { model.restart() }
                    }
                }
            }

            Divider()

            HStack {
                Button("Historique…") { model.openHistory() }
                Button("Réglages…") { model.openSettings() }
                Spacer()
                if model.protectionEnabled {
                    Button("Quitter…") { model.openSettings() }
                } else {
                    Button("Quitter") { model.quit() }
                }
            }

            #if DEBUG
            DebugMenuSection(model: model)
            #endif
        }
        .padding(14)
        .frame(width: 300)
    }
}

extension DroughtPhase {
    var label: LocalizedStringKey {
        switch self {
        case .outsideHours: "Hors de ta plage horaire"
        case .paused: "En pause"
        case .intact: "Écran intact"
        case .drying: "Ça commence à sécher"
        case .drought: "Sécheresse"
        case .unusable: "Écran inutilisable"
        }
    }

    var tint: Color {
        switch self {
        case .outsideHours, .paused, .intact: .blue
        case .drying: .orange
        case .drought, .unusable: .brown
        }
    }
}

enum Liters {
    static func format(_ milliliters: Int) -> String {
        let liters = (Double(milliliters) / 1000).formatted(.number.precision(.fractionLength(2)))
        return "\(liters) L"
    }
}

#if DEBUG
private struct DebugMenuSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(verbatim: "Debug · actif : \(model.isUserActive ? "oui" : "non")")
                .font(.caption.bold())
            Picker(selection: $model.timeScale) {
                Text(verbatim: "×1").tag(1.0)
                Text(verbatim: "×60").tag(60.0)
                Text(verbatim: "×600").tag(600.0)
            } label: {
                Text(verbatim: "Vitesse")
            }
            .pickerStyle(.segmented)
            Toggle(isOn: $model.overlayHiddenForDebug) {
                Text(verbatim: "Masquer la sécheresse (⌃⌥⇧D)")
            }
        }
        .font(.caption)
    }
}
#endif
