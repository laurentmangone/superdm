import Foundation
import SQLite

public class Database {
    public static let shared = Database()

    private var db: Connection?
    private let downloads = Table("downloads")

    private let id = SQLite.Expression<String>("id")
    private let url = SQLite.Expression<String>("url")
    private let destinationFolder = SQLite.Expression<String>("destination_folder")
    private let filename = SQLite.Expression<String>("filename")
    private let status = SQLite.Expression<String>("status")
    private let totalBytes = SQLite.Expression<Int64>("total_bytes")
    private let downloadedBytes = SQLite.Expression<Int64>("downloaded_bytes")
    private let speed = SQLite.Expression<Double>("speed")
    private let errorMessage = SQLite.Expression<String?>("error_message")
    private let createdAt = SQLite.Expression<Double>("created_at")
    private let updatedAt = SQLite.Expression<Double>("updated_at")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("superdm")

            if !fileManager.fileExists(atPath: appDir.path) {
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            }

            let dbPath = appDir.appendingPathComponent("downloads.sqlite3").path
            db = try Connection(dbPath)

            try db?.execute("PRAGMA journal_mode = WAL")
            try db?.execute("PRAGMA busy_timeout = 5000")

            try db?.run(downloads.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(url)
                t.column(destinationFolder)
                t.column(filename)
                t.column(status)
                t.column(totalBytes, defaultValue: 0)
                t.column(downloadedBytes, defaultValue: 0)
                t.column(speed, defaultValue: 0)
                t.column(errorMessage)
                t.column(createdAt)
                t.column(updatedAt)
            })
        } catch {
            print("Database setup error: \(error)")
        }
    }

    public func insert(_ download: Download) throws {
        let insert = downloads.insert(
            id <- download.id.uuidString,
            url <- download.url.absoluteString,
            destinationFolder <- download.destinationFolder.path,
            filename <- download.filename,
            status <- download.status.rawValue,
            totalBytes <- download.totalBytes,
            downloadedBytes <- download.downloadedBytes,
            speed <- download.speed,
            errorMessage <- download.errorMessage,
            createdAt <- download.createdAt.timeIntervalSince1970,
            updatedAt <- download.updatedAt.timeIntervalSince1970
        )
        
        print("DB Insert: \(download.filename) - status: \(download.status.rawValue)")
        try db?.run(insert)
    }

    public func update(_ download: Download) throws {
        let target = downloads.filter(id == download.id.uuidString)
        try db?.run(target.update(
            destinationFolder <- download.destinationFolder.path,
            filename <- download.filename,
            status <- download.status.rawValue,
            totalBytes <- download.totalBytes,
            downloadedBytes <- download.downloadedBytes,
            speed <- download.speed,
            errorMessage <- download.errorMessage,
            updatedAt <- Date().timeIntervalSince1970
        ))
    }

    public func delete(id downloadId: UUID) throws {
        let target = downloads.filter(id == downloadId.uuidString)
        try db?.run(target.delete())
    }

    public func fetchAll() throws -> [Download] {
        guard let db = db else { return [] }
        var results: [Download] = []

        for row in try db.prepare(downloads.order(createdAt.desc)) {
            guard let downloadUrl = URL(string: row[url]),
                  let downloadStatus = DownloadStatus(rawValue: row[status]) else {
                continue
            }

            let download = Download(
                id: UUID(uuidString: row[id]) ?? UUID(),
                url: downloadUrl,
                destinationFolder: URL(fileURLWithPath: row[destinationFolder]),
                filename: row[filename],
                status: downloadStatus,
                totalBytes: row[totalBytes],
                downloadedBytes: row[downloadedBytes],
                speed: row[speed],
                errorMessage: row[errorMessage],
                createdAt: Date(timeIntervalSince1970: row[createdAt]),
                updatedAt: Date(timeIntervalSince1970: row[updatedAt])
            )
            results.append(download)
        }

        return results
    }

    public func fetch(status filterStatus: DownloadStatus? = nil) throws -> [Download] {
        guard let db = db else { return [] }
        var results: [Download] = []

        var query = downloads.order(createdAt.desc)
        if let filterStatus = filterStatus {
            query = query.filter(status == filterStatus.rawValue)
        }

        for row in try db.prepare(query) {
            guard let downloadUrl = URL(string: row[url]),
                  let downloadStatus = DownloadStatus(rawValue: row[status]) else {
                continue
            }

            let download = Download(
                id: UUID(uuidString: row[id]) ?? UUID(),
                url: downloadUrl,
                destinationFolder: URL(fileURLWithPath: row[destinationFolder]),
                filename: row[filename],
                status: downloadStatus,
                totalBytes: row[totalBytes],
                downloadedBytes: row[downloadedBytes],
                speed: row[speed],
                errorMessage: row[errorMessage],
                createdAt: Date(timeIntervalSince1970: row[createdAt]),
                updatedAt: Date(timeIntervalSince1970: row[updatedAt])
            )
            results.append(download)
        }

        return results
    }

    public func get(id downloadId: UUID) throws -> Download? {
        guard let db = db else { return nil }
        let target = downloads.filter(id == downloadId.uuidString)

        guard let row = try db.pluck(target),
              let downloadUrl = URL(string: row[url]),
              let downloadStatus = DownloadStatus(rawValue: row[status]) else {
            return nil
        }

        return Download(
            id: UUID(uuidString: row[id]) ?? UUID(),
            url: downloadUrl,
            destinationFolder: URL(fileURLWithPath: row[destinationFolder]),
            filename: row[filename],
            status: downloadStatus,
            totalBytes: row[totalBytes],
            downloadedBytes: row[downloadedBytes],
            speed: row[speed],
            errorMessage: row[errorMessage],
            createdAt: Date(timeIntervalSince1970: row[createdAt]),
            updatedAt: Date(timeIntervalSince1970: row[updatedAt])
        )
    }
}
