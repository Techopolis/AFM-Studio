import Foundation

struct RemoteModelRegistry: Codable, Equatable, Sendable {
    var schemaVersion: String
    var name: String
    var updated: String
    var baseUrl: URL
    var note: String?
    var models: [RemoteModel]

    static func decode(_ data: Data) throws -> RemoteModelRegistry {
        try JSONDecoder().decode(RemoteModelRegistry.self, from: data)
    }

    func model(id: String) -> RemoteModel? {
        models.first { $0.id == id }
    }
}

struct RemoteModel: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var description: String
    var author: String
    var hfModelId: String
    var kind: String
    var numParameters: String
    var license: String
    var tokenizer: String
    var vocabSize: Int?
    var maxContextLength: Int?
    var compression: String?
    var variant: String
    var aimodel: String
    var files: [RemoteModelFile]

    var primaryFile: RemoteModelFile? {
        files.first
    }

    var installedBundleRelativePath: String {
        "\(id)/\(variant)"
    }

    var formattedSize: String {
        guard let sizeBytes = primaryFile?.sizeBytes else {
            return "Unknown size"
        }
        return RemoteModelFile.format(sizeBytes: sizeBytes)
    }
}

struct RemoteModelFile: Codable, Equatable, Sendable {
    var name: String
    var url: URL
    var sizeBytes: Int64
    var format: String
    var sha256: String

    static func format(sizeBytes: Int64) -> String {
        let value = Double(sizeBytes)
        let units: [(suffix: String, bytes: Double)] = [
            ("TB", 1_000_000_000_000),
            ("GB", 1_000_000_000),
            ("MB", 1_000_000),
            ("KB", 1_000)
        ]

        for unit in units where value >= unit.bytes {
            return String(format: "%.1f %@", value / unit.bytes, unit.suffix)
        }

        return "\(sizeBytes) bytes"
    }
}

struct RemoteModelRegistryCache: Sendable {
    var baseDirectory: URL

    var registryFileURL: URL {
        baseDirectory
            .appendingPathComponent("Registry", isDirectory: true)
            .appendingPathComponent("registry.json", isDirectory: false)
    }

    func load() throws -> RemoteModelRegistry? {
        guard FileManager.default.fileExists(atPath: registryFileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: registryFileURL)
        return try RemoteModelRegistry.decode(data)
    }

    func save(_ registry: RemoteModelRegistry) throws {
        try FileManager.default.createDirectory(
            at: registryFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(registry)
        try data.write(to: registryFileURL, options: .atomic)
    }
}
