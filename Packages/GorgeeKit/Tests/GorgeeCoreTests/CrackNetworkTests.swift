import Foundation
import Testing
@testable import GorgeeCore

@Suite("Réseau de craquelures")
struct CrackNetworkTests {
    static let width = 1512.0
    static let height = 982.0
    static let half = min(width, height) / 2
    let network = CrackNetwork(width: Self.width, height: Self.height, seed: 42)

    func edgeDistance(_ point: Point2D) -> Double {
        min(point.x, point.y, Self.width - point.x, Self.height - point.y)
    }

    @Test("Le même écran et la même graine donnent les mêmes craquelures")
    func isDeterministic() {
        #expect(network.segments == CrackNetwork(width: Self.width, height: Self.height, seed: 42).segments)
        #expect(network.segments != CrackNetwork(width: Self.width, height: Self.height, seed: 7).segments)
    }

    @Test("Rien n'apparaît à sévérité nulle, tout apparaît à sévérité maximale")
    func revealBounds() {
        #expect(network.revealed(at: 0).isEmpty)
        #expect(network.revealed(at: 1).count == network.segments.count)
        #expect(network.segments.allSatisfy { (0...1).contains($0.reveal) })
    }

    @Test("Plus la sévérité monte, plus il y a de craquelures")
    func revealIsMonotonic() {
        let counts = [0.1, 0.3, 0.5, 0.7, 0.9].map { network.revealed(at: $0).count }
        #expect(counts == counts.sorted())
        #expect(counts.first! > 0)
        #expect(counts.last! < network.segments.count)
    }

    @Test("Au début, seules les zones proches des bords se fissurent")
    func earlyCracksHugTheEdges() {
        let revealed = network.revealed(at: 0.25)
        #expect(!revealed.isEmpty)
        #expect(revealed.allSatisfy { edgeDistance($0.end) <= 0.25 * Self.half + 1e-9 })
    }

    @Test("Les craquelures finissent par atteindre le centre")
    func cracksReachTheCenter() {
        #expect(network.segments.contains { $0.reveal >= 0.9 })
    }

    @Test("Chaque craquelure visible part d'un bord ou prolonge une craquelure visible", arguments: [0.2, 0.5, 0.8])
    func growthIsConnected(severity: Double) {
        let revealed = network.revealed(at: severity)
        let ends = Set(revealed.map(\.end))
        for segment in revealed {
            #expect(edgeDistance(segment.start) < 1e-9 || ends.contains(segment.start))
        }
    }

    @Test("Le réseau reste dans l'écran et sous le plafond de segments")
    func staysInBounds() {
        let small = CrackNetwork(width: 800, height: 600, seed: 3, maxSegments: 500)
        #expect(small.segments.count <= 500)
        for segment in network.segments {
            for point in [segment.start, segment.end] {
                #expect((0...Self.width).contains(point.x) && (0...Self.height).contains(point.y))
            }
        }
    }
}
