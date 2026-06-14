import CryptoKit
import Foundation
import Observation

#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

enum ModelDownloadStatus: Equatable, Sendable {
    case idle
    case downloading(progress: Double, downloadedBytes: Int64, totalBytes: Int64?)
    case installing
    case installed
    case failed(String)

    var isActive: Bool {
        switch self {
        case .downloading, .installing:
            true
        case .idle, .installed, .failed:
            false
        }
    }
}

enum RegistryRefreshStatus: Equatable, Sendable {
    case idle
    case refreshing
    case ready(String)
    case failed(String)
}

enum ModelDownloadError: LocalizedError {
    case missingFile(RemoteModel)
    case checksumMismatch(expected: String, actual: String)
    case zipSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .missingFile(let model):
            "The registry entry for \(model.name) does not include a downloadable file."
        case .checksumMismatch(let expected, let actual):
            "Checksum mismatch. Expected \(expected), got \(actual)."
        case .zipSupportUnavailable:
            "ZIP extraction support is not linked in this build."
        }
    }
}

@MainActor
@Observable
final class ModelDownloadManager {
    static let defaultRegistryURL = URL(
        string: "https://techopolis-storage.nyc3.digitaloceanspaces.com/AFM%20Studio/registry.json"
    )!

    private(set) var registry: RemoteModelRegistry?
    private(set) var registryStatus: RegistryRefreshStatus = .idle
    private(set) var downloadStatuses: [String: ModelDownloadStatus] = [:]

    private let registryURL: URL
    private let cache: RemoteModelRegistryCache
    private let modelDirectory: URL
    private let downloadDirectory: URL
    private var activeDownloads: [String: RemoteModelDownloadRequest] = [:]

    init(
        registryURL: URL = ModelDownloadManager.defaultRegistryURL,
        applicationSupportDirectory: URL? = nil
    ) {
        self.registryURL = registryURL
        let supportRoot = CoreAIModelStore.applicationSupportRoot(
            applicationSupportDirectory: applicationSupportDirectory
        )
        cache = RemoteModelRegistryCache(baseDirectory: supportRoot)
        modelDirectory = CoreAIModelStore.modelDirectoryURL(
            applicationSupportDirectory: applicationSupportDirectory
        )
        downloadDirectory = supportRoot.appendingPathComponent("Downloads", isDirectory: true)
        loadCachedRegistry()
    }

    func loadCachedRegistry() {
        do {
            registry = try cache.load()
            if let registry {
                registryStatus = .ready("Using cached registry from \(registry.updated)")
            }
        } catch {
            registryStatus = .failed(error.localizedDescription)
        }
    }

