import CoreVideo
import GorgeeCore
import Testing
@testable import GorgeeDetection

@Suite("Moteur de preuve")
struct ProofRunnerTests {
    struct JudgeDown: Error {}

    static func blankFrame() throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer)
        return try #require(status == kCVReturnSuccess ? buffer : nil)
    }

    @Test("Une panne du juge n'est pas déguisée en « pas de verre »")
    func judgeErrorsAreReported() async throws {
        let runner = ProofRunner(startedAt: 0, judge: { _ in throw JudgeDown() })
        let frame = try Self.blankFrame()
        for time in [0.0, 1.3, 2.6] {
            await runner.process(frame, at: time)
        }
        #expect(runner.step == .showContainer)
        #expect(runner.lastVerdict == nil)
        #expect(runner.judgeFailures == 3)
    }
}
