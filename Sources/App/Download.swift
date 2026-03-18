import Foundation

public enum DownloadStatus: String, Codable, CaseIterable {
    case pending
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

public struct Download: Identifiable, Codable, Hashable {
    public let id: UUID
    public let url: URL
    public var destinationFolder: URL
    public var filename: String
    public var status: DownloadStatus
    public var totalBytes: Int64
    public var downloadedBytes: Int64
    public var speed: Double
    public var errorMessage: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        url: URL,
        destinationFolder: URL,
        filename: String? = nil,
        status: DownloadStatus = .pending,
        totalBytes: Int64 = 0,
        downloadedBytes: Int64 = 0,
        speed: Double = 0,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.destinationFolder = destinationFolder
        self.filename = filename ?? url.lastPathComponent
        self.status = status
        self.totalBytes = totalBytes
        self.downloadedBytes = downloadedBytes
        self.speed = speed
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    public var formattedDownloaded: String {
        ByteCountFormatter.string(fromByteCount: downloadedBytes, countStyle: .file)
    }

    public var formattedSpeed: String {
        guard speed > 0 else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }
}
