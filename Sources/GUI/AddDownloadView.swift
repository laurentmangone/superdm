import SwiftUI
import App

struct AddDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString: String = ""
    @State private var destinationFolder: URL = Preferences.shared.defaultDownloadFolder
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isSelectingFolder = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Download")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("URL")
                        .font(.headline)
                    Spacer()
                    Button("Import from File...") {
                        importFromFile()
                    }
                    .buttonStyle(.link)
                }
                TextField("Enter URL or drag file here", text: $urlString)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Destination Folder")
                    .font(.headline)
                HStack {
                    Text(destinationFolder.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    Button("Choose...") {
                        selectFolder()
                    }
                }
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Download") {
                    addDownload()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(urlString.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500)
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = destinationFolder
        
        if panel.runModal() == .OK, let url = panel.url {
            destinationFolder = url
        }
    }
    
    private func addDownload() {
        let urls = urlString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var addedCount = 0
        var errors: [String] = []
        
        for urlStr in urls {
            guard let url = URL(string: urlStr) else {
                errors.append("Invalid URL: \(urlStr)")
                continue
            }
            
            do {
                let download = try DownloadManager.shared.addDownload(url: url, destinationFolder: destinationFolder)
                DownloadManager.shared.startDownload(download)
                addedCount += 1
            } catch {
                errors.append("\(urlStr): \(error.localizedDescription)")
            }
        }
        
        if addedCount > 0 {
            dismiss()
        } else if !errors.isEmpty {
            errorMessage = errors.joined(separator: "\n")
            showError = true
        }
    }
    
    private func importFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                urlString = content
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
                showError = true
            }
        }
    }
}
