import CoreGraphics
import CoreVideo
import OSLog
@preconcurrency import ScreenCaptureKit
import Synchronization

/// Une image capturée, transmise au rendu qui ne fait que la lire.
nonisolated struct CapturedFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
}

/// Capture d'un écran, sans les fenêtres de Gorgée, et garde la dernière image complète.
nonisolated final class DisplayCapture: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    let displayID: CGDirectDisplayID
    let queue: DispatchQueue
    private let latest = Mutex<CapturedFrame?>(nil)
    private let onFirstFrame: @Sendable () -> Void
    private let onStop: @Sendable (Error) -> Void

    init(displayID: CGDirectDisplayID, onFirstFrame: @escaping @Sendable () -> Void, onStop: @escaping @Sendable (Error) -> Void) {
        self.displayID = displayID
        self.queue = DispatchQueue(label: "app.gorgee.capture.\(displayID)")
        self.onFirstFrame = onFirstFrame
        self.onStop = onStop
    }

    var latestFrame: CapturedFrame? { latest.withLock { $0 } }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        let isFirst = latest.withLock { frame in
            defer { frame = CapturedFrame(pixelBuffer: pixelBuffer) }
            return frame == nil
        }
        if isFirst { onFirstFrame() }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        onStop(error)
    }
}

/// Capture tous les écrans pendant la sécheresse, pour que l'overlay en affiche une copie déformée.
///
/// Demande la permission « Enregistrement de l'écran » ; sans elle, l'overlay garde le rendu peint.
final class ScreenCaptureManager {
    private let log = Logger(subsystem: "app.gorgee.Gorgee", category: "capture")
    private var captures: [CGDirectDisplayID: DisplayCapture] = [:]
    private var streams: [SCStream] = []
    private var generation = 0
    private(set) var isRunning = false

    /// Appelé sur le fil principal à la première image (capture prête) et à l'arrêt sur erreur.
    var onReady: () -> Void = {}
    var onFailure: () -> Void = {}

    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    @discardableResult
    static func requestPermission() -> Bool { CGRequestScreenCaptureAccess() }

    func latestFrame(for displayID: CGDirectDisplayID) -> CapturedFrame? {
        captures[displayID]?.latestFrame
    }

    func start() {
        guard !isRunning, Self.hasPermission else { return }
        isRunning = true
        generation += 1
        let current = generation
        Task { [weak self] in await self?.startStreams(generation: current) }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        generation += 1
        let stopping = streams
        streams = []
        captures = [:]
        for stream in stopping {
            Task { try? await stream.stopCapture() }
        }
    }

    private func startStreams(generation current: Int) async {
        do {
            let content = try await SCShareableContent.current
            guard current == generation else { return }
            let ownApp = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
            for display in content.displays {
                let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: [])
                let configuration = SCStreamConfiguration()
                let scale = Double(filter.pointPixelScale)
                configuration.width = Int(Double(display.width) * scale)
                configuration.height = Int(Double(display.height) * scale)
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                configuration.showsCursor = false
                configuration.queueDepth = 4

                let capture = DisplayCapture(
                    displayID: display.displayID,
                    onFirstFrame: { [weak self] in Task { @MainActor in self?.handleFirstFrame(generation: current) } },
                    onStop: { [weak self] error in Task { @MainActor in self?.handleStop(error, generation: current) } }
                )
                let stream = SCStream(filter: filter, configuration: configuration, delegate: capture)
                try stream.addStreamOutput(capture, type: .screen, sampleHandlerQueue: capture.queue)
                try await stream.startCapture()
                guard current == generation else {
                    try? await stream.stopCapture()
                    return
                }
                captures[display.displayID] = capture
                streams.append(stream)
            }
            log.notice("Capture lancée sur \(self.streams.count) écran(s)")
        } catch {
            log.error("Capture impossible : \(error.localizedDescription, privacy: .public)")
            guard current == generation else { return }
            stop()
            onFailure()
        }
    }

    private func handleFirstFrame(generation current: Int) {
        guard current == generation else { return }
        onReady()
    }

    private func handleStop(_ error: Error, generation current: Int) {
        guard current == generation else { return }
        log.error("Capture arrêtée : \(error.localizedDescription, privacy: .public)")
        stop()
        onFailure()
    }
}
