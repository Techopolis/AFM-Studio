import Foundation

@main
struct RemoteModelRegistryTests {
    static func main() throws {
        try decodesRegistryAndDerivesInstallPath()
        try decodesBundleRegistryAndDerivesRemoteLayout()
        try savesAndLoadsCachedRegistry()
        print("RemoteModelRegistryTests passed")
    }

    private static func decodesRegistryAndDerivesInstallPath() throws {
        let data = Data(Self.sampleRegistry.utf8)
        let registry = try RemoteModelRegistry.decode(data)
        try expect(registry.schemaVersion == "1.0", "schema version should decode")
        try expect(registry.models.count == 1, "one model should decode")

        let model = try expectValue(registry.model(id: "gemma-3-4b-it"), "model lookup should work")
        try expect(model.name == "Gemma 3 4B IT", "model name should decode")
        try expect(model.primaryFile?.sizeBytes == 1_914_561_360, "primary file size should decode")
        try expect(model.primaryFile?.sha256 == "9eff3249600a091995ec5bc76178305b74e8e31c49573fcab275ce0b8e48f88e", "sha should decode")
        try expect(model.installedBundleRelativePath == "gemma-3-4b-it/gemma_3_4b_it_4bit_dynamic", "install path should use id plus variant folder")
        try expect(model.formattedSize == "1.9 GB", "formatted size should be compact")
    }

    private static func decodesBundleRegistryAndDerivesRemoteLayout() throws {
        let data = Data(Self.bundleRegistry.utf8)
        let registry = try RemoteModelRegistry.decode(data)
        let model = try expectValue(registry.model(id: "gemma4-e4b-phone-4bit"), "bundle model lookup should work")

        try expect(model.format == "aimodel-bundle", "top-level download format should decode")
        try expect(model.baseUrl?.absoluteString == "https://example.com/models/gemma4-e4b-coreai/phone-4bit", "bundle base URL should decode")
        try expect(model.readme?.absoluteString == "https://example.com/models/gemma4-e4b-coreai/phone-4bit/README.txt", "bundle readme should decode")
        try expect(model.formattedSize == "2.8 GB", "bundle formatted size should use totalSizeBytes")

        let mainFile = try expectValue(
            model.files.first { $0.path == "gemma4_e4b_4bit.aimodel/main.mlirb" },
            "bundle file path should decode"
        )
        try expect(mainFile.name == "main.mlirb", "bundle files without name should derive one from the path")
        try expect(mainFile.relativePath == "gemma4_e4b_4bit.aimodel/main.mlirb", "bundle download should preserve relative path")

        let destination = try mainFile.destinationURL(
            in: URL(fileURLWithPath: "/tmp/AFMStudioBundleDownload", isDirectory: true)
        )
        try expect(
            destination.path.hasSuffix("/AFMStudioBundleDownload/gemma4_e4b_4bit.aimodel/main.mlirb"),
            "bundle file destination should preserve nested Core AI paths"
        )
        try expectThrows("unsafe registry paths should be rejected") {
            _ = try RemoteModelFile(
                name: "escape",
                path: "../escape",
                url: URL(string: "https://example.com/escape")!,
                sizeBytes: 1,
                sha256: "abc"
            ).destinationURL(in: URL(fileURLWithPath: "/tmp/AFMStudioBundleDownload", isDirectory: true))
        }
    }

    private static func savesAndLoadsCachedRegistry() throws {
        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AFMStudioRemoteModelRegistryTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: cacheRoot)
        }

        let data = Data(Self.sampleRegistry.utf8)
        let registry = try RemoteModelRegistry.decode(data)
        let cache = RemoteModelRegistryCache(baseDirectory: cacheRoot)
        try cache.save(registry)

        let loaded = try expectValue(cache.load(), "cached registry should load")
        try expect(loaded.updated == "2026-06-14", "cached registry should preserve metadata")
        try expect(loaded.model(id: "gemma-3-4b-it")?.variant == "gemma_3_4b_it_4bit_dynamic", "cached registry should preserve models")
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

    private static func expectThrows(_ message: String, operation: () throws -> Void) throws {
        do {
            try operation()
        } catch {
            return
        }

        throw TestFailure(message)
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }

    private static let sampleRegistry = """
    {
      "schemaVersion": "1.0",
      "name": "AFM Studio Models",
      "updated": "2026-06-14",
      "baseUrl": "https://techopolis-storage.nyc3.digitaloceanspaces.com/AFM%20Studio",
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
              "url": "https://techopolis-storage.nyc3.digitaloceanspaces.com/AFM%20Studio/gemma-3-4b-it.zip",
              "sizeBytes": 1914561360,
              "format": "zip(aimodel)",
              "sha256": "9eff3249600a091995ec5bc76178305b74e8e31c49573fcab275ce0b8e48f88e"
            }
          ]
        }
      ]
    }
    """

    private static let bundleRegistry = """
    {
      "schemaVersion": "1.0",
      "name": "Techopolis Core AI Models",
      "updated": "2026-06-14",
      "baseUrl": "https://example.com/models",
      "models": [
        {
          "id": "gemma4-e4b-phone-4bit",
          "name": "Gemma 4 E4B (phone, 4-bit)",
          "description": "Gemma 4 E4B converted to Apple's Core AI .aimodel format.",
          "author": "Google (Gemma Team)",
          "hfModelId": "unsloth/gemma-4-E4B-it",
          "kind": "llm",
          "numParameters": "E4B",
          "license": "Gemma Terms of Use",
          "licenseUrl": "https://ai.google.dev/gemma/terms",
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
            },
            {
              "path": "tokenizer/tokenizer.json",
              "url": "https://example.com/models/gemma4-e4b-coreai/phone-4bit/tokenizer/tokenizer.json",
              "sizeBytes": 32169626,
              "sha256": "cc8d3a0ce36466ccc1278bf987df5f71db1719b9ca6b4118264f45cb627bfe0f"
            }
          ]
        }
      ]
    }
    """
}
