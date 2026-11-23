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
        exit(0)
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