    func refreshRegistry() async {
        registryStatus = .refreshing

        do {
            let (data, response) = try await URLSession.shared.data(from: registryURL)
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) == false {
                throw URLError(.badServerResponse)
            }

            let remoteRegistry = try RemoteModelRegistry.decode(data)
            try cache.save(remoteRegistry)
            registry = remoteRegistry
            registryStatus = .ready("Updated \(remoteRegistry.updated)")
        } catch {
            registryStatus = .failed(error.localizedDescription)
        }
    }

    func remoteModel(for descriptor: ModelDescriptor) -> RemoteModel? {
        registry?.models.first { remoteModel in
            remoteModel.hfModelId == descriptor.modelID ||
            remoteModel.id == descriptor.catalogID ||
            remoteModel.id == descriptor.id
        }
    }

    func status(for modelID: String) -> ModelDownloadStatus {
        downloadStatuses[modelID] ?? .idle
    }

    func cancelDownload(for modelID: String) {
        activeDownloads[modelID]?.cancel()
        activeDownloads[modelID] = nil
        downloadStatuses[modelID] = .idle
    }

    func isDownloaded(_ model: RemoteModel) -> Bool {
        DownloadedModelStore.containsDownloadedModel(model, modelDirectory: modelDirectory)
    }

    func deleteDownloadedModel(_ model: RemoteModel) throws {
        cancelDownload(for: model.id)
        try DownloadedModelStore.deleteDownloadedModel(model, modelDirectory: modelDirectory)
        let workDirectory = downloadDirectory.appendingPathComponent(model.id, isDirectory: true)
        try FileManager.default.removeItemIfExists(at: workDirectory)
        downloadStatuses[model.id] = .idle
    }

    func download(_ model: RemoteModel) async {
        guard status(for: model.id).isActive == false else {
            return
        }

        guard model.files.isEmpty == false else {
            downloadStatuses[model.id] = .failed(ModelDownloadError.missingFile(model).localizedDescription)
            return
        }

        let workDirectory = downloadDirectory.appendingPathComponent(model.id, isDirectory: true)

        do {
            try FileManager.default.removeItemIfExists(at: workDirectory)
            try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)

            if model.isBundleDownload {
                try await downloadBundle(model, workDirectory: workDirectory)
            } else {
                try await downloadZipArchive(model, workDirectory: workDirectory)
            }

            try FileManager.default.removeItemIfExists(at: workDirectory)
            downloadStatuses[model.id] = .installed
        } catch is CancellationError {
            activeDownloads[model.id] = nil
            try? FileManager.default.removeItemIfExists(at: workDirectory)
            downloadStatuses[model.id] = .idle
        } catch {
            activeDownloads[model.id] = nil
            try? FileManager.default.removeItemIfExists(at: workDirectory)
            downloadStatuses[model.id] = .failed(error.localizedDescription)
        }
    }

    private func downloadZipArchive(_ model: RemoteModel, workDirectory: URL) async throws {
        guard let file = model.primaryFile else {
            throw ModelDownloadError.missingFile(model)
        }

        let zipURL = workDirectory.appendingPathComponent(file.name, isDirectory: false)
        let extractDirectory = workDirectory.appendingPathComponent("extracted", isDirectory: true)
        try await downloadFile(
            file,
            to: zipURL,
            modelID: model.id,
            progressOffset: 0,
            totalBytes: file.sizeBytes
        )

        downloadStatuses[model.id] = .installing
        try FileManager.default.createDirectory(at: extractDirectory, withIntermediateDirectories: true)
        try unzipItem(at: zipURL, to: extractDirectory)
        _ = try RemoteModelArchiveInstaller.installExtractedArchive(
            at: extractDirectory,
            for: model,
            modelDirectory: modelDirectory
        )
    }

    private func downloadBundle(_ model: RemoteModel, workDirectory: URL) async throws {
        let bundleDirectory = workDirectory.appendingPathComponent("bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleDirectory, withIntermediateDirectories: true)

        let totalBytes = model.totalSizeBytes ?? model.files.reduce(Int64(0)) { $0 + $1.sizeBytes }
        var downloadedBytes: Int64 = 0
        for file in model.files {
            let destinationURL = try file.destinationURL(in: bundleDirectory)
            try await downloadFile(
                file,
                to: destinationURL,
                modelID: model.id,
                progressOffset: downloadedBytes,
                totalBytes: totalBytes
            )
            downloadedBytes += file.sizeBytes
        }

        downloadStatuses[model.id] = .installing
        _ = try RemoteModelArchiveInstaller.installExtractedArchive(
            at: bundleDirectory,
            for: model,
            modelDirectory: modelDirectory
        )
    }

    private func downloadFile(
        _ file: RemoteModelFile,
        to destinationURL: URL,
        modelID: String,
        progressOffset: Int64,
        totalBytes: Int64
    ) async throws {
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        downloadStatuses[modelID] = .downloading(
            progress: Double(progressOffset) / Double(max(totalBytes, 1)),
            downloadedBytes: progressOffset,
            totalBytes: totalBytes
        )
        let request = RemoteModelDownloadRequest(destinationURL: destinationURL) { [weak self] downloadedBytes, _ in
            Task { @MainActor in
                let expectedBytes = max(totalBytes, 1)
                let completedBytes = min(progressOffset + downloadedBytes, expectedBytes)
                let progress = min(Double(completedBytes) / Double(expectedBytes), 1)
                self?.downloadStatuses[modelID] = .downloading(
                    progress: progress,
                    downloadedBytes: completedBytes,
                    totalBytes: expectedBytes
                )
            }
        }
        activeDownloads[modelID] = request
        _ = try await request.download(from: file.url)
        activeDownloads[modelID] = nil

        let actualHash = try RemoteModelChecksum.sha256Hex(for: destinationURL)
        guard actualHash.lowercased() == file.sha256.lowercased() else {
            throw ModelDownloadError.checksumMismatch(expected: file.sha256, actual: actualHash)
        }
    }

    private func unzipItem(at zipURL: URL, to destinationURL: URL) throws {
        #if canImport(ZIPFoundation)
        try FileManager.default.unzipItem(at: zipURL, to: destinationURL)
        #else
        throw ModelDownloadError.zipSupportUnavailable
        #endif
    }
}

enum RemoteModelChecksum {
    static func sha256Hex(for fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), data.isEmpty == false {
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private final class RemoteModelDownloadRequest: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destinationURL: URL
    private let progressHandler: @Sendable (Int64, Int64?) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var downloadedURL: URL?
    private var task: URLSessionDownloadTask?
    private var session: URLSession?

    init(
        destinationURL: URL,
        progressHandler: @escaping @Sendable (Int64, Int64?) -> Void
    ) {
        self.destinationURL = destinationURL
        self.progressHandler = progressHandler
    }

    func download(from url: URL) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock {
                    self.continuation = continuation
                    let session = URLSession(
                        configuration: .default,
                        delegate: self,
                        delegateQueue: nil
                    )
                    self.session = session
                    let task = session.downloadTask(with: url)
                    self.task = task
                    task.resume()
                }
            }
        } onCancel: {
            cancel()
        }
    }

    func cancel() {
        lock.withLock {
            task?.cancel()
            task = nil
            session?.invalidateAndCancel()
            session = nil
            continuation?.resume(throwing: CancellationError())
            continuation = nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
        progressHandler(totalBytesWritten, expected)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            try FileManager.default.removeItemIfExists(at: destinationURL)
            try FileManager.default.moveItem(at: location, to: destinationURL)
            lock.withLock {
                downloadedURL = destinationURL
            }
        } catch {
            finish(with: .failure(error))
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        if let error {
            finish(with: .failure(error))
            return
        }

        lock.withLock {
            guard let downloadedURL else {
                continuation?.resume(throwing: URLError(.unknown))
                continuation = nil
                self.session?.finishTasksAndInvalidate()
                self.session = nil
                self.task = nil
                return
            }

            continuation?.resume(returning: downloadedURL)
            continuation = nil
            self.session?.finishTasksAndInvalidate()
            self.session = nil
            self.task = nil
        }
    }

    private func finish(with result: Result<URL, any Error>) {
        lock.withLock {
            switch result {
            case .success(let url):
                continuation?.resume(returning: url)
            case .failure(let error):
                continuation?.resume(throwing: error)
            }
            continuation = nil
            session?.finishTasksAndInvalidate()
            session = nil
            task = nil
        }
    }
}

private extension FileManager {
    func removeItemIfExists(at url: URL) throws {
        if fileExists(atPath: url.path) {
            try removeItem(at: url)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ work: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try work()
    }
}
