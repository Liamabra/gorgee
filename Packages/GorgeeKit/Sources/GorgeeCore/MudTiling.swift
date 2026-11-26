import Foundation

public struct Point2D: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Une plaque d'argile du sol craquelé.
public struct MudCell: Equatable, Sendable {
    /// Polygone convexe, en points, origine en haut à gauche.
    public var polygon: [Point2D]
    public var site: Point2D
    /// Sévérité à partir de laquelle la plaque commence à sécher.
    public var reveal: Double
    /// Variation de teinte propre à la plaque, dans [0, 1].
    public var shade: Double
}

/// L'écran découpé en plaques d'argile (cellules de Voronoï) qui sèchent depuis les bords vers le centre.
///
/// Le même écran et la même graine donnent toujours le même sol, pour que les plaques ne sautent pas
/// d'un rafraîchissement à l'autre. À sévérité maximale, toutes les plaques sont sèches et couvrent l'écran.
public struct MudTiling: Sendable {
    /// Écart de sévérité entre l'apparition d'une plaque et son séchage complet.
    public static let rampWidth = 0.2

    public let width: Double
    public let height: Double
    public let cellSize: Double
    /// Triées par `reveal` croissant.
    public let cells: [MudCell]
    /// Les mêmes plaques rangées ligne par ligne sur la grille des germes : le shader y retrouve
    /// la plaque d'un pixel en ne regardant que les 3×3 cases voisines.
    public let grid: [MudCell]
    public let columns: Int
    public let rows: Int

    public init(width: Double, height: Double, seed: UInt64, cellSize: Double = 72) {
        self.width = width
        self.height = height
        self.cellSize = cellSize
        var random = SplitMix64(state: seed)

        let columns = max(1, Int((width / cellSize).rounded()))
        let rows = max(1, Int((height / cellSize).rounded()))
        self.columns = columns
        self.rows = rows
        let columnWidth = width / Double(columns)
        let rowHeight = height / Double(rows)
        var sites: [Point2D] = []
        for row in 0..<rows {
            for column in 0..<columns {
                sites.append(Point2D(
                    x: (Double(column) + 0.5 + random.uniform(-0.4...0.4)) * columnWidth,
                    y: (Double(row) + 0.5 + random.uniform(-0.4...0.4)) * rowHeight
                ))
            }
        }

        let half = min(width, height) / 2
        let screen = [
            Point2D(x: 0, y: 0), Point2D(x: width, y: 0),
            Point2D(x: width, y: height), Point2D(x: 0, y: height),
        ]
        var cells: [MudCell] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let site = sites[row * columns + column]
                var polygon = screen
                // Germes posés sur une grille à ±40 % : les voisins de Voronoï sont à deux cases au plus.
                for neighborRow in max(0, row - 2)...min(rows - 1, row + 2) {
                    for neighborColumn in max(0, column - 2)...min(columns - 1, column + 2)
                    where (neighborRow, neighborColumn) != (row, column) {
                        polygon = Self.clip(polygon, keepingCloserTo: site, than: sites[neighborRow * columns + neighborColumn])
                    }
                }
                // Une plaque apparaît quand la sécheresse a gagné toute la surface plus proche du bord qu'elle :
                // la surface touchée suit ainsi la sévérité au lieu de filer avec les grands anneaux extérieurs.
                let edgeDistance = min(site.x, site.y, width - site.x, height - site.y)
                let inset = min(half, max(0, edgeDistance - cellSize / 2))
                let outerArea = 1 - (width - 2 * inset) * (height - 2 * inset) / (width * height)
                let reveal = min(1 - Self.rampWidth, (1 - Self.rampWidth) * outerArea * random.uniform(0.85...1.15))
                cells.append(MudCell(polygon: polygon, site: site, reveal: reveal, shade: random.uniform(0...1)))
            }
        }
        self.grid = cells
        self.cells = cells.enumerated()
            .sorted { ($0.element.reveal, $0.offset) < ($1.element.reveal, $1.offset) }
            .map(\.element)
    }

    /// Les plaques qui ont commencé à sécher à cette sévérité.
    public func revealed(at severity: Double) -> ArraySlice<MudCell> {
        var low = 0
        var high = cells.count
        while low < high {
            let mid = (low + high) / 2
            if cells[mid].reveal < severity { low = mid + 1 } else { high = mid }
        }
        return cells[..<low]
    }

    /// 0 = encore humide, 1 = complètement sèche.
    public func dryness(of cell: MudCell, at severity: Double) -> Double {
        guard severity < 1 else { return 1 }
        return min(1, max(0, (severity - cell.reveal) / Self.rampWidth))
    }

    /// Garde la partie du polygone plus proche de `site` que de `other` (demi-plan de la médiatrice).
    static func clip(_ polygon: [Point2D], keepingCloserTo site: Point2D, than other: Point2D) -> [Point2D] {
        let normalX = other.x - site.x
        let normalY = other.y - site.y
        let limit = (other.x * other.x + other.y * other.y - site.x * site.x - site.y * site.y) / 2
        var kept: [Point2D] = []
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            let sideA = a.x * normalX + a.y * normalY - limit
            let sideB = b.x * normalX + b.y * normalY - limit
            if sideA <= 0 { kept.append(a) }
            if (sideA <= 0) != (sideB <= 0) {
                let t = sideA / (sideA - sideB)
                kept.append(Point2D(x: a.x + t * (b.x - a.x), y: a.y + t * (b.y - a.y)))
            }
        }
        return kept
    }
}

/// Générateur pseudo-aléatoire stable d'une version de Swift à l'autre.
struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func uniform(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * Double(next() >> 11) * 0x1p-53
    }
}
