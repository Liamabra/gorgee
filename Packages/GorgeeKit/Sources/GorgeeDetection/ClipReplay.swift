import AVFoundation
import GorgeeCore

/// Rejoue un clip vidéo dans le pipeline de preuve, comme si la caméra le filmait.
public enum ClipReplay {
    public struct Result: Sendable {
        public var step: SipStep
        public var frames: Int
        public var duration: Double
    }

    /// Analyse le clip à environ `framesPerSecond` images par seconde.
    public static func run(_ url: URL, framesPerSecond: Double = 10) async throws -> Result {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ReplayError.noVideoTrack
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()

        var runner: ProofRunner?
        var lastTime = -Double.infinity
        var frames = 0
        var time = 0.0
        while let sample = try await provider.next() {
            let sampleTime = sample.presentationTimeStamp.seconds
            guard sampleTime - lastTime >= 1 / framesPerSecond - 1e-6 else { continue }
            // L'image est comptée par référence : la garder au-delà de la fermeture est sûr, on ne fait que la lire.
            nonisolated(unsafe) var extracted: CVPixelBuffer?
            sample.withUnsafeSampleBuffer { extracted = CMSampleBufferGetImageBuffer($0) }
            guard let pixelBuffer = extracted else { continue }
            time = sampleTime
            lastTime = time
            let active = runner ?? ProofRunner(startedAt: time)
            runner = active
            frames += 1
            if active.machine.isFinished { break }
            await active.process(pixelBuffer, at: time)
        }
        reader.cancelReading()
        return Result(step: runner?.step ?? .showContainer, frames: frames, duration: time)
    }

    public enum ReplayError: Error {
        case noVideoTrack
        case unreadable
    }
}
