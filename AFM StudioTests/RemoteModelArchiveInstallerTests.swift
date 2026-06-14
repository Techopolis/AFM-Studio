import Foundation

@main
struct RemoteModelArchiveInstallerTests {
    static func main() throws {
        try installsVariantFolderFromExtractedArchive()
        try installsFlatResourceFolderFromExtractedArchive()
        print("RemoteModelArchiveInstallerTests passed")
    }

    private static func installsVariantFolderFromExtractedArchive() throws {
        let fixture = try TestFixture()
        let extractedVariant = fixture.extracted
            .appendingPathComponent("gemma_3_4b_it_4bit_dynamic", isDirectory: true)
        try FileManager.default.createDirectory(at: extractedVariant, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: extractedVariant.appendingPathComponent("tokenizer", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("model".utf8).write(to: extractedVariant.appendingPathComponent("gemma_3_4b_it_4bit_dynamic.aimodel"))

        let installedURL = try RemoteModelArchiveInstaller.installExtractedArchive(
            at: fixture.extracted,
            for: fixture.model,
            modelDirectory: fixture.modelDirectory
        )

        try expect(installedURL.path == fixture.modelDirectory.appendingPathComponent("gemma-3-4b-it/gemma_3_4b_it_4bit_dynamic").path, "installer should return the Core AI resource folder")
        try expect(FileManager.default.fileExists(atPath: installedURL.appendingPathComponent("tokenizer").path), "tokenizer should be installed")
        try expect(FileManager.default.fileExists(atPath: installedURL.appendingPathComponent("gemma_3_4b_it_4bit_dynamic.aimodel").path), "aimodel should be installed")
    }

    private static func installsFlatResourceFolderFromExtractedArchive() throws {
        let fixture = try TestFixture()
        try FileManager.default.createDirectory(
            at: fixture.extracted.appendingPathComponent("tokenizer", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data("model".utf8).write(to: fixture.extracted.appendingPathComponent("gemma_3_4b_it_4bit_dynamic.aimodel"))

        let installedURL = try RemoteModelArchiveInstaller.installExtractedArchive(
            at: fixture.extracted,
            for: fixture.model,
            modelDirectory: fixture.modelDirectory
        )

        try expect(FileManager.default.fileExists(atPath: installedURL.appendingPathComponent("tokenizer").path), "flat tokenizer should be installed")
        try expect(FileManager.default.fileExists(atPath: installedURL.appendingPathComponent("gemma_3_4b_it_4bit_dynamic.aimodel").path), "flat aimodel should be installed")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if condition == false {
            throw TestFailure(message)
        }
    }

    private struct TestFixture {
        let root: URL
        let extracted: URL
        let modelDirectory: URL
        let model: RemoteModel

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("AFMStudioArchiveInstallerTests-\(UUID().uuidString)", isDirectory: true)
            extracted = root.appendingPathComponent("extracted", isDirectory: true)
            modelDirectory = root.appendingPathComponent("CoreAIModels", isDirectory: true)
            try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
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

    private struct TestFailure: Error, CustomStringConvertible {
        var description: String

        init(_ description: String) {
            self.description = description
        }
    }
}
