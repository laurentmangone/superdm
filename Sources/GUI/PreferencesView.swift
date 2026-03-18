import SwiftUI
import App

struct PreferencesView: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var maxParallel: Int = Preferences.shared.maxParallelDownloads
    @State private var downloadFolder: URL = Preferences.shared.defaultDownloadFolder
    
    var body: some View {
        Form {
            Section {
                Stepper(
                    "Max Parallel Downloads: \(maxParallel)",
                    value: $maxParallel,
                    in: 1...10
                )
                
                Text("Number of simultaneous downloads")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Default Download Folder") {
                HStack {
                    Text(downloadFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button("Choose...") {
                        selectFolder()
                    }
                }
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        resetDefaults()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 450, height: 250)
        .onChange(of: maxParallel) { newValue in
            preferences.maxParallelDownloads = newValue
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = downloadFolder
        
        if panel.runModal() == .OK, let url = panel.url {
            downloadFolder = url
            preferences.defaultDownloadFolder = url
        }
    }
    
    private func resetDefaults() {
        preferences.reset()
        maxParallel = preferences.maxParallelDownloads
        downloadFolder = preferences.defaultDownloadFolder
    }
}
