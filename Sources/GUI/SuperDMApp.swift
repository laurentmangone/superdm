import SwiftUI
import App

@main
struct SuperDMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var downloadManager = DownloadManager.shared
    
    var body: some Scene {
        Window("SuperDM", id: "main") {
            ContentView(downloadManager: downloadManager)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Download...") {
                    NotificationCenter.default.post(name: .showAddDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        
        Settings {
            PreferencesView()
        }
    }
}

extension Notification.Name {
    static let showAddDownload = Notification.Name("showAddDownload")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(0.5, forKey: "NSInitialToolTipDelay")
        _ = DownloadManager.shared
        _ = Preferences.shared
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
