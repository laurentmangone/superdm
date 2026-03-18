import SwiftUI
import App

struct DownloadRowView: View {
    let download: Download
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(download.filename)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(download.destinationFolder.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if download.status == .downloading || download.status == .paused {
                    ProgressView(value: download.progress)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text(download.formattedSpeed)
                        Spacer()
                        Text("\(download.formattedDownloaded) / \(download.formattedSize)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            statusBadge
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
    
    @ViewBuilder
    var statusIcon: some View {
        switch download.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.orange)
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.blue)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .cancelled:
            Image(systemName: "xmark.circle")
                .foregroundColor(.gray)
        }
    }
    
    @ViewBuilder
    var statusBadge: some View {
        switch download.status {
        case .pending:
            Text("Pending")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .clipShape(Capsule())
        case .downloading:
            Text(String(format: "%.0f%%", download.progress * 100))
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        case .paused:
            Text("Paused")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .clipShape(Capsule())
        case .completed:
            Text("Completed")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .clipShape(Capsule())
        case .failed:
            Text("Failed")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .clipShape(Capsule())
        case .cancelled:
            Text("Cancelled")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.gray)
                .clipShape(Capsule())
        }
    }
}
