import AppKit
import Charts
import GorgeeCore
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    let model: AppModel
    @State private var days = 7

    var body: some View {
        let history = HydrationHistory(events: model.drinkEvents)
        let goal = model.settings.dailyGoalML
        let today = history.total(on: model.now)
        let totals = history.dailyTotals(days: days, endingOn: model.now)

        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 32) {
                StatBlock(title: "Aujourd'hui") {
                    Text("\(Liters.format(today)) sur \(Liters.format(goal))")
                }
                StatBlock(title: "Série") {
                    Text("\(history.streak(goal: goal, today: model.now)) jours d'affilée")
                }
            }

            Picker("Période", selection: $days) {
                Text("7 jours").tag(7)
                Text("30 jours").tag(30)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Chart {
                ForEach(totals) { total in
                    BarMark(
                        x: .value("Jour", total.day, unit: .day),
                        y: .value("Litres", Double(total.milliliters) / 1000)
                    )
                    .foregroundStyle(total.milliliters >= goal ? Color.blue : Color.orange)
                }
                RuleMark(y: .value("Objectif", Double(goal) / 1000))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Objectif").font(.caption).foregroundStyle(.secondary)
                    }
            }
            .chartYAxisLabel("L")
            .frame(height: 220)

            HStack {
                Spacer()
                Button("Exporter en CSV…") { model.exportHistory(as: .commaSeparatedText) }
                Button("Exporter en JSON…") { model.exportHistory(as: .json) }
            }
            .disabled(model.drinkEvents.isEmpty)
        }
        .padding(20)
        .frame(width: 540)
    }

    private struct StatBlock<Content: View>: View {
        let title: LocalizedStringKey
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                content.font(.title3.weight(.semibold))
            }
        }
    }
}

final class HistoryWindowController {
    static let shared = HistoryWindowController()
    private var window: NSWindow?

    func show(model: AppModel) {
        let window = self.window ?? makeWindow(model: model)
        self.window = window
        NSApp.activate()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: HistoryView(model: model)))
        window.title = String(localized: "Historique de Gorgée")
        window.styleMask = [.titled, .closable]
        window.level = NSWindow.Level(rawValue: OverlayController.level.rawValue + 1)
        window.isReleasedWhenClosed = false
        return window
    }
}
