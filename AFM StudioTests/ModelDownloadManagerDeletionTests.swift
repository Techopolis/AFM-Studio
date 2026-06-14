import Foundation

struct CoreAIModelCatalogEntry {
    let id: String
    let localBundlePath: String?
}

@main
struct DownloadedModelStoreDeletionTests {
    static func main() throws {
        try deletesInstalledDownloadedModelBundle()
        print("DownloadedModelStoreDeletionTests passed")
    }

    private static func deletesInstalledDownloadedModelBundle() throws {
        let fixture = try TestFixture()
        defer {
            try? FileManager.default.removeItem(at: fixture.root)
        }

        let installedURL = CoreAIModelStore.installedBundleURL(
            for: fixture.model,
            applicationSupportDirectory: fixture.root
        )
        try FileManager.default.createDirectory(at: installedURL, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: installedURL.appendingPathComponent(fixture.model.aimodel))

        try expect(FileManager.default.fileExists(atPath: installedURL.path), "fixture should create installed model")

        try DownloadedModelStore.deleteDownloadedModel(
            fixture.model,
            modelDirectory: CoreAIModelStore.modelDirectoryURL(applicationSupportDirectory: fixture.root)
        )

        try expect(
            FileManager.default.fileExists(atPath: installedURL.path) == false,
            "delete should remove the installed model bundle"
        )
        try expect(
            FileManager.default.fileExists(atPath: installedURL.deletingLastPathComponent().path) == false,
            "delete should remove the empty model parent folder"
        )
    }

    private struct TestFixture {
        let root: URL
        let model: RemoteModel

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("AFMStudioModelDeletionTests-\(UUID().uuidString)", isDirectory: true)
            model = try RemoteModelRegistry.decode(Data(Self.registryJSON.utf8)).models[0]
        }

        private static let registryJSON = """
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

    private static func expect(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw TestFailure(message)
        }
    }

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
