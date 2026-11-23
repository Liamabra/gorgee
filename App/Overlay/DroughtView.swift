import GorgeeCore
import SwiftUI

/// Le dessin de la sécheresse : plaques d'argile craquelée, brume, poussière, puis l'eau qui répare.
struct DroughtView: View {
    let state: OverlayState
    let tiling: MudTiling

    var body: some View {
        Group {
            if let wash = state.wash {
                TimelineView(.animation) { timeline in
                    let progress = wash.progress(at: timeline.date)
                    let eased = 1 - pow(1 - progress, 3)
                    ZStack {
                        DroughtLayers(severity: wash.from + (wash.to - wash.from) * eased, tiling: tiling)
                        WaterWashLayer(progress: progress)
                    }
                }
            } else {
                DroughtLayers(severity: state.severity, tiling: tiling)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private enum Palette {
    static let sand = Color(red: 0.80, green: 0.64, blue: 0.42)
    static let scorched = Color(red: 0.56, green: 0.39, blue: 0.22)
    static let crack = Color(red: 0.24, green: 0.15, blue: 0.08)
    static let clay = Color(red: 0.72, green: 0.55, blue: 0.36)
    static let clayLight = Color(red: 0.87, green: 0.75, blue: 0.56)
    static let dust = Color(red: 0.93, green: 0.83, blue: 0.64)
    static let water = Color(red: 0.36, green: 0.67, blue: 0.96)
}

private struct DroughtLayers: View {
    let severity: Double
    let tiling: MudTiling

    var body: some View {
        ZStack {
            Canvas { context, size in
                drawHaze(in: &context, size: size)
                drawMud(in: &context)
            }
            if severity > 0 {
                DustLayer(severity: severity)
            }
        }
    }

    /// Brume chaude sur la partie encore humide de l'écran.
    private func drawHaze(in context: inout GraphicsContext, size: CGSize) {
        guard severity > 0, size.width > 0, size.height > 0 else { return }
        let gradient = Gradient(colors: [
            Palette.sand.opacity(0.12 * severity),
            Palette.scorched.opacity(0.30 * severity),
        ])
        // Dégradé elliptique : un cercle dans un repère étiré à la forme de l'écran.
        var haze = context
        let stretch = size.width / size.height
        haze.scaleBy(x: stretch, y: 1)
        let rect = CGRect(x: 0, y: 0, width: size.width / stretch, height: size.height)
        haze.fill(Path(rect), with: .radialGradient(
            gradient,
            center: CGPoint(x: rect.midX, y: rect.midY),
            startRadius: 0,
            endRadius: size.height / 2
        ))
    }

    /// Plaques d'argile : la fissure sombre dessous, la plaque bombée dessus, qui se rétracte en séchant.
    private func drawMud(in context: inout GraphicsContext) {
        for cell in tiling.revealed(at: severity) {
            let dryness = tiling.dryness(of: cell, at: severity)
            // Même sèche, une plaque laisse deviner l'écran ; elle ne devient opaque qu'à sévérité maximale.
            let cover = 0.5 + 0.45 * severity
            let points = cell.polygon.map { CGPoint(x: $0.x, y: $0.y) }
            context.fill(Path(polygon: points), with: .color(Palette.crack.opacity(0.9 * dryness * cover)))

            let centroid = CGPoint(
                x: points.map(\.x).reduce(0, +) / Double(points.count),
                y: points.map(\.y).reduce(0, +) / Double(points.count)
            )
            let gap = 1.2 + 3.0 * dryness
            let plate = points.map { point in
                let dx = centroid.x - point.x
                let dy = centroid.y - point.y
                let shrink = min(0.5, gap / max(1, hypot(dx, dy)))
                return CGPoint(x: point.x + dx * shrink, y: point.y + dy * shrink)
            }
            let radius = plate.map { hypot($0.x - centroid.x, $0.y - centroid.y) }.max() ?? 1
            let opacity = (0.15 + 0.85 * dryness) * cover
            let base = Palette.clay.mix(with: Palette.clayLight, by: cell.shade * 0.6)
            context.fill(Path(polygon: plate), with: .radialGradient(
                Gradient(colors: [Palette.clayLight.opacity(opacity), base.opacity(opacity)]),
                center: centroid,
                startRadius: 0,
                endRadius: radius
            ))
        }
    }
}

/// Grains de poussière portés par le vent ; seule couche animée en continu.
private struct DustLayer: View {
    let severity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let count = Int(180 * severity)
                for index in 0..<count {
                    let speed = 12 + 40 * unitNoise(index, 1)
                    let span = size.width + 20
                    let x = (unitNoise(index, 2) * span + time * speed).truncatingRemainder(dividingBy: span) - 10
                    let wobble = sin(time * (0.5 + unitNoise(index, 1)) + unitNoise(index, 2) * 6.28) * 14
                    let y = unitNoise(index, 3) * size.height + wobble
                    let radius = 0.8 + 1.8 * unitNoise(index, 4)
                    let grain = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: grain), with: .color(Palette.dust.opacity(0.35 + 0.4 * unitNoise(index, 3))))
                }
            }
        }
    }
}

/// Une vague d'eau descend l'écran pendant que la sécheresse recule.
private struct WaterWashLayer: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let fade = 1 - progress
            let bandHeight = size.height * 0.55
            let top = -bandHeight + (size.height + bandHeight) * progress
            let band = CGRect(x: 0, y: top, width: size.width, height: bandHeight)
            let gradient = Gradient(colors: [
                Palette.water.opacity(0),
                Palette.water.opacity(0.1 + 0.3 * fade),
                Palette.water.opacity(0),
            ])
            context.fill(Path(band), with: .linearGradient(
                gradient, startPoint: CGPoint(x: 0, y: band.minY), endPoint: CGPoint(x: 0, y: band.maxY)
            ))
            var streaks = Path()
            for index in 0..<60 {
                let x = unitNoise(index, 7) * size.width
                let length = 40 + 120 * unitNoise(index, 8)
                let speed = 0.8 + 0.6 * unitNoise(index, 9)
                let y = progress * speed * (size.height + length) - length
                streaks.move(to: CGPoint(x: x, y: y))
                streaks.addLine(to: CGPoint(x: x, y: y + length))
            }
            context.stroke(streaks, with: .color(Palette.water.opacity(0.5 * fade)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

/// Bruit stable dans [0, 1) pour un grain et un canal donnés.
private func unitNoise(_ index: Int, _ channel: UInt64) -> Double {
    var z = UInt64(truncatingIfNeeded: index) &* 0x9E37_79B9_7F4A_7C15 &+ channel &* 0xD1B5_4A32_D192_ED03
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z ^= z >> 31
    return Double(z >> 11) * 0x1p-53
}

private extension Path {
    init(polygon points: [CGPoint]) {
        self.init()
        addLines(points)
        closeSubpath()
    }
}
