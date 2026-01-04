import SwiftUI

/// View for managing Apple Watch connection
public struct WatchConnectView: View {
    @StateObject private var manager = WatchConnectivityManager.shared
    @StateObject private var syncService = WatchSyncService()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Connection status
                Section {
                    HStack {
                        Image(systemName: statusIcon)
                            .font(.title)
                            .foregroundStyle(statusColor)
                            .frame(width: 50, height: 50)
                            .background(statusColor.opacity(0.1))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusTitle)
                                .font(.headline)
                            Text(statusSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Connection Status")
                }

                // Details
                if manager.isPaired {
                    Section {
                        LabeledContent("Watch App Installed") {
                            Text(manager.isWatchAppInstalled ? "Yes" : "No")
                        }

                        LabeledContent("Reachable") {
                            Text(manager.isReachable ? "Yes" : "No")
                        }

                        if let lastSync = manager.lastSyncDate {
                            LabeledContent("Last Sync") {
                                Text(lastSync, style: .relative)
                            }
                        }
                    } header: {
                        Text("Details")
                    }

                    // Sync action
                    Section {
                        Button {
                            Task {
                                await syncService.syncDivesToWatch()
                            }
                        } label: {
                            HStack {
                                Label("Sync Dives to Watch", systemImage: "arrow.triangle.2.circlepath")

                                Spacer()

                                if syncService.isSyncing {
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(!manager.isReachable || syncService.isSyncing)
                    } header: {
                        Text("Actions")
                    } footer: {
                        Text("Syncs your recent dives to your Apple Watch for quick reference.")
                    }
                }

                // Help section
                if !manager.isPaired {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HelpRow(number: 1, text: "Open the Watch app on your iPhone")
                            HelpRow(number: 2, text: "Pair your Apple Watch if not already paired")
                            HelpRow(number: 3, text: "Install UmiLog on your Watch")
                            HelpRow(number: 4, text: "Return here and tap \"Retry Connection\"")
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("How to Connect")
                    }

                    Section {
                        Button {
                            manager.activate()
                        } label: {
                            Label("Retry Connection", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationTitle("Apple Watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Status Display

    private var statusIcon: String {
        switch manager.connectionState {
        case .activated:
            return manager.isReachable ? "applewatch.radiowaves.left.and.right" : "applewatch"
        case .notPaired:
            return "applewatch.slash"
        case .notSupported:
            return "exclamationmark.triangle"
        default:
            return "applewatch"
        }
    }

    private var statusColor: Color {
        switch manager.connectionState {
        case .activated:
            return manager.isReachable ? .green : .orange
        case .notPaired, .inactive, .unknown:
            return .secondary
        case .notSupported:
            return .red
        }
    }

    private var statusTitle: String {
        switch manager.connectionState {
        case .activated:
            return manager.isReachable ? "Connected" : "Paired"
        case .notPaired:
            return "Not Paired"
        case .notSupported:
            return "Not Supported"
        case .inactive:
            return "Inactive"
        case .unknown:
            return "Checking..."
        }
    }

    private var statusSubtitle: String {
        switch manager.connectionState {
        case .activated:
            return manager.isReachable
                ? "Your Apple Watch is connected and ready"
                : "Watch paired but not currently reachable"
        case .notPaired:
            return "Pair your Apple Watch to sync dives"
        case .notSupported:
            return "This device doesn't support WatchConnectivity"
        case .inactive:
            return "Connection is inactive"
        case .unknown:
            return "Checking connection status..."
        }
    }
}

// MARK: - Help Row

private struct HelpRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}
