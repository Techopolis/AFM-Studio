import Foundation

enum CoreAIModelCatalogSource: String, Codable, Sendable {
    case appleCoreAIModels
    case communityModelZoo

    var title: String {
        switch self {
        case .appleCoreAIModels:
            "Apple coreai-models"
        case .communityModelZoo:
            "Community CoreAI model zoo"
        }
    }
}

enum CoreAIModelPlatform: String, Codable, CaseIterable, Sendable {
    case macOS
    case iOS
}

struct CoreAIModelCatalogEntry: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var modelID: String
    var family: String
    var source: CoreAIModelCatalogSource
    var platforms: [CoreAIModelPlatform]
    var parameters: String?
    var license: String
    var compression: String
    var computePrecision: String?
    var maxContextLength: Int?
    var downloadURL: URL?
    var modelCardURL: URL
    var exportCommand: String
    var localBundlePath: String?
    var statusLine: String

    var platformSummary: String {
        platforms.map(\.rawValue).joined(separator: ", ")
    }
}

enum CoreAIModelCatalog {
    static let entries: [CoreAIModelCatalogEntry] = [
        CoreAIModelCatalogEntry(
            id: BuiltInModelID.gemma4E2BCoreAI,
            displayName: "Gemma 4 E2B (Core AI)",
            modelID: "google/gemma-4-E2B-it",
            family: "Gemma 4",
            source: .communityModelZoo,
            platforms: [.macOS, .iOS],
            parameters: "E2B",
            license: "Gemma",
            compression: "official QAT int4 / Core AI bundle",
            computePrecision: "bfloat16 source, int4 Core AI bundle",
            maxContextLength: nil,
            downloadURL: URL(string: "https://huggingface.co/mlboydaisuke/gemma-4-E2B-CoreAI")!,
            modelCardURL: URL(string: "https://github.com/john-rocky/coreai-model-zoo/blob/main/zoo/gemma4-e2b.md")!,
            exportCommand: "Use mlboydaisuke/gemma-4-E2B-CoreAI or the zoo conversion/export_gemma4_decode_pipelined.py recipe.",
            localBundlePath: nil,
            statusLine: "Community Core AI bundle - iOS/macOS - E2B text decoder"
        ),
        CoreAIModelCatalogEntry(
            id: BuiltInModelID.gemma4E4BCoreAI,
            displayName: "Gemma 4 E4B (Core AI)",
            modelID: "google/gemma-4-E4B-it-qat-q4_0-unquantized",
            family: "Gemma 4",
            source: .communityModelZoo,
            platforms: [.macOS, .iOS],
            parameters: "E4B",
            license: "Gemma",
            compression: "official QAT int4 / Core AI bundle",
            computePrecision: "bfloat16 source, int4 Core AI bundle",
            maxContextLength: nil,
            downloadURL: URL(string: "https://huggingface.co/mlboydaisuke/gemma-4-E4B-CoreAI")!,
            modelCardURL: URL(string: "https://github.com/john-rocky/coreai-model-zoo/blob/main/zoo/gemma4-e4b.md")!,
            exportCommand: "Use mlboydaisuke/gemma-4-E4B-CoreAI or the zoo conversion/export_gemma4_decode_pipelined.py recipe.",
            localBundlePath: nil,
            statusLine: "Community Core AI bundle - iOS/macOS - official QAT int4"
        ),
        CoreAIModelCatalogEntry(
            id: BuiltInModelID.gemma3_4BCoreAI,
            displayName: "Gemma 3 4B Instruct (Core AI)",
            modelID: "google/gemma-3-4b-it",
            family: "Gemma 3",
            source: .appleCoreAIModels,
            platforms: [.macOS],
            parameters: "4B",
            license: "Gemma Terms of Use",
            compression: "4bit",
            computePrecision: "bfloat16",
            maxContextLength: 131_072,
            downloadURL: nil,
            modelCardURL: URL(string: "https://github.com/apple/coreai-models/blob/main/models/gemma3/README.md")!,
            exportCommand: "uv run coreai.llm.export google/gemma-3-4b-it",
            localBundlePath: "gemma-3-4b-it/gemma_3_4b_it_4bit_dynamic",
            statusLine: "Apple coreai-models preset - macOS - 4bit bfloat16"
        ),
        CoreAIModelCatalogEntry(
            id: BuiltInModelID.gemma3_12BCoreAI,
            displayName: "Gemma 3 12B Instruct (Core AI)",
            modelID: "google/gemma-3-12b-it",
            family: "Gemma 3",
            source: .appleCoreAIModels,
            platforms: [.macOS],
            parameters: "12B",
            license: "Gemma Terms of Use",
            compression: "4bit",
            computePrecision: "bfloat16",
            maxContextLength: 131_072,
            downloadURL: nil,
            modelCardURL: URL(string: "https://github.com/apple/coreai-models/blob/main/models/gemma3/README.md")!,
            exportCommand: "uv run coreai.llm.export google/gemma-3-12b-it",
            localBundlePath: "gemma-3-12b-it/gemma_3_12b_it_4bit_dynamic",
            statusLine: "Apple coreai-models preset - macOS - 4bit bfloat16"
        ),
        CoreAIModelCatalogEntry(
            id: BuiltInModelID.gptOSS20BCoreAI,
            displayName: "GPT-OSS 20B (Core AI)",
            modelID: "openai/gpt-oss-20b",
            family: "GPT-OSS",
            source: .appleCoreAIModels,
            platforms: [.macOS],
            parameters: "20B",
            license: "GPT-OSS model license",
            compression: "none (pre-quantized MXFP4)",
            computePrecision: "bfloat16",
            maxContextLength: 32_768,
            downloadURL: nil,
            modelCardURL: URL(string: "https://github.com/apple/coreai-models/blob/main/models/gpt_oss/README.md")!,
            exportCommand: "uv run coreai.llm.export openai/gpt-oss-20b",
            localBundlePath: "gpt-oss-20b/gpt_oss_20b_dynamic",
            statusLine: "Apple coreai-models preset - macOS - pre-quantized MXFP4"
        )
    ]

    static func entry(id: String) -> CoreAIModelCatalogEntry? {
        entries.first { $0.id == id }
    }
}
