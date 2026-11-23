import Foundation
import Testing
@testable import GorgeeCore

@Suite("Sol craquelé")
struct MudTilingTests {
    static let width = 1512.0
    static let height = 982.0
    static let half = min(width, height) / 2
    let tiling = MudTiling(width: Self.width, height: Self.height, seed: 42)

    func edgeDistance(_ point: Point2D) -> Double {
        min(point.x, point.y, Self.width - point.x, Self.height - point.y)
    }

    func area(_ polygon: [Point2D]) -> Double {
        var sum = 0.0
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    @Test("Le même écran et la même graine donnent le même sol")
    func isDeterministic() {
        #expect(tiling.cells == MudTiling(width: Self.width, height: Self.height, seed: 42).cells)
        #expect(tiling.cells != MudTiling(width: Self.width, height: Self.height, seed: 7).cells)
    }

    @Test("Les plaques pavent tout l'écran, sans trou ni chevauchement")
    func cellsTileTheScreen() {
        #expect(tiling.cells.count > 100)
        #expect(tiling.cells.allSatisfy { $0.polygon.count >= 3 })
        let total = tiling.cells.map { area($0.polygon) }.reduce(0, +)
        #expect(abs(total - Self.width * Self.height) < 1e-6 * Self.width * Self.height)
    }

    @Test("Chaque plaque reste dans l'écran et contient son germe")
    func cellsStayInBounds() {
        for cell in tiling.cells {
            #expect(cell.polygon.allSatisfy { (0...Self.width).contains($0.x) && (0...Self.height).contains($0.y) })
            #expect(edgeDistance(cell.site) >= 0)
        }
    }

    @Test("Rien n'est sec à sévérité nulle ; tout est complètement sec à sévérité maximale")
    func revealBounds() {
        #expect(tiling.revealed(at: 0).isEmpty)
        #expect(tiling.revealed(at: 1).count == tiling.cells.count)
        #expect(tiling.cells.allSatisfy { tiling.dryness(of: $0, at: 1) == 1 })
    }

    @Test("Plus la sévérité monte, plus il y a de plaques sèches")
    func revealIsMonotonic() {
        let counts = [0.05, 0.2, 0.4, 0.6, 0.8].map { tiling.revealed(at: $0).count }
        #expect(counts == counts.sorted())
        #expect(counts.first! > 0)
        #expect(counts.last! < tiling.cells.count)
    }

    @Test("Au début, seules les plaques proches des bords sèchent")
    func edgesDryFirst() {
        let revealed = tiling.revealed(at: 0.2)
        #expect(!revealed.isEmpty)
        let reach = tiling.cellSize / 2 + 0.3 * (Self.half - tiling.cellSize / 2)
        #expect(revealed.allSatisfy { edgeDistance($0.site) <= reach })
    }

    @Test("La surface touchée suit la sévérité, sans tout couvrir d'un coup", arguments: [0.25, 0.5, 0.75])
    func coverageFollowsSeverity(severity: Double) {
        let touched = tiling.revealed(at: severity).map { area($0.polygon) }.reduce(0, +)
        let fraction = touched / (Self.width * Self.height)
        let expected = severity / (1 - MudTiling.rampWidth)
        #expect(abs(fraction - expected) < 0.12, "surface touchée \(fraction) pour une sévérité \(severity)")
    }

    @Test("Le centre de l'écran sèche en dernier")
    func centerDriesLast() {
        let center = Point2D(x: Self.width / 2, y: Self.height / 2)
        let nearest = tiling.cells.min {
            hypot($0.site.x - center.x, $0.site.y - center.y) < hypot($1.site.x - center.x, $1.site.y - center.y)
        }!
        #expect(nearest.reveal >= 0.6)
    }

    @Test("Une plaque sèche progressivement après son apparition")
    func drynessRamps() {
        let cell = tiling.cells[tiling.cells.count / 2]
        #expect(tiling.dryness(of: cell, at: cell.reveal) == 0)
        let midway = tiling.dryness(of: cell, at: cell.reveal + MudTiling.rampWidth / 2)
        #expect(abs(midway - 0.5) < 1e-9)
        #expect(tiling.dryness(of: cell, at: cell.reveal + MudTiling.rampWidth) > 1 - 1e-9)
    }
}
