import SwiftUI
import UmiDB
import UmiCoreKit
import UniformTypeIdentifiers
import os

private let logger = Logger(subsystem: "com.umilog", category: "Settings")

public struct SettingsView: View {
    @State private var pendingDivesCount = 0
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    public init() {}

    public var body: some View {
        List {
            Section("Account") {
                NavigationLink("Privacy Settings") {
                    PrivacySettingsView()
                }
                NavigationLink("Sync") {
                    SyncSettingsView()
                }
            }

            Section("Data") {
                NavigationLink {
                    PendingSitesView()
                } label: {
                    HStack {
                        Label("Pending Locations", systemImage: "location.slash")
                        Spacer()
                        if pendingDivesCount > 0 {
                            Text("\(pendingDivesCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .cornerRadius(8)
                        }
                    }
                }

                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isExporting)

                Button {
                    isImporting = true
                } label: {
                    Label("Import Data", systemImage: "square.and.arrow.down")
                }
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
                NavigationLink("Attributions") {
                    AttributionsView()
                }
            }

            #if DEBUG
            Section("Developer") {
                Button("Clear All User Data") {
                    clearAllUserData()
                }
                .foregroundStyle(.red)

                Button("Clear Image Cache") {
                    clearImageCache()
                }

                Button("Reset First Launch Flag") {
                    resetFirstLaunch()
                }

                Button("Reset All Preferences") {
                    resetAllPreferences()
                }
            }
            #endif
        }
        .navigationTitle("Settings")
        .task {
            await loadPendingCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .diveLogUpdated)) { _ in
            Task {
                await loadPendingCount()
            }
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importData(result: result)
        }
        .alert("Data Operation", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func loadPendingCount() async {
        do {
            let diveRepository = DiveRepository(database: AppDatabase.shared)
            let pending = try diveRepository.fetchPendingGPS()
            await MainActor.run {
                pendingDivesCount = pending.count
            }
        } catch {
            logger.error("Error loading pending count: \(error.localizedDescription)")
        }
    }

    private func exportData() {
        isExporting = true
        Task {
            do {
                let diveRepository = DiveRepository(database: AppDatabase.shared)
                let dives = try diveRepository.fetchAll()

                let export = DiveExport(
                    version: 1,
                    exportedAt: Date(),
                    dives: dives
                )

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(export)

                let fileName = "umilog_export_\(ISO8601DateFormatter().string(from: Date())).json"
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                try data.write(to: tempURL)

                await MainActor.run {
                    exportURL = tempURL
                    showExportShare = true
                    isExporting = false
                    logger.info("Exported \(dives.count) dives to \(fileName)")
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Export failed: \(error.localizedDescription)"
                    showAlert = true
                    isExporting = false
                    logger.error("Export failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func importData(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw ImportError.invalidFormat("Cannot access the selected file")
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let export = try decoder.decode(DiveExport.self, from: data)

                    let diveRepository = DiveRepository(database: AppDatabase.shared)
                    var imported = 0
                    var skipped = 0

                    for dive in export.dives {
                        // Check if dive already exists
                        if try diveRepository.fetch(id: dive.id) != nil {
                            skipped += 1
                            continue
                        }
                        try diveRepository.create(dive)
                        imported += 1
                    }

                    await MainActor.run {
                        alertMessage = "Imported \(imported) dives. Skipped \(skipped) duplicates."
                        showAlert = true
                        logger.info("Imported \(imported) dives, skipped \(skipped) duplicates")

                        // Notify other views to refresh
                        NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
                    }
                } catch {
                    await MainActor.run {
                        alertMessage = "Import failed: \(error.localizedDescription)"
                        showAlert = true
                        logger.error("Import failed: \(error.localizedDescription)")
                    }
                }
            }
        case .failure(let error):
            alertMessage = "Could not access file: \(error.localizedDescription)"
            showAlert = true
            logger.error("File access failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Debug Actions (DEBUG builds only)
    #if DEBUG
    private func clearAllUserData() {
        Task {
            do {
                try AppDatabase.shared.deleteAllUserData()
                await MainActor.run {
                    alertMessage = "All user data cleared"
                    showAlert = true
                }
                NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
                logger.info("[DEBUG] Cleared all user data")
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to clear data: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    private func clearImageCache() {
        Task {
            await ImageCacheService.shared.clearCache()
        }
        alertMessage = "Image cache cleared"
        showAlert = true
        logger.info("[DEBUG] Cleared image cache")
    }

    private func resetFirstLaunch() {
        UserDefaults.standard.removeObject(forKey: "app.umilog.hasLaunchedBefore")
        alertMessage = "First launch flag reset. Restart app to see onboarding."
        showAlert = true
        logger.info("[DEBUG] Reset first launch flag")
    }

    private func resetAllPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedTab")
        defaults.removeObject(forKey: "app.umilog.hasLaunchedBefore")
        defaults.removeObject(forKey: "app.umilog.preferences.underwaterThemeEnabled")
        defaults.removeObject(forKey: "analytics_enabled")
        defaults.removeObject(forKey: "crash_reporting")
        defaults.removeObject(forKey: "icloud_sync_enabled")
        alertMessage = "All preferences reset. Restart app for full effect."
        showAlert = true
        logger.info("[DEBUG] Reset all preferences")
    }
    #endif
}

// MARK: - Export Model

private struct DiveExport: Codable {
    let version: Int
    let exportedAt: Date
    let dives: [DiveLog]
}

// ImportError is defined in CSVImporter.swift

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @AppStorage("analytics_enabled") private var analyticsEnabled = true
    @AppStorage("crash_reporting") private var crashReporting = true

    var body: some View {
        List {
            Section {
                Toggle("Analytics", isOn: $analyticsEnabled)
                Toggle("Crash Reporting", isOn: $crashReporting)
            } header: {
                Text("Data Collection")
            } footer: {
                Text("Analytics help us improve UmiLog. Crash reports help us fix bugs. Your dive data is never shared.")
            }

            Section {
                NavigationLink("Privacy Policy") {
                    Text("Privacy policy content would go here")
                        .padding()
                }
            }
        }
        .navigationTitle("Privacy")
    }
}

// MARK: - Sync Settings

struct SyncSettingsView: View {
    @AppStorage("icloud_sync_enabled") private var iCloudEnabled = false
    @State private var lastSyncDate: Date?

    var body: some View {
        List {
            Section {
                Toggle("iCloud Sync", isOn: $iCloudEnabled)
            } header: {
                Text("Sync")
            } footer: {
                Text("Sync your dive logs across all your devices. Requires iCloud to be enabled on this device.")
            }

            if iCloudEnabled {
                Section("Status") {
                    HStack {
                        Text("Last Sync")
                        Spacer()
                        if let date = lastSyncDate {
                            Text(date, style: .relative)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Sync Now") {
                        // TODO: Implement sync
                        lastSyncDate = Date()
                    }
                }
            }
        }
        .navigationTitle("Sync")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
