import SwiftUI
import DiveMap
import UmiDesignSystem

/// Settings view for managing offline map tile packs.
public struct OfflineMapsView: View {
    @State private var manager = OfflineTilePackManager.shared

    public init() {}

    public var body: some View {
        List {
            Section {
                HStack {
                    Label("Storage Used", systemImage: "internaldrive")
                    Spacer()
                    Text(String(format: "%.1f MB", manager.totalStorageUsedMB))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Downloaded", systemImage: "checkmark.circle")
                    Spacer()
                    Text("\(manager.downloadedCount) of \(manager.packs.count) regions")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Overview")
            }

            Section {
                ForEach(manager.packs) { pack in
                    OfflineRegionRow(pack: pack) {
                        handleAction(for: pack)
                    } onDelete: {
                        manager.delete(regionId: pack.id)
                    }
                }
            } header: {
                Text("Regions")
            } footer: {
                Text("Download map tiles for offline use in areas without internet. Tiles cover zoom levels 5–14.")
            }
        }
        .navigationTitle("Offline Maps")
        .onAppear {
            manager.refreshPacks()
        }
    }

    private func handleAction(for pack: OfflinePackInfo) {
        switch pack.status {
        case .notDownloaded, .error:
            // Use the primary vector style URL for downloads
            if let styleURL = Bundle.main.url(forResource: "umilog_underwater_vector", withExtension: "json") {
                manager.download(region: pack.region, styleURL: styleURL)
            }
        case .downloading:
            manager.pause(regionId: pack.id)
        case .paused:
            manager.resume(regionId: pack.id)
        case .complete:
            break
        }
    }
}

// MARK: - Region Row

private struct OfflineRegionRow: View {
    let pack: OfflinePackInfo
    let onAction: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.region.name)
                    .font(.body.weight(.medium))

                statusSubtitle
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            actionButton
        }
        .swipeActions(edge: .trailing) {
            if case .complete = pack.status {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private var statusSubtitle: some View {
        switch pack.status {
        case .notDownloaded:
            Text("Not downloaded")
        case .downloading(let progress):
            HStack(spacing: 6) {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("\(Int(progress * 100))%")
            }
        case .paused:
            Text("Paused")
        case .complete(let sizeMB, let date):
            Text("\(String(format: "%.1f MB", sizeMB)) \u{00B7} \(date.formatted(.relative(presentation: .named)))")
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch pack.status {
        case .notDownloaded, .error:
            Button {
                onAction()
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
            }
        case .downloading:
            Button {
                onAction()
            } label: {
                Image(systemName: "pause.circle")
                    .font(.title2)
            }
        case .paused:
            Button {
                onAction()
            } label: {
                Image(systemName: "play.circle")
                    .font(.title2)
            }
        case .complete:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        }
    }
}
