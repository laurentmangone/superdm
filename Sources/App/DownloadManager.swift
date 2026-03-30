import Foundation
import Combine

public class DownloadManager: NSObject, ObservableObject {
    public static let shared = DownloadManager()

    @Published public var downloads: [Download] = []
    @Published public var activeDownloads: [UUID: URLSessionDownloadTask] = [:]

    private var urlSession: URLSession!
    private let preferences = Preferences.shared
    private var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var speedTrackers: [UUID: SpeedTracker] = [:]
    private var resumeData: [UUID: Data] = [:]
    private var resumeBaseBytes: [UUID: Int64] = [:]
    private var lastDbUpdate: [UUID: Date] = [:]
    private let dbUpdateInterval: TimeInterval = 5.0
    private static let maxRetryCount = 3
    private static var keepAlive: DownloadManager?
    
    private let tempDirectory: URL = {
        return FileManager.default.temporaryDirectory
    }()
    
    private lazy var sessionCacheDirectory: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("com.apple.nsurlsessiond/Downloads/superdm")
    }()

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        config.httpMaximumConnectionsPerHost = 4
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        loadDownloads()
        resumeActiveDownloads()
        cleanupTempFiles()
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.reloadDownloadsFromDatabase()
            }
        }
        
        if DownloadManager.keepAlive == nil {
            DownloadManager.keepAlive = self
        }
    }
    
    public static func keepAliveForCLI() {
        let _ = shared
    }
    
    private func reloadDownloadsFromDatabase() {
        do {
            let dbDownloads = try Database.shared.fetchAll()
            var updated = false
            
            for dbDownload in dbDownloads {
                if let index = downloads.firstIndex(where: { $0.id == dbDownload.id }) {
                    let currentStatus = downloads[index].status
                    if currentStatus == .downloading || currentStatus == .pending {
                        if downloads[index].status == .downloading && downloads[index].downloadedBytes < dbDownload.downloadedBytes {
                            downloads[index].downloadedBytes = dbDownload.downloadedBytes
                            downloads[index].totalBytes = dbDownload.totalBytes
                            updated = true
                        }
                        continue
                    }
                    if downloads[index].status != dbDownload.status || 
                       downloads[index].downloadedBytes != dbDownload.downloadedBytes ||
                       downloads[index].totalBytes != dbDownload.totalBytes {
                        downloads[index] = dbDownload
                        updated = true
                    }
                } else {
                    print("GUI: New download from DB: \(dbDownload.filename) - status: \(dbDownload.status)")
                    var newDownload = dbDownload
                    newDownload.status = .pending
                    downloads.insert(newDownload, at: 0)
                    updated = true
                }
            }
            
            if updated {
                objectWillChange.send()
                startNextPending()
            }
        } catch {
            print("Failed to reload downloads: \(error)")
        }
    }
    
    private func cleanupTempFiles() {
        cleanupDirectory(tempDirectory)
        cleanupDirectory(sessionCacheDirectory)
    }
    
    private func cleanupDirectory(_ directory: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in contents where file.lastPathComponent.hasPrefix("CFNetworkDownload_") {
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
        }
    }

    private func loadDownloads() {
        do {
            downloads = try Database.shared.fetchAll()
        } catch {
            print("Failed to load downloads: \(error)")
        }
    }

    private func resumeActiveDownloads() {
        let active = downloads.filter { $0.status == .downloading || $0.status == .pending }
        for download in active {
            var updated = download
            updated.status = .pending
            updateDownload(updated)
        }
        startNextPending()
    }

    public func addDownload(url: URL, destinationFolder: URL? = nil) throws -> Download {
        let destFolder = destinationFolder ?? preferences.defaultDownloadFolder
        let filename = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        let download = Download(url: url, destinationFolder: destFolder, filename: filename)
        try Database.shared.insert(download)
        downloads.insert(download, at: 0)
        return download
    }

    public func startDownload(_ download: Download) {
        let currentActive = activeDownloads.count
        print("startDownload: \(download.filename) - active: \(currentActive), max: \(preferences.maxParallelDownloads)")
        
        guard activeDownloads.count < preferences.maxParallelDownloads else {
            var updated = download
            updated.status = .pending
            updateDownload(updated)
            return
        }

        var updated = download
        updated.status = .downloading
        updateDownload(updated)

        let task: URLSessionDownloadTask
        if let data = resumeData[download.id] {
            task = urlSession.downloadTask(withResumeData: data)
            resumeBaseBytes[download.id] = download.downloadedBytes
            resumeData.removeValue(forKey: download.id)
        } else {
            task = urlSession.downloadTask(with: download.url)
        }

        downloadTasks[download.id] = task
        speedTrackers[download.id] = SpeedTracker()
        task.resume()
        activeDownloads[download.id] = task
    }

    public func pauseDownload(_ download: Download) {
        guard let task = downloadTasks[download.id] else { return }
        
        task.cancel(byProducingResumeData: { [weak self] data in
            if let data = data {
                self?.resumeData[download.id] = data
            }
            DispatchQueue.main.async {
                var updated = download
                updated.status = .paused
                self?.updateDownload(updated)
                
                self?.downloadTasks.removeValue(forKey: download.id)
                self?.activeDownloads.removeValue(forKey: download.id)
                self?.startNextPending()
            }
        })
    }

    public func resumeDownload(_ download: Download) {
        var updated = download
        updated.status = .pending
        updated.errorMessage = nil
        updateDownload(updated)
        startDownload(updated)
    }
    
    public func retryDownload(_ download: Download) {
        var updated = download
        updated.status = .pending
        updated.downloadedBytes = 0
        updated.errorMessage = nil
        updateDownload(updated)
        startDownload(updated)
    }

    public func cancelDownload(_ download: Download) {
        downloadTasks[download.id]?.cancel()
        
        var updated = download
        updated.status = .cancelled
        updateDownload(updated)
        
        downloadTasks.removeValue(forKey: download.id)
        activeDownloads.removeValue(forKey: download.id)
        speedTrackers.removeValue(forKey: download.id)
        resumeData.removeValue(forKey: download.id)
        resumeBaseBytes.removeValue(forKey: download.id)
    }

    public func removeDownload(_ download: Download) {
        cancelDownload(download)
        
        do {
            try Database.shared.delete(id: download.id)
            downloads.removeAll { $0.id == download.id }
        } catch {
            print("Failed to remove download: \(error)")
        }
    }

    private func updateDownload(_ download: Download) {
        do {
            try Database.shared.update(download)
            if let index = downloads.firstIndex(where: { $0.id == download.id }) {
                downloads[index] = download
            }
            objectWillChange.send()
        } catch {
            print("Failed to update download: \(error)")
        }
    }

    private func startNextPending() {
        let pending = downloads.filter { $0.status == .pending }
        for download in pending {
            if activeDownloads.count < preferences.maxParallelDownloads {
                startDownload(download)
            }
        }
        
        let failedToRetry = downloads.filter { $0.status == .failed && $0.retryCount < Self.maxRetryCount }
        for download in failedToRetry {
            if activeDownloads.count < preferences.maxParallelDownloads {
                var retry = download
                retry.status = .pending
                retry.retryCount += 1
                retry.downloadedBytes = 0
                retry.errorMessage = nil
                updateDownload(retry)
                startDownload(retry)
            }
        }
    }

    public func filterDownloads(by status: DownloadStatus?) -> [Download] {
        guard let status = status else { return downloads }
        return downloads.filter { $0.status == status }
    }
    
    public func changeDestination(for downloadIds: [UUID], to newDestination: URL) {
        for id in downloadIds {
            guard let index = downloads.firstIndex(where: { $0.id == id }) else { continue }
            var download = downloads[index]
            let oldDestination = download.destinationFolder.appendingPathComponent(download.filename)
            
            download.destinationFolder = newDestination
            downloads[index] = download
            
            if download.status == .completed && FileManager.default.fileExists(atPath: oldDestination.path) {
                let newPath = newDestination.appendingPathComponent(download.filename)
                do {
                    try FileManager.default.createDirectory(at: newDestination, withIntermediateDirectories: true)
                    if FileManager.default.fileExists(atPath: newPath.path) {
                        try FileManager.default.removeItem(at: newPath)
                    }
                    try FileManager.default.moveItem(at: oldDestination, to: newPath)
                } catch {
                    print("Failed to move file to new destination: \(error)")
                }
            }
            
            updateDownload(download)
        }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              var download = downloads.first(where: { $0.id == taskId }) else { return }

        let destination = download.destinationFolder.appendingPathComponent(download.filename)
        var errorMsg: String? = nil
        
        do {
            try FileManager.default.createDirectory(at: download.destinationFolder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            download.status = .completed
            download.downloadedBytes = download.totalBytes
        } catch {
            download.status = .failed
            errorMsg = error.localizedDescription
            download.errorMessage = errorMsg
        }

        let finalDownload = download
        let finalTaskId = taskId

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloadTasks.removeValue(forKey: finalTaskId)
            self.speedTrackers.removeValue(forKey: finalTaskId)
            self.activeDownloads.removeValue(forKey: finalTaskId)
            self.resumeData.removeValue(forKey: finalTaskId)
            self.resumeBaseBytes.removeValue(forKey: finalTaskId)
            self.updateDownload(finalDownload)
            self.startNextPending()
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let taskId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              var download = downloads.first(where: { $0.id == taskId }) else { return }

        if let baseBytes = resumeBaseBytes[taskId], baseBytes > 0 {
            download.downloadedBytes = baseBytes + totalBytesWritten
            if totalBytesExpectedToWrite > 0 {
                download.totalBytes = baseBytes + totalBytesExpectedToWrite
            }
        } else {
            download.downloadedBytes = totalBytesWritten
            download.totalBytes = totalBytesExpectedToWrite
        }

        if let tracker = speedTrackers[taskId] {
            download.speed = tracker.calculateSpeed(bytes: totalBytesWritten)
        }

        let downloadId = download.id
        let updatedDownload = download
        let shouldUpdateDb: Bool

        let now = Date()
        if let lastUpdate = lastDbUpdate[downloadId], now.timeIntervalSince(lastUpdate) < dbUpdateInterval {
            shouldUpdateDb = false
        } else {
            lastDbUpdate[downloadId] = now
            shouldUpdateDb = true
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let index = self.downloads.firstIndex(where: { $0.id == downloadId }) {
                self.downloads[index] = updatedDownload
            }
            self.objectWillChange.send()
            if shouldUpdateDb {
                self.updateDownload(updatedDownload)
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let taskId = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }

        guard var download = downloads.first(where: { $0.id == taskId }) else { return }

        if download.status == .completed {
            DispatchQueue.main.async { [weak self] in
                self?.downloadTasks.removeValue(forKey: taskId)
            }
            return
        }

        guard let error = error else { return }

        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled && resumeData[taskId] != nil {
            return
        }

        download.status = .failed
        download.errorMessage = error.localizedDescription

        let finalDownload = download
        let finalTaskId = taskId

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.downloadTasks.removeValue(forKey: finalTaskId)
            self.speedTrackers.removeValue(forKey: finalTaskId)
            self.activeDownloads.removeValue(forKey: finalTaskId)
            self.resumeData.removeValue(forKey: finalTaskId)
            self.resumeBaseBytes.removeValue(forKey: finalTaskId)
            self.updateDownload(finalDownload)
            self.startNextPending()
        }
    }
}

private class SpeedTracker {
    private var samples: [(time: Date, bytes: Int64)] = []
    private let maxSamples = 10

    func calculateSpeed(bytes: Int64) -> Double {
        let now = Date()
        samples.append((now, bytes))

        if samples.count > maxSamples {
            samples.removeFirst()
        }

        guard samples.count >= 2 else { return 0 }

        let oldest = samples.first!
        let newest = samples.last!

        let timeDiff = newest.time.timeIntervalSince(oldest.time)
        let bytesDiff = newest.bytes - oldest.bytes

        guard timeDiff > 0 else { return 0 }
        return Double(bytesDiff) / timeDiff
    }
}
