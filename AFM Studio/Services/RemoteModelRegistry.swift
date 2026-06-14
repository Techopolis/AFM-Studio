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
    var licenseUrl: URL?
    var tokenizer: String
    var vocabSize: Int?
    var maxContextLength: Int?
    var compression: String?
    var variant: String
    var aimodel: String
    var format: String?
    var baseUrl: URL?
    var readme: URL?
    var totalSizeBytes: Int64?
    var files: [RemoteModelFile]

    var primaryFile: RemoteModelFile? {
        files.first
    }

    var installedBundleRelativePath: String {
        "\(id)/\(variant)"
    }

    var formattedSize: String {
        let sizeBytes = totalSizeBytes ?? files.reduce(Int64(0)) { $0 + $1.sizeBytes }
        guard sizeBytes > 0 else {
            return "Unknown size"
        }
        return RemoteModelFile.format(sizeBytes: sizeBytes)
    }

    var downloadURL: URL? {
        baseUrl ?? primaryFile?.url
    }

    var isBundleDownload: Bool {
        format == "aimodel-bundle" || files.contains { $0.path != nil }
    }
}

struct RemoteModelFile: Codable, Equatable, Sendable {
    var name: String
    var path: String?
    var url: URL
    var sizeBytes: Int64
    var format: String?
    var sha256: String

    var relativePath: String {
        path ?? name
    }

    init(
        name: String,
        path: String? = nil,
        url: URL,
        sizeBytes: Int64,
        format: String? = nil,
        sha256: String
    ) {
        self.name = name
        self.path = path
        self.url = url
        self.sizeBytes = sizeBytes
        self.format = format
        self.sha256 = sha256
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let url = try container.decode(URL.self, forKey: .url)
        let path = try container.decodeIfPresent(String.self, forKey: .path)
        let decodedName = try container.decodeIfPresent(String.self, forKey: .name)
        self.name = decodedName ?? path.map { URL(fileURLWithPath: $0).lastPathComponent } ?? url.lastPathComponent
        self.path = path
        self.url = url
        sizeBytes = try container.decode(Int64.self, forKey: .sizeBytes)
        format = try container.decodeIfPresent(String.self, forKey: .format)
        sha256 = try container.decode(String.self, forKey: .sha256)
    }

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

    func destinationURL(in directory: URL) throws -> URL {
        let components = relativePath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard components.isEmpty == false else {
            throw RemoteModelFilePathError.unsafePath(relativePath)
        }

        var destination = directory
        for (index, component) in components.enumerated() {
            guard component.isEmpty == false,
                  component != ".",
                  component != "..",
                  component.contains(":") == false else {
                throw RemoteModelFilePathError.unsafePath(relativePath)
            }
            destination.appendPathComponent(component, isDirectory: index < components.count - 1)
        }

        return destination
    }
}

enum RemoteModelFilePathError: LocalizedError {
    case unsafePath(String)

    var errorDescription: String? {
        switch self {
        case .unsafePath(let value):
            "The registry contains an unsafe file path: \(value)"
        }
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
