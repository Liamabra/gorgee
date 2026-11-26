import CoreVideo
import GorgeeCore
import Metal
import MetalKit
import QuartzCore

/// Affiche, au-dessus d'un écran, sa copie capturée et déformée par la sécheresse.
final class DistortionView: MTKView, MTKViewDelegate {
    private let renderer: DistortionRenderer
    private let tiling: MudTiling
    private let sites: MTLBuffer
    private let state: OverlayState
    private let frameSource: () -> CapturedFrame?
    private var textureCache: CVMetalTextureCache?

    init?(
        frame: CGRect,
        renderer: DistortionRenderer,
        tiling: MudTiling,
        state: OverlayState,
        frameSource: @escaping () -> CapturedFrame?
    ) {
        guard let sites = renderer.makeSites(for: tiling) else { return nil }
        self.renderer = renderer
        self.tiling = tiling
        self.sites = sites
        self.state = state
        self.frameSource = frameSource
        super.init(frame: frame, device: renderer.device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        layer?.isOpaque = false
        preferredFramesPerSecond = 30
        enableSetNeedsDisplay = false
        isPaused = true
        delegate = self
        CVMetalTextureCacheCreate(nil, nil, renderer.device, nil, &textureCache)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) n'est pas utilisé")
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable,
              let commandBuffer = renderer.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else { return }
        var retained: CVMetalTexture?
        if let frame = frameSource(), let (texture, cvTexture) = makeTexture(frame.pixelBuffer) {
            retained = cvTexture
            let severity = state.wash?.severity(at: .now) ?? state.severity
            renderer.encode(encoder, screen: texture, sites: sites, tiling: tiling, severity: severity, time: CACurrentMediaTime())
        }
        encoder.endEncoding()
        // La texture doit vivre jusqu'à la fin du travail du GPU.
        let keepAlive = RetainedTexture(texture: retained)
        commandBuffer.addCompletedHandler { _ in _ = keepAlive }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeTexture(_ pixelBuffer: CVPixelBuffer) -> (MTLTexture, CVMetalTexture)? {
        guard let textureCache else { return nil }
        var cvTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            nil, textureCache, pixelBuffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer), 0, &cvTexture
        )
        guard let cvTexture, let texture = CVMetalTextureGetTexture(cvTexture) else { return nil }
        return (texture, cvTexture)
    }
}

private struct RetainedTexture: @unchecked Sendable {
    let texture: CVMetalTexture?
}
