import CoreGraphics
import CoreVideo
import GorgeeCore
import Vision

/// Trouve la bouche, l'inclinaison de la tête et les mains sur une image, en pixels.
public struct FrameAnalyzer: Sendable {
    private static let handJoints: [HumanHandPoseObservation.JointName] = [.thumbTip, .indexTip, .middleTip, .wrist]

    public init() {}

    public func analyze(_ pixelBuffer: CVPixelBuffer) async throws -> PoseSnapshot {
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        var handRequest = DetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2
        let faces = try await DetectFaceLandmarksRequest().perform(on: pixelBuffer)
        let hands = try await handRequest.perform(on: pixelBuffer)

        var snapshot = PoseSnapshot(mouth: nil, faceWidth: nil, pitchDegrees: nil, handPoints: [])
        if let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }) {
            let box = face.boundingBox.toImageCoordinates(size)
            snapshot.faceWidth = box.width
            snapshot.pitchDegrees = face.pitch.converted(to: .degrees).value
            let lips = face.landmarks?.outerLips.pointsInImageCoordinates(size) ?? []
            if lips.isEmpty {
                // Sans repères, la bouche est vers le bas du visage (origine en bas à gauche).
                snapshot.mouth = Point2D(x: box.midX, y: box.minY + 0.25 * box.height)
            } else {
                let count = Double(lips.count)
                snapshot.mouth = Point2D(
                    x: lips.map(\.x).reduce(0, +) / count,
                    y: lips.map(\.y).reduce(0, +) / count
                )
            }
        }
        for hand in hands {
            let joints = hand.allJoints()
            for name in Self.handJoints {
                guard let joint = joints[name], joint.confidence > 0.3 else { continue }
                let point = joint.location.toImageCoordinates(size)
                snapshot.handPoints.append(Point2D(x: point.x, y: point.y))
            }
        }
        return snapshot
    }
}
