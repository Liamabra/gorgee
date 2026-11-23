import Foundation

/// Ce que l'analyse d'une image a trouvé, en pixels.
public struct PoseSnapshot: Equatable, Sendable {
    public var mouth: Point2D?
    public var faceWidth: Double?
    /// Inclinaison avant-arrière de la tête, en degrés.
    public var pitchDegrees: Double?
    /// Bouts des doigts et poignets des mains détectées.
    public var handPoints: [Point2D]

    public init(mouth: Point2D?, faceWidth: Double?, pitchDegrees: Double?, handPoints: [Point2D]) {
        self.mouth = mouth
        self.faceWidth = faceWidth
        self.pitchDegrees = pitchDegrees
        self.handPoints = handPoints
    }
}

/// Reconnaît le geste « boire » : une main à la bouche, la tête inclinée par rapport à sa position de repos.
///
/// La position de repos se calibre sur les images où la main est loin de la bouche. Quand le verre masque
/// le visage, on garde un court instant la dernière bouche vue et le dernier verdict d'inclinaison.
public struct DrinkingPoseDetector: Sendable {
    /// Distance main-bouche maximale, en largeurs de visage.
    public var nearMouthFactor = 0.9
    public var tiltDegrees = 8.0
    /// Durée pendant laquelle on se fie à la dernière bouche vue.
    public var faceMemory = 1.0

    private var baselinePitch: Double?
    private var lastMouth: Point2D?
    private var lastFaceWidth = 0.0
    private var lastFaceTime = -Double.infinity
    private var lastTilted = false

    public init() {}

    public mutating func evaluate(_ snapshot: PoseSnapshot, at time: Double) -> Bool {
        let faceVisible = snapshot.mouth != nil && snapshot.faceWidth != nil
        if let mouth = snapshot.mouth, let width = snapshot.faceWidth {
            lastMouth = mouth
            lastFaceWidth = width
            lastFaceTime = time
        }
        guard let mouth = lastMouth, time - lastFaceTime <= faceMemory else { return false }

        let reach = nearMouthFactor * lastFaceWidth
        let handNearMouth = snapshot.handPoints.contains { hypot($0.x - mouth.x, $0.y - mouth.y) <= reach }
        guard handNearMouth else {
            if let pitch = snapshot.pitchDegrees { baselinePitch = pitch }
            lastTilted = false
            return false
        }
        guard let baselinePitch else { return false }
        if faceVisible, let pitch = snapshot.pitchDegrees {
            lastTilted = abs(pitch - baselinePitch) >= tiltDegrees
        }
        return lastTilted
    }
}
