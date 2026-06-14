import Foundation

struct UserModelRecord {
    var descriptorID: String
    var displayName: String
    var laneRawValue: String
    var modelID: String
    var catalogID: String?
    var resourcePath: String?
    var resourceBookmark: Data?
    var variant: String?
}

enum BuiltInModelID {
    static let appleSystem = "apple.system.default"
    static let privateCloud = "apple.private-cloud.default"
    static let gemma4E2BCoreAI = "coreai.catalog.gemma-4-e2b"
    static let gemma4E4BCoreAI = "coreai.catalog.gemma-4-e4b"
    static let gemma3_4BCoreAI = "coreai.catalog.gemma-3-4b-it"
    static let gemma3_12BCoreAI = "coreai.catalog.gemma-3-12b-it"
    static let gptOSS20BCoreAI = "coreai.catalog.gpt-oss-20b"
}

@main
struct ModelRegistryRemoteTests {
    @MainActor
    static func main() throws {
        try appendsRemoteOnlyCoreAIModelsFromRegistry()
        print("ModelRegistryRemoteTests passed")
    }

    @MainActor
    private static func appendsRemoteOnlyCoreAIModelsFromRegistry() throws {
        let remoteRegistry = try RemoteModelRegistry.decode(Data(Self.registryJSON.utf8))
        let registry = ModelRegistry()

        registry.refresh(remoteRegistry: remoteRegistry)

        let descriptor = try expectValue(
            registry.descriptor(for: "gemma4-e4b-phone-4bit"),
            "remote-only Gemma 4 model should become a descriptor"
        )
        try expect(descriptor.displayName == "Gemma 4 E4B (phone, 4-bit)", "descriptor should use remote registry name")
        try expect(descriptor.modelID == "unsloth/gemma-4-E4B-it", "descriptor should use remote registry model ID")
        try expect(descriptor.catalogSource == "Remote registry", "descriptor should identify remote registry source")
        try expect(descriptor.downloadURL?.absoluteString == "https://example.com/models/gemma4-e4b-coreai/phone-4bit", "descriptor should expose bundle download URL")
        try expect(descriptor.statusLine.contains("2.8 GB"), "descriptor should show bundle download size")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw TestFailure(message)
        }
    }

    private static func expectValue<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw TestFailure(message)
        }
        return value
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }

    private static let registryJSON = """
    {
      "schemaVersion": "1.0",
      "name": "Techopolis Core AI Models",
      "updated": "2026-06-14",
      "baseUrl": "https://example.com/models",
      "models": [
        {
          "id": "gemma-3-4b-it",
          "name": "Gemma 3 4B IT",
          "description": "Gemma 3 4B IT is a 4B-parameter instruction-tuned model.",
          "author": "Gemma Team",
          "hfModelId": "google/gemma-3-4b-it",
          "kind": "llm",
          "numParameters": "4B",
          "license": "Gemma Terms of Use",
          "tokenizer": "google/gemma-3-4b-it",
          "vocabSize": 262208,
          "maxContextLength": 131072,
          "compression": "4bit",
          "variant": "gemma_3_4b_it_4bit_dynamic",
          "aimodel": "gemma_3_4b_it_4bit_dynamic.aimodel",
          "files": [
            {
              "name": "gemma-3-4b-it.zip",
              "url": "https://example.com/models/gemma-3-4b-it.zip",
              "sizeBytes": 1914561360,
              "format": "zip(aimodel)",
              "sha256": "9eff3249600a091995ec5bc76178305b74e8e31c49573fcab275ce0b8e48f88e"
            }
          ]
        },
        {
          "id": "gemma4-e4b-phone-4bit",
          "name": "Gemma 4 E4B (phone, 4-bit)",
          "description": "Gemma 4 E4B converted to Apple's Core AI .aimodel format.",
          "author": "Google (Gemma Team)",
          "hfModelId": "unsloth/gemma-4-E4B-it",
          "kind": "llm",
          "numParameters": "E4B",
          "license": "Gemma Terms of Use",
          "tokenizer": "unsloth/gemma-4-E4B-it",
          "vocabSize": 262144,
          "maxContextLength": 4096,
          "compression": "4bit",
          "variant": "gemma4_e4b_4bit",
          "aimodel": "gemma4_e4b_4bit.aimodel",
          "format": "aimodel-bundle",
          "baseUrl": "https://example.com/models/gemma4-e4b-coreai/phone-4bit",
          "readme": "https://example.com/models/gemma4-e4b-coreai/phone-4bit/README.txt",
          "totalSizeBytes": 2822239911,
          "files": [
            {
              "path": "gemma4_e4b_4bit.aimodel/main.mlirb",
              "url": "https://example.com/models/gemma4-e4b-coreai/phone-4bit/gemma4_e4b_4bit.aimodel/main.mlirb",
              "sizeBytes": 2790050097,
              "sha256": "f63068027f92c48aaa0e67a57f061e4fe06801b3fc8edf6a7bd85c818d1796f8"
            }
          ]
        }
      ]
    }
    """
}
