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

    public override init() {
        super.init()
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        loadDownloads()
        resumeActiveDownloads()
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
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
    }

    public func filterDownloads(by status: DownloadStatus?) -> [Download] {
        guard let status = status else { return downloads }
        return downloads.filter { $0.status == status }
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let taskId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              var download = downloads.first(where: { $0.id == taskId }) else { return }

        let destination = download.destinationFolder.appendingPathComponent(download.filename)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
            download.status = .completed
            download.downloadedBytes = download.totalBytes
        } catch {
            download.status = .failed
            download.errorMessage = error.localizedDescription
        }

        downloadTasks.removeValue(forKey: taskId)
        speedTrackers.removeValue(forKey: taskId)
        activeDownloads.removeValue(forKey: taskId)
        resumeData.removeValue(forKey: taskId)

        updateDownload(download)
        startNextPending()
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let taskId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              var download = downloads.first(where: { $0.id == taskId }) else { return }

        download.downloadedBytes = totalBytesWritten
        download.totalBytes = totalBytesExpectedToWrite

        if let tracker = speedTrackers[taskId] {
            download.speed = tracker.calculateSpeed(bytes: totalBytesWritten)
        }

        if let index = downloads.firstIndex(where: { $0.id == taskId }) {
            downloads[index] = download
            objectWillChange.send()
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              let taskId = downloadTasks.first(where: { $0.value == downloadTask })?.key,
              var download = downloads.first(where: { $0.id == taskId }),
              let error = error else { return }

        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled {
            if resumeData[taskId] != nil {
                return
            }
        }

        download.status = .failed
        download.errorMessage = error.localizedDescription

        downloadTasks.removeValue(forKey: taskId)
        speedTrackers.removeValue(forKey: taskId)
        activeDownloads.removeValue(forKey: taskId)

        updateDownload(download)
        startNextPending()
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
