import Foundation

@main
struct RemoteModelRegistryTests {
    static func main() throws {
        try decodesRegistryAndDerivesInstallPath()
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
}
