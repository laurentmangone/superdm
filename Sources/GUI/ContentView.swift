import SwiftUI
import App

struct ContentView: View {
    @ObservedObject var downloadManager: DownloadManager
    @State private var selectedDownloadIds: Set<UUID> = []
    @State private var selectedStatus: DownloadStatus?
    @State private var showingAddSheet = false
    @State private var showingSettings = false
    
    var filteredDownloads: [Download] {
        downloadManager.filterDownloads(by: selectedStatus)
    }
    
    private var selectedDownloads: [Download] {
        downloadManager.downloads.filter { selectedDownloadIds.contains($0.id) }
    }
    
    private var canStart: Bool {
        !selectedDownloadIds.isEmpty && selectedDownloads.contains { $0.status == .paused || $0.status == .cancelled }
    }
    
    private var canRetry: Bool {
        !selectedDownloadIds.isEmpty && selectedDownloads.contains { $0.status == .failed || $0.status == .cancelled }
    }
    
    private var canPause: Bool {
        !selectedDownloadIds.isEmpty && selectedDownloads.contains { $0.status == .downloading }
    }
    
    private var canCancel: Bool {
        !selectedDownloadIds.isEmpty && selectedDownloads.contains { $0.status != .completed }
    }
    
    private var canDelete: Bool {
        !selectedDownloadIds.isEmpty
    }
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedStatus: $selectedStatus, downloadManager: downloadManager)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        } detail: {
            VStack(spacing: 0) {
                DownloadListView(
                    downloads: filteredDownloads,
                    selectedDownloadIds: $selectedDownloadIds
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingSettings = true }) {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Preferences")
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
                .help("Add download")
                
                Button(action: startSelected) {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(!canStart)
                .help("Resume download")
                
                Button(action: retrySelected) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .disabled(!canRetry)
                .help("Retry failed download")
                
                Button(action: pauseSelected) {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(!canPause)
                .help("Pause download")
                
                Button(action: cancelSelected) {
                    Label("Cancel", systemImage: "xmark")
                }
                .disabled(!canCancel)
                .help("Cancel download")
                
                Button(action: removeSelected) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(!canDelete)
                .keyboardShortcut(.delete, modifiers: [])
                .help("Delete download")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddDownloadView()
        }
        .sheet(isPresented: $showingSettings) {
            PreferencesView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddDownload)) { _ in
            showingAddSheet = true
        }
    }
    
    private func startSelected() {
        for download in selectedDownloads where download.status == .paused || download.status == .cancelled {
            DownloadManager.shared.resumeDownload(download)
        }
    }
    
    private func pauseSelected() {
        for download in selectedDownloads where download.status == .downloading {
            DownloadManager.shared.pauseDownload(download)
        }
    }
    
    private func cancelSelected() {
        for download in selectedDownloads where download.status != .completed {
            DownloadManager.shared.cancelDownload(download)
        }
    }
    
    private func retrySelected() {
        for download in selectedDownloads where download.status == .failed || download.status == .cancelled {
            DownloadManager.shared.retryDownload(download)
        }
    }
    
    private func removeSelected() {
        for download in selectedDownloads {
            DownloadManager.shared.removeDownload(download)
        }
        selectedDownloadIds.removeAll()
    }
}

struct SidebarView: View {
    @Binding var selectedStatus: DownloadStatus?
    @ObservedObject var downloadManager: DownloadManager
    
    var body: some View {
        List {
            Section("Status") {
                SidebarRow(
                    title: "All",
                    icon: "arrow.down.circle",
                    count: downloadManager.downloads.count,
                    status: nil,
                    isSelected: selectedStatus == nil
                )
                .onTapGesture {
                    selectedStatus = nil
                }
                
                SidebarRow(
                    title: "Downloading",
                    icon: "arrow.down.circle.fill",
                    count: downloadManager.filterDownloads(by: .downloading).count,
                    status: .downloading,
                    isSelected: selectedStatus == .downloading
                )
                .onTapGesture {
                    selectedStatus = .downloading
                }
                
                SidebarRow(
                    title: "Paused",
                    icon: "pause.circle.fill",
                    count: downloadManager.filterDownloads(by: .paused).count,
                    status: .paused,
                    isSelected: selectedStatus == .paused
                )
                .onTapGesture {
                    selectedStatus = .paused
                }
                
                SidebarRow(
                    title: "Pending",
                    icon: "clock.fill",
                    count: downloadManager.filterDownloads(by: .pending).count,
                    status: .pending,
                    isSelected: selectedStatus == .pending
                )
                .onTapGesture {
                    selectedStatus = .pending
                }
                
                SidebarRow(
                    title: "Completed",
                    icon: "checkmark.circle.fill",
                    count: downloadManager.filterDownloads(by: .completed).count,
                    status: .completed,
                    isSelected: selectedStatus == .completed
                )
                .onTapGesture {
                    selectedStatus = .completed
                }
                
                SidebarRow(
                    title: "Failed",
                    icon: "xmark.circle.fill",
                    count: downloadManager.filterDownloads(by: .failed).count,
                    status: .failed,
                    isSelected: selectedStatus == .failed
                )
                .onTapGesture {
                    selectedStatus = .failed
                }
                
                SidebarRow(
                    title: "Cancelled",
                    icon: "xmark.circle",
                    count: downloadManager.filterDownloads(by: .cancelled).count,
                    status: .cancelled,
                    isSelected: selectedStatus == .cancelled
                )
                .onTapGesture {
                    selectedStatus = .cancelled
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Downloads")
    }
}

struct SidebarRow: View {
    let title: String
    let icon: String
    let count: Int
    let status: DownloadStatus?
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            Text(title)
            
            Spacer()
            
            Text("\(count)")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
    
    var iconColor: Color {
        switch status {
        case .downloading: return .blue
        case .paused: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        default: return .accentColor
        }
    }
}

struct DownloadListView: View {
    let downloads: [Download]
    @Binding var selectedDownloadIds: Set<UUID>
    
    var body: some View {
        if downloads.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle.dotted")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No Downloads")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Click the + button to add a download")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedDownloadIds) {
                ForEach(downloads, id: \.id) { download in
                    DownloadRowView(download: download, isSelected: selectedDownloadIds.contains(download.id))
                        .tag(download.id)
                }
            }
            .listStyle(.inset)
        }
    }
}
