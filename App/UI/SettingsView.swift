import AppKit
import GorgeeCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel
    @State private var typedPhrase = ""

    var body: some View {
        Form {
            Section("Profil") {
                Picker("Sexe", selection: setting(\.sex)) {
                    Text("Femme").tag(Sex.female)
                    Text("Homme").tag(Sex.male)
                }
                Stepper("Poids : \(Int(model.settings.weightKg)) kg", value: setting(\.weightKg), in: 30...200, step: 1)
                LabeledContent("Objectif du jour", value: Liters.format(model.settings.dailyGoalML))
            }

            Section("Plage horaire") {
                Picker("Début", selection: startHour) {
                    ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) }
                }
                Picker("Fin", selection: endHour) {
                    ForEach(1...24, id: \.self) { Text("\($0) h").tag($0) }
                }
                LabeledContent("Rythme", value: String(localized: "\(Int(model.settings.accrualPerHourML.rounded())) mL par heure active"))
            }

            Section("Sécheresse") {
                Stepper("Premiers signes à \(Int(model.settings.firstSignsML)) mL", value: firstSigns, in: 50...2950, step: 50)
                Stepper("Inutilisable à \(Int(model.settings.unusableML)) mL", value: unusable, in: 100...3000, step: 50)
            }

            Section("Protection") {
                Toggle("Relance automatique si on ferme Gorgée", isOn: protection)
                    .disabled(model.protectionEnabled)
                Text("Gorgée se lance aussi à l'ouverture de session. Pour la désactiver, passe par « Quitter Gorgée ».")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quitter Gorgée") {
                if model.protectionEnabled {
                    Text("Recopie cette phrase pour pouvoir quitter :")
                    Text(Self.quitPhrase).italic()
                    TextField("Phrase", text: $typedPhrase)
                    HStack {
                        Button("Quitter") { model.quit() }
                        Spacer()
                        Button("Désactiver la protection et quitter") { model.disableProtectionAndQuit() }
                    }
                    .disabled(!phraseMatches)
                } else {
                    Button("Quitter Gorgée") { model.quit() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    static var quitPhrase: String {
        String(localized: "Je bois de l'eau, je ne fuis pas.")
    }

    private var phraseMatches: Bool {
        normalized(typedPhrase) == normalized(Self.quitPhrase)
    }

    private func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "’", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .lowercased()
    }

    // MARK: - Liaisons vers les réglages

    private func setting<Value>(_ keyPath: WritableKeyPath<HydrationSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { value in model.updateSettings { $0[keyPath: keyPath] = value } }
        )
    }

    private var startHour: Binding<Int> {
        Binding(
            get: { model.settings.dayStartHour },
            set: { hour in
                model.updateSettings {
                    $0.dayStartHour = hour
                    $0.dayEndHour = max($0.dayEndHour, hour + 1)
                }
            }
        )
    }

    private var endHour: Binding<Int> {
        Binding(
            get: { model.settings.dayEndHour },
            set: { hour in
                model.updateSettings {
                    $0.dayEndHour = hour
                    $0.dayStartHour = min($0.dayStartHour, hour - 1)
                }
            }
        )
    }

    private var firstSigns: Binding<Double> {
        Binding(
            get: { model.settings.firstSignsML },
            set: { value in
                model.updateSettings {
                    $0.firstSignsML = value
                    $0.unusableML = max($0.unusableML, value + 50)
                }
            }
        )
    }

    private var unusable: Binding<Double> {
        Binding(
            get: { model.settings.unusableML },
            set: { value in
                model.updateSettings {
                    $0.unusableML = value
                    $0.firstSignsML = min($0.firstSignsML, value - 50)
                }
            }
        )
    }

    private var protection: Binding<Bool> {
        Binding(
            get: { model.protectionEnabled },
            set: { enabled in if enabled { model.enableProtection() } }
        )
    }
}

/// Fenêtre de réglages gérée par AppKit : une app de barre de menus n'a pas de scène `Settings` fiable.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(model: AppModel) {
        let window = self.window ?? makeWindow(model: model)
        self.window = window
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: model)))
        window.title = String(localized: "Réglages de Gorgée")
        window.styleMask = [.titled, .closable]
        window.level = NSWindow.Level(rawValue: OverlayController.level.rawValue + 1)
        window.isReleasedWhenClosed = false
        return window
    }
}
