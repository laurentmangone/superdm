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
                Text("URL")
                    .font(.headline)
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
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid URL"
            showError = true
            return
        }
        
        do {
            let download = try DownloadManager.shared.addDownload(url: url, destinationFolder: destinationFolder)
            DownloadManager.shared.startDownload(download)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
