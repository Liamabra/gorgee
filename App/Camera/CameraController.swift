@preconcurrency import AVFoundation
import GorgeeCore
import Synchronization

/// Une image de la caméra, passée au pipeline de détection qui ne fait que la lire.
nonisolated struct CameraFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let time: Double
}

enum CameraError: Error {
    case denied
    case noAllowedCamera
    case cannotConfigure
}

/// Ouvre à la demande une caméra physique autorisée et diffuse ses images.
nonisolated final class CameraController: NSObject, @unchecked Sendable, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "app.gorgee.camera")
    private let sink = Mutex<AsyncStream<CameraFrame>.Continuation?>(nil)

    /// Caméras physiques uniquement : intégrée, USB ou iPhone en Continuity.
    static func allowedDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        .devices
        .filter { CameraPolicy.isAllowed(transportType: $0.transportType, isContinuityCamera: $0.isContinuityCamera) }
    }

    static var hasAllowedCamera: Bool { !allowedDevices().isEmpty }

    func start() async throws -> AsyncStream<CameraFrame> {
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw CameraError.denied }
        let devices = Self.allowedDevices()
        guard let device = devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) ?? devices.first else {
            throw CameraError.noAllowedCamera
        }
        let input = try AVCaptureDeviceInput(device: device)

        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            throw CameraError.cannotConfigure
        }
        session.addInput(input)
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        session.commitConfiguration()

        let (stream, continuation) = AsyncStream.makeStream(of: CameraFrame.self, bufferingPolicy: .bufferingNewest(1))
        sink.withLock { $0 = continuation }
        queue.async { [session] in session.startRunning() }
        return stream
    }

    func stop() {
        sink.withLock { continuation in
            continuation?.finish()
            continuation = nil
        }
        queue.async { [session] in session.stopRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frame = CameraFrame(pixelBuffer: pixelBuffer, time: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds)
        sink.withLock { _ = $0?.yield(frame) }
    }
}

/// Une autre app (visio) utilise-t-elle une caméra ? La sécheresse se suspend alors, la dette continue.
@Observable
final class CameraBusyMonitor {
    private(set) var isBusy = false
    @ObservationIgnored private var devices: [AVCaptureDevice] = []
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    @ObservationIgnored private var tokens: [NSObjectProtocol] = []

    init() {
        observeDevices()
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            tokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.observeDevices() }
            })
        }
    }

    private func observeDevices() {
        devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        observations = devices.map { device in
            device.observe(\.isInUseByAnotherApplication, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.refresh() }
            }
        }
        refresh()
    }

    private func refresh() {
        isBusy = devices.contains { $0.isInUseByAnotherApplication }
    }
}
