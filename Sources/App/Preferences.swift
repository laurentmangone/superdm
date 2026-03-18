import Foundation

public class Preferences: ObservableObject {
    public static let shared = Preferences()

    private let maxParallelDownloadsKey = "maxParallelDownloads"
    private let defaultDownloadFolderKey = "defaultDownloadFolder"

    @Published public var maxParallelDownloads: Int {
        didSet {
            UserDefaults.standard.set(maxParallelDownloads, forKey: maxParallelDownloadsKey)
        }
    }

    @Published public var defaultDownloadFolder: URL {
        didSet {
            UserDefaults.standard.set(defaultDownloadFolder.path, forKey: defaultDownloadFolderKey)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let savedMaxParallel = defaults.integer(forKey: maxParallelDownloadsKey)
        maxParallelDownloads = savedMaxParallel == 0 ? 3 : savedMaxParallel

        if let savedPath = defaults.string(forKey: defaultDownloadFolderKey) {
            defaultDownloadFolder = URL(fileURLWithPath: savedPath)
        } else {
            defaultDownloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
    }

    public func reset() {
        maxParallelDownloads = 3
        defaultDownloadFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
}
