import Foundation

public struct Point2D: Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct CrackSegment: Equatable, Sendable {
    public var start: Point2D
    public var end: Point2D
    /// Sévérité (0…1) à partir de laquelle ce segment est visible.
    public var reveal: Double
    /// 0 = craquelure principale, 1+ = ramifications, plus fines.
    public var depth: Int
}

/// Craquelures de sol sec qui partent des bords de l'écran et gagnent le centre avec la sévérité.
///
/// Coordonnées en points, origine en haut à gauche. Le même écran et la même graine donnent
/// toujours le même réseau, pour que les fissures ne sautent pas d'un rafraîchissement à l'autre.
public struct CrackNetwork: Sendable {
    public let width: Double
    public let height: Double
    /// Triés par `reveal` croissant ; une ramification vient toujours après son parent.
    public let segments: [CrackSegment]

    public init(width: Double, height: Double, seed: UInt64, spacing: Double = 110, maxSegments: Int = 8000) {
        self.width = width
        self.height = height
        var generator = Generator(width: width, height: height, seed: seed, maxSegments: maxSegments)
        generator.grow(spacing: spacing)
        segments = generator.segments.enumerated()
            .sorted { ($0.element.reveal, $0.offset) < ($1.element.reveal, $1.offset) }
            .map(\.element)
    }

    /// Les segments visibles à cette sévérité.
    public func revealed(at severity: Double) -> ArraySlice<CrackSegment> {
        var low = 0
        var high = segments.count
        while low < high {
            let mid = (low + high) / 2
            if segments[mid].reveal <= severity { low = mid + 1 } else { high = mid }
        }
        return segments[..<low]
    }
}

private struct Generator {
    let width: Double
    let height: Double
    let half: Double
    let maxSegments: Int
    var random: SplitMix64
    var segments: [CrackSegment] = []

    init(width: Double, height: Double, seed: UInt64, maxSegments: Int) {
        self.width = width
        self.height = height
        self.half = min(width, height) / 2
        self.maxSegments = maxSegments
        self.random = SplitMix64(state: seed)
    }

    struct Head {
        var point: Point2D
        var angle: Double
        var depth: Int
        var reveal: Double
        var length: Double
    }

    mutating func grow(spacing: Double) {
        guard width > 0, height > 0 else { return }
        let perimeter = 2 * (width + height)
        let rootCount = max(8, min(64, Int(perimeter / spacing)))
        let gap = perimeter / Double(rootCount)
        var heads: [Head] = []
        let offset = random.uniform(0...gap)
        for index in 0..<rootCount {
            let t = offset + Double(index) * gap + random.uniform(-0.3 * gap...0.3 * gap)
            let (point, inward) = edgePoint(at: t.truncatingRemainder(dividingBy: perimeter))
            heads.append(Head(point: point, angle: inward + random.uniform(-0.5...0.5), depth: 0, reveal: 0, length: half * 1.2))
        }
        // Chaque racine fait pousser sa craquelure, puis ses ramifications.
        for root in heads {
            var stack = [root]
            while let head = stack.popLast(), segments.count < maxSegments {
                walk(head, branches: &stack)
            }
        }
    }

    mutating func walk(_ head: Head, branches: inout [Head]) {
        var point = head.point
        var angle = head.angle
        var reveal = head.reveal
        var remaining = head.length
        let center = Point2D(x: width / 2, y: height / 2)
        while remaining > 0, segments.count < maxSegments {
            angle += random.uniform(-0.35...0.35)
            if head.depth == 0 {
                let toCenter = atan2(center.y - point.y, center.x - point.x)
                angle += remainder(toCenter - angle, 2 * .pi) * 0.08
            }
            let step = random.uniform(12...26)
            let next = Point2D(x: point.x + step * cos(angle), y: point.y + step * sin(angle))
            guard (0...width).contains(next.x), (0...height).contains(next.y) else { return }
            reveal = min(1, max(reveal, edgeDistance(next) / half))
            segments.append(CrackSegment(start: point, end: next, reveal: reveal, depth: head.depth))
            if head.depth < 3, random.uniform(0...1) < 0.10 - Double(head.depth) * 0.02 {
                let side: Double = random.uniform(0...1) < 0.5 ? -1 : 1
                branches.append(Head(
                    point: next,
                    angle: angle + side * random.uniform(0.6...1.2),
                    depth: head.depth + 1,
                    reveal: reveal,
                    length: remaining * 0.5
                ))
            }
            point = next
            remaining -= step
        }
    }

    func edgeDistance(_ point: Point2D) -> Double {
        min(point.x, point.y, width - point.x, height - point.y)
    }

    /// Un point du bord, parcouru dans le sens horaire depuis le coin haut gauche, et la direction vers l'intérieur.
    func edgePoint(at t: Double) -> (Point2D, Double) {
        switch t {
        case ..<width:
            return (Point2D(x: t, y: 0), .pi / 2)
        case ..<(width + height):
            return (Point2D(x: width, y: t - width), .pi)
        case ..<(2 * width + height):
            return (Point2D(x: width - (t - width - height), y: height), -.pi / 2)
        default:
            return (Point2D(x: 0, y: height - (t - 2 * width - height)), 0)
        }
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
