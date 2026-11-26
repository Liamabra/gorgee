#if DEBUG
import AppKit
import GorgeeCore
import SwiftUI

/// `-GorgeeRenderPreview /dossier` : écrit des PNG de la sécheresse à plusieurs sévérités, puis quitte.
///
/// Sert à régler le rendu sans capture d'écran. Le flou de WindowServer n'y apparaît pas.
enum PreviewRenderer {
    static func runIfRequested() {
        guard let path = UserDefaults.standard.string(forKey: "GorgeeRenderPreview") else { return }
        let directory = URL(filePath: path)
        let size = CGSize(width: 1440, height: 900)
        let tiling = MudTiling(width: size.width, height: size.height, seed: 1)
        for severity in [0.05, 0.25, 0.5, 0.75, 1.0] {
            let state = OverlayState()
            state.severity = severity
            let view = ZStack {
                FakeDesktop()
                DroughtView(state: state, tiling: tiling)
            }
            .frame(width: size.width, height: size.height)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { continue }
            try? png.write(to: directory.appending(path: "drought-\(Int(severity * 100)).png"))
        }
        renderInterface(to: directory)
        renderDistortion(to: directory, size: size)
        exit(0)
    }

    /// Le faux bureau passé dans le shader de déformation, comme le serait la capture de l'écran.
    private static func renderDistortion(to directory: URL, size: CGSize) {
        let desktop = ImageRenderer(content: FakeDesktop().frame(width: size.width, height: size.height))
        desktop.scale = 1
        guard let image = desktop.cgImage, let renderer = DistortionRenderer() else {
            print("Rendu de déformation impossible (Metal ou bibliothèque de shaders absente)")
            return
        }
        let tiling = MudTiling(width: size.width, height: size.height, seed: 1)
        for severity in [0.25, 0.5, 0.75, 1.0] {
            guard let warped = renderer.render(image, tiling: tiling, severity: severity, time: 1.3),
                  let png = NSBitmapImageRep(cgImage: warped).representation(using: .png, properties: [:])
            else { continue }
            try? png.write(to: directory.appending(path: "warp-\(Int(severity * 100)).png"))
        }
    }

    /// Menu et historique, alimentés par 30 jours de gorgées d'exemple dans un dossier temporaire.
    private static func renderInterface(to directory: URL) {
        let data = FileManager.default.temporaryDirectory.appending(path: "gorgee-preview-\(UUID().uuidString)")
        let log = DrinkLog(url: data.appending(path: "drinks.jsonl"))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let glasses = offset == 0 ? 4 : 5 + (offset * 7) % 5
            for glass in 0..<glasses {
                let date = day.addingTimeInterval(Double(9 + glass * 2) * 3600)
                try? log.append(DrinkEvent(date: date, milliliters: glass.isMultiple(of: 3) ? 330 : 250, source: .camera))
            }
        }
        let model = AppModel(files: AppFiles(directory: data))
        let views: [(String, AnyView)] = [
            ("history", AnyView(HistoryView(model: model).background(Color(nsColor: .windowBackgroundColor)))),
            ("menu", AnyView(MenuView(model: model).background(Color(nsColor: .windowBackgroundColor)))),
        ]
        for (name, view) in views {
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { continue }
            try? png.write(to: directory.appending(path: "\(name).png"))
        }
        try? FileManager.default.removeItem(at: data)
    }
}

/// Un faux bureau avec une fenêtre de code, pour juger la lisibilité sous la sécheresse.
private struct FakeDesktop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<20, id: \.self) { line in
                    Text(verbatim: "func hydrate(_ step: Int = \(line)) { let glass = Water(ml: 250); drink(glass) }")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundStyle(.black)
                }
            }
            .padding(24)
            .frame(width: 900, height: 600, alignment: .topLeading)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
#endif
