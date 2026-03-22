import Foundation
import ArgumentParser
import App

struct SuperDM: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "superdm",
        subcommands: [
            AddCommand.self,
            ListCommand.self,
            PauseCommand.self,
            ResumeCommand.self,
            CancelCommand.self,
            RemoveCommand.self,
            PreferencesCommand.self
        ]
    )
}

struct AddCommand: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Add a new download")

    @Argument(help: "URL to download")
    var urlString: String

    @Option(name: .short, help: "Destination folder")
    var to: String?

    func run() throws {
        guard let url = URL(string: urlString) else {
            throw ValidationError("Invalid URL")
        }

        let destination: URL
        if let to = to {
            destination = URL(fileURLWithPath: to)
        } else {
            destination = Preferences.shared.defaultDownloadFolder
        }

        let manager = DownloadManager.shared
        let download = try manager.addDownload(url: url, destinationFolder: destination)
        print("Added download: \(download.filename) (ID: \(download.id))")

        let startTime = Date()
        var lastProgress: Double = 0
        while download.status == .downloading || download.status == .pending {
            Thread.sleep(forTimeInterval: 0.5)
            if let updated = manager.downloads.first(where: { $0.id == download.id }) {
                if updated.progress != lastProgress {
                    print("Progress: \(String(format: "%.1f", updated.progress * 100))% - \(updated.formattedDownloaded)/\(updated.formattedSize)")
                    lastProgress = updated.progress
                }
                if updated.status == .completed {
                    print("Download completed!")
                    break
                }
                if updated.status == .failed {
                    print("Download failed: \(updated.errorMessage ?? "Unknown error")")
                    break
                }
            }
            if Date().timeIntervalSince(startTime) > 300 {
                print("Timeout after 5 minutes")
                break
            }
        }
    }
}

struct ListCommand: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "List downloads")

    @Option(name: .short, help: "Filter by status: all, downloading, paused, completed, failed")
    var status: String = "all"

    func run() throws {
        let manager = DownloadManager.shared
        let filterStatus: DownloadStatus?

        switch status.lowercased() {
        case "all": filterStatus = nil
        case "downloading": filterStatus = .downloading
        case "paused": filterStatus = .paused
        case "completed": filterStatus = .completed
        case "failed": filterStatus = .failed
        default:
            throw ValidationError("Invalid status. Use: all, downloading, paused, completed, failed")
        }

        let downloads = manager.filterDownloads(by: filterStatus)

        if downloads.isEmpty {
            print("No downloads found.")
            return
        }

        print("\nID                                  | Filename                    | Status       | Size       | Progress")
        print(String(repeating: "-", count: 100))

        for download in downloads {
            let id = String(download.id.uuidString.prefix(36))
            let filename = String(download.filename.prefix(26)).padding(toLength: 26, withPad: " ", startingAt: 0)
            let statusStr = String(download.status.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0))
            let size = "\(download.formattedDownloaded)/\(download.formattedSize)"
            let progress = String(format: "%.1f%%", download.progress * 100)

            print("\(id) | \(filename) | \(statusStr) | \(size) | \(progress)")
        }
        print()
    }
}

struct PauseCommand: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Pause a download")

    @Argument(help: "Download ID")
    var idString: String

    func run() throws {
        guard let id = UUID(uuidString: idString) else {
            throw ValidationError("Invalid UUID")
        }

        let manager = DownloadManager.shared
        guard let download = manager.downloads.first(where: { $0.id == id }) else {
            throw ValidationError("Download not found")
        }

        manager.pauseDownload(download)
        print("Paused: \(download.filename)")
    }
}

struct ResumeCommand: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Resume a download")

    @Argument(help: "Download ID")
    var idString: String

    func run() throws {
        guard let id = UUID(uuidString: idString) else {
            throw ValidationError("Invalid UUID")
        }

        let manager = DownloadManager.shared
        guard let download = manager.downloads.first(where: { $0.id == id }) else {
            throw ValidationError("Download not found")
        }

        manager.resumeDownload(download)
        print("Resumed: \(download.filename)")
    }
}

struct CancelCommand: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Cancel a download")

    @Argument(help: "Download ID")
    var idString: String

    func run() throws {
        guard let id = UUID(uuidString: idString) else {
            throw ValidationError("Invalid UUID")
        }

        let manager = DownloadManager.shared
        guard let download = manager.downloads.first(where: { $0.id == id }) else {
            throw ValidationError("Download not found")
        }

        manager.cancelDownload(download)
        print("Cancelled: \(download.filename)")
    }
}

struct RemoveCommand: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Remove a download")

    @Argument(help: "Download ID")
    var idString: String

    func run() throws {
        guard let id = UUID(uuidString: idString) else {
            throw ValidationError("Invalid UUID")
        }

        let manager = DownloadManager.shared
        guard let download = manager.downloads.first(where: { $0.id == id }) else {
            throw ValidationError("Download not found")
        }

        manager.removeDownload(download)
        print("Removed: \(download.filename)")
    }
}

struct PreferencesCommand: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Show or set preferences")

    @Option(name: .short, help: "Maximum parallel downloads")
    var maxParallel: Int?

    @Option(name: .short, help: "Default download folder")
    var folder: String?

    func run() throws {
        let prefs = Preferences.shared

        if let maxParallel = maxParallel {
            prefs.maxParallelDownloads = maxParallel
            print("Set max parallel downloads to: \(maxParallel)")
        }

        if let folder = folder {
            prefs.defaultDownloadFolder = URL(fileURLWithPath: folder)
            print("Set default download folder to: \(folder)")
        }

        if maxParallel == nil && folder == nil {
            print("Preferences:")
            print("  Max parallel downloads: \(prefs.maxParallelDownloads)")
            print("  Default download folder: \(prefs.defaultDownloadFolder.path)")
        }
    }
}

SuperDM.main()
