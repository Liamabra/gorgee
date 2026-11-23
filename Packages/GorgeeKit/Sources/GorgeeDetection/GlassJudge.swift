import CoreVideo
import FoundationModels
import GorgeeCore

@Generable
enum JudgedContainer: Equatable {
    case transparentGlass
    case transparentBottle
    case opaqueContainer
    case noContainer
}

@Generable
enum JudgedLiquid: Equatable {
    case clearColorless
    case tinted
    case opaque
    case empty
}

@Generable
struct ContainerJudgement: Equatable {
    @Guide(description: "The drinking container the person holds up or shows to the camera")
    var container: JudgedContainer
    @Guide(description: "What the container holds")
    var liquid: JudgedLiquid
    @Guide(description: "How full the container is, in quarters: 0 empty, 4 full", .range(0...4))
    var fillQuarters: Int

    init(container: JudgedContainer, liquid: JudgedLiquid, fillQuarters: Int) {
        self.container = container
        self.liquid = liquid
        self.fillQuarters = fillQuarters
    }
}

/// Le modèle embarqué d'Apple regarde l'image et dit ce que l'utilisateur tient. Rien ne quitte le Mac.
public struct GlassJudge: Sendable {
    static let instructions = """
        You inspect webcam images of a person showing a drinking container. Judge only what is visible.
        A glass or a plastic bottle you can see through is transparent; a mug, can, cup or metal bottle is opaque.
        A clear, colorless liquid such as water is clearColorless. Any tint (cola, juice, coffee, tea, soda) is tinted.
        Milk, smoothies and similar are opaque.
        """

    public init() {}

    public static var isAvailable: Bool {
        let model = SystemLanguageModel.default
        return model.availability == .available && model.capabilities.contains(.vision)
    }

    public nonisolated(nonsending) func judge(_ pixelBuffer: CVPixelBuffer) async throws -> ContainerVerdict {
        let session = LanguageModelSession(model: .default, instructions: Self.instructions)
        let response = try await session.respond(
            generating: ContainerJudgement.self,
            options: GenerationOptions(samplingMode: .greedy)
        ) {
            "Judge the drinking container in this image."
            Attachment(pixelBuffer)
        }
        return Self.verdict(for: response.content)
    }

    static func verdict(for judgement: ContainerJudgement) -> ContainerVerdict {
        switch judgement.container {
        case .noContainer: return .noContainer
        case .opaqueContainer: return .opaqueContainer
        case .transparentGlass, .transparentBottle: break
        }
        switch judgement.liquid {
        case .empty: return .emptyContainer
        case .tinted: return .coloredLiquid
        case .opaque: return .opaqueLiquid
        case .clearColorless:
            guard judgement.fillQuarters > 0 else { return .emptyContainer }
            return .clearLiquid(fillQuarters: min(4, judgement.fillQuarters))
        }
    }
}
