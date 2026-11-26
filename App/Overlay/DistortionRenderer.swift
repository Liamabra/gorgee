import CoreGraphics
import GorgeeCore
import Metal

/// Même disposition mémoire que `DroughtUniforms` dans `DroughtShader.source`.
struct DroughtUniforms {
    var viewSize: SIMD2<Float>
    var cellSize: SIMD2<Float>
    var severity: Float
    var time: Float
    var rampWidth: Float
    var columns: Int32
    var rows: Int32
}

/// Même disposition mémoire que `MudSite` dans `DroughtShader.source`.
struct MudSiteGPU {
    var position: SIMD2<Float>
    var reveal: Float
    var shade: Float
}

/// Dessine la copie déformée de l'écran avec le shader de sécheresse.
final class DistortionRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    init?(pixelFormat: MTLPixelFormat = .bgra8Unorm) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = try? device.makeLibrary(source: DroughtShader.source, options: nil),
              let commandQueue = device.makeCommandQueue()
        else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "droughtVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "droughtFragment")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        self.device = device
        self.commandQueue = commandQueue
        self.pipeline = pipeline
    }

    /// Les germes du sol, rangés comme la grille que parcourt le shader.
    func makeSites(for tiling: MudTiling) -> MTLBuffer? {
        let sites = tiling.grid.map {
            MudSiteGPU(position: SIMD2(Float($0.site.x), Float($0.site.y)), reveal: Float($0.reveal), shade: Float($0.shade))
        }
        return device.makeBuffer(bytes: sites, length: MemoryLayout<MudSiteGPU>.stride * sites.count)
    }

    func encode(
        _ encoder: MTLRenderCommandEncoder,
        screen: MTLTexture,
        sites: MTLBuffer,
        tiling: MudTiling,
        severity: Double,
        time: Double
    ) {
        var uniforms = DroughtUniforms(
            viewSize: SIMD2(Float(tiling.width), Float(tiling.height)),
            cellSize: SIMD2(Float(tiling.width / Double(tiling.columns)), Float(tiling.height / Double(tiling.rows))),
            severity: Float(severity),
            time: Float(time.truncatingRemainder(dividingBy: 3600)),
            rampWidth: Float(MudTiling.rampWidth),
            columns: Int32(tiling.columns),
            rows: Int32(tiling.rows)
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(screen, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<DroughtUniforms>.stride, index: 0)
        encoder.setFragmentBuffer(sites, offset: 0, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    /// Redessine l'image en BGRA 8 bits : MTKTextureLoader refuse les images à gamme étendue de SwiftUI.
    private func makeTexture(from image: CGImage) -> MTLTexture? {
        let bytesPerRow = image.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: image.width, height: image.height, mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        guard drawn, let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: bytesPerRow)
        return texture
    }

    /// Rendu hors écran d'une image, pour les aperçus de debug.
    func render(_ image: CGImage, tiling: MudTiling, severity: Double, time: Double = 0) -> CGImage? {
        guard let screen = makeTexture(from: image), let sites = makeSites(for: tiling) else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: image.width, height: image.height, mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let target = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer()
        else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encode(encoder, screen: screen, sites: sites, tiling: tiling, severity: severity, time: time)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let bytesPerRow = image.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        target.getBytes(&pixels, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }
}
