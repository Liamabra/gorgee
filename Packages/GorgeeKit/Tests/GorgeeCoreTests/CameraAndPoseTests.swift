import Testing
@testable import GorgeeCore

@Suite("Caméras acceptées")
struct CameraPolicyTests {
    @Test("Caméra intégrée et caméra USB acceptées", arguments: ["bltn", "usb "])
    func physicalCamerasAllowed(transport: String) {
        #expect(CameraPolicy.isAllowed(transportType: fourCharCode(transport), isContinuityCamera: false))
    }

    @Test("Un iPhone en Continuity Camera est accepté")
    func continuityAllowed() {
        #expect(CameraPolicy.isAllowed(transportType: fourCharCode("wlss"), isContinuityCamera: true))
    }

    @Test("Caméras virtuelles et transports inconnus refusés", arguments: ["virt", "????"])
    func virtualRefused(transport: String) {
        #expect(!CameraPolicy.isAllowed(transportType: fourCharCode(transport), isContinuityCamera: false))
        #expect(!CameraPolicy.isAllowed(transportType: 0, isContinuityCamera: false))
    }

    @Test("Le code à quatre lettres se lit comme AVFoundation l'écrit")
    func fourCCMatchesAVFoundation() {
        #expect(fourCharCode("bltn") == 1_651_274_862)
    }
}

@Suite("Geste « boire »")
struct DrinkingPoseTests {
    /// Visage de 200 px de large, bouche en (500, 400), tête droite.
    static func face(pitch: Double = 0) -> PoseSnapshot {
        PoseSnapshot(mouth: Point2D(x: 500, y: 400), faceWidth: 200, pitchDegrees: pitch, handPoints: [])
    }

    static func withHand(_ snapshot: PoseSnapshot, at point: Point2D) -> PoseSnapshot {
        var snapshot = snapshot
        snapshot.handPoints = [point]
        return snapshot
    }

    static let nearMouth = Point2D(x: 540, y: 380)
    static let farAway = Point2D(x: 900, y: 100)

    /// Un détecteur calibré : tête droite, main loin de la bouche.
    static func calibrated() -> DrinkingPoseDetector {
        var detector = DrinkingPoseDetector()
        _ = detector.evaluate(withHand(face(), at: farAway), at: 0)
        return detector
    }

    @Test("Main loin de la bouche : pas de gorgée")
    func handFarAway() {
        var detector = Self.calibrated()
        let outcome1 = detector.evaluate(Self.withHand(Self.face(pitch: 15), at: Self.farAway), at: 1)
        #expect(!outcome1)
    }

    @Test("Main à la bouche mais tête droite : pas encore une gorgée")
    func handNearHeadLevel() {
        var detector = Self.calibrated()
        let outcome2 = detector.evaluate(Self.withHand(Self.face(pitch: 2), at: Self.nearMouth), at: 1)
        #expect(!outcome2)
    }

    @Test("Main à la bouche, tête inclinée : gorgée")
    func handNearHeadTilted() {
        var detector = Self.calibrated()
        let outcome3 = detector.evaluate(Self.withHand(Self.face(pitch: 12), at: Self.nearMouth), at: 1)
        #expect(outcome3)
        let outcome4 = detector.evaluate(Self.withHand(Self.face(pitch: -12), at: Self.nearMouth), at: 1.1)
        #expect(outcome4)
    }

    @Test("Visage masqué un instant par le verre : la gorgée continue")
    func briefOcclusionCounts() {
        var detector = Self.calibrated()
        _ = detector.evaluate(Self.withHand(Self.face(pitch: 12), at: Self.nearMouth), at: 1)
        let hidden = PoseSnapshot(mouth: nil, faceWidth: nil, pitchDegrees: nil, handPoints: [Self.nearMouth])
        let outcome5 = detector.evaluate(hidden, at: 1.6)
        #expect(outcome5)
    }

    @Test("Visage absent depuis plus d'une seconde : pas de gorgée")
    func longOcclusionStops() {
        var detector = Self.calibrated()
        _ = detector.evaluate(Self.withHand(Self.face(pitch: 12), at: Self.nearMouth), at: 1)
        let hidden = PoseSnapshot(mouth: nil, faceWidth: nil, pitchDegrees: nil, handPoints: [Self.nearMouth])
        let outcome6 = detector.evaluate(hidden, at: 2.2)
        #expect(!outcome6)
    }

    @Test("Sans calibrage préalable, une tête déjà inclinée ne suffit pas")
    func needsBaseline() {
        var detector = DrinkingPoseDetector()
        let outcome7 = detector.evaluate(Self.withHand(Self.face(pitch: 15), at: Self.nearMouth), at: 0)
        #expect(!outcome7)
    }
}
