import GorgeeCore
import Testing
@testable import GorgeeDetection

@Suite("Juge du récipient")
struct GlassJudgeTests {
    @Test("Le jugement du modèle se traduit en verdict", arguments: [
        (JudgedContainer.transparentGlass, JudgedLiquid.clearColorless, 3, ContainerVerdict.clearLiquid(fillQuarters: 3)),
        (.transparentBottle, .clearColorless, 4, .clearLiquid(fillQuarters: 4)),
        (.transparentGlass, .tinted, 4, .coloredLiquid),
        (.transparentGlass, .opaque, 2, .opaqueLiquid),
        (.transparentGlass, .empty, 0, .emptyContainer),
        (.opaqueContainer, .clearColorless, 4, .opaqueContainer),
        (.noContainer, .clearColorless, 4, .noContainer),
    ])
    func mapsJudgement(container: JudgedContainer, liquid: JudgedLiquid, quarters: Int, expected: ContainerVerdict) {
        let judgement = ContainerJudgement(container: container, liquid: liquid, fillQuarters: quarters)
        #expect(GlassJudge.verdict(for: judgement) == expected)
    }

    @Test("Un liquide incolore à niveau zéro compte comme un verre vide")
    func clearButZeroIsEmpty() {
        let judgement = ContainerJudgement(container: .transparentGlass, liquid: .clearColorless, fillQuarters: 0)
        #expect(GlassJudge.verdict(for: judgement) == .emptyContainer)
    }

    @Test("Un niveau hors bornes est ramené entre 1 et 4")
    func fillIsClamped() {
        let judgement = ContainerJudgement(container: .transparentGlass, liquid: .clearColorless, fillQuarters: 9)
        #expect(GlassJudge.verdict(for: judgement) == .clearLiquid(fillQuarters: 4))
    }
}
