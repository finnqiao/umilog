import SwiftUI
import UmiDB
import os

private let logger = Logger(subsystem: "com.umilog", category: "DataExport")

/// Data export view with format selection and content options
public struct DataExportView: View {
    @State private var selectedFormat: ExportFormat = .json
    @State private var includeDives = true
    @State private var includeSites = true
    @State private var includeSightings = true
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showExportShare = false
    @State private var alertMessage: String?
    @State private var showAlert = false

    // Stats for display
    @State private var diveCount = 0
    @State private var siteCount = 0
    @State private var sightingCount = 0

    public init() {}

    public var body: some View {
        List {
            Section("Export Format") {
                Picker("Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedFormat.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Data to Export") {
                Toggle(isOn: $includeDives) {
                    HStack {
                        Label("Dive Logs", systemImage: "water.waves")
                        Spacer()
                        Text("\(diveCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $includeSites) {
                    HStack {
                        Label("Saved Sites", systemImage: "mappin.circle")
                        Spacer()
                        Text("\(siteCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $includeSightings) {
                    HStack {
                        Label("Wildlife Sightings", systemImage: "fish")
                        Spacer()
                        Text("\(sightingCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await exportData()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Exporting...")
                        } else {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        Spacer()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .background(canExport ? Color.accentColor : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!canExport || isExporting)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                Text("Your data will be exported as a \(selectedFormat.fileExtension.uppercased()) file that you can save to Files, send via AirDrop, or share via email.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Export Data")
        .task {
            await loadCounts()
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Export", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var canExport: Bool {
        includeDives || includeSites || includeSightings
    }

    private func loadCounts() async {
        do {
            let diveRepository = DiveRepository(database: AppDatabase.shared)
            let siteRepository = SiteRepository(database: AppDatabase.shared)
            let sightingsRepository = SightingsRepository(database: AppDatabase.shared)

            let dives = try diveRepository.fetchAll()
            let sites = try siteRepository.fetchWishlist()
            let sightings = try sightingsRepository.fetchAll()

            await MainActor.run {
                diveCount = dives.count
                siteCount = sites.count
                sightingCount = sightings.count
            }
        } catch {
            logger.error("Error loading counts: \(error.localizedDescription)")
        }
    }

    private func exportData() async {
        isExporting = true

        do {
            let exportData = try await gatherExportData()
            let url = try await generateExportFile(data: exportData, format: selectedFormat)

            await MainActor.run {
                exportURL = url
                showExportShare = true
                isExporting = false
                logger.info("Export completed: \(url.lastPathComponent)")
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

    private func gatherExportData() async throws -> ExportData {
        let diveRepository = DiveRepository(database: AppDatabase.shared)
        let siteRepository = SiteRepository(database: AppDatabase.shared)
        let sightingsRepository = SightingsRepository(database: AppDatabase.shared)

        let dives = includeDives ? try diveRepository.fetchAll() : []
        let sites = includeSites ? try siteRepository.fetchWishlist() : []
        let sightings = includeSightings ? try sightingsRepository.fetchAll() : []

        return ExportData(
            version: 2,
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            dives: dives,
            sites: sites,
            sightings: sightings
        )
    }

    private func generateExportFile(data: ExportData, format: ExportFormat) async throws -> URL {
        let dateFormatter = ISO8601DateFormatter()
        let timestamp = dateFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "T", with: "_")

        let fileName = "umilog_export_\(timestamp).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: tempURL)

        case .csv:
            let csvContent = generateCSV(from: data)
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        }

        return tempURL
    }

    private func generateCSV(from data: ExportData) -> String {
        var lines: [String] = []

        // Dives section
        if !data.dives.isEmpty {
            lines.append("# DIVE LOGS")
            lines.append("id,site_id,date,start_time,end_time,max_depth_m,average_depth_m,bottom_time_min,start_pressure_bar,end_pressure_bar,temperature_c,visibility_m,current,conditions,notes")

            for dive in data.dives {
                let row = [
                    escapeCSV(dive.id),
                    escapeCSV(dive.siteId ?? ""),
                    formatDate(dive.date),
                    formatDateTime(dive.startTime),
                    formatDateTime(dive.endTime),
                    String(format: "%.1f", dive.maxDepth),
                    String(format: "%.1f", dive.averageDepth ?? 0),
                    String(dive.bottomTime),
                    String(dive.startPressure),
                    String(dive.endPressure),
                    String(format: "%.1f", dive.temperature),
                    String(format: "%.1f", dive.visibility),
                    dive.current.rawValue,
                    dive.conditions.rawValue,
                    escapeCSV(dive.notes)
                ].joined(separator: ",")
                lines.append(row)
            }
            lines.append("")
        }

        // Sites section
        if !data.sites.isEmpty {
            lines.append("# SAVED SITES")
            lines.append("id,name,location,latitude,longitude,region,max_depth_m,average_visibility_m,difficulty,type,description")

            for site in data.sites {
                let row = [
                    escapeCSV(site.id),
                    escapeCSV(site.name),
                    escapeCSV(site.location),
                    String(format: "%.6f", site.latitude),
                    String(format: "%.6f", site.longitude),
                    escapeCSV(site.region),
                    String(format: "%.1f", site.maxDepth),
                    String(format: "%.1f", site.averageVisibility),
                    site.difficulty.rawValue,
                    site.type.rawValue,
                    escapeCSV(site.description ?? "")
                ].joined(separator: ",")
                lines.append(row)
            }
            lines.append("")
        }

        // Sightings section
        if !data.sightings.isEmpty {
            lines.append("# WILDLIFE SIGHTINGS")
            lines.append("id,dive_id,species_id,count,notes,spotted_at")

            for sighting in data.sightings {
                let row = [
                    escapeCSV(sighting.id),
                    escapeCSV(sighting.diveId),
                    escapeCSV(sighting.speciesId),
                    String(sighting.count),
                    escapeCSV(sighting.notes ?? ""),
                    formatDateTime(sighting.createdAt)
                ].joined(separator: ",")
                lines.append(row)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDateTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case json
    case csv

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        }
    }

    var fileExtension: String {
        rawValue
    }

    var description: String {
        switch self {
        case .json:
            return "Full data export with complete structure. Best for backup and restore."
        case .csv:
            return "Spreadsheet-compatible format. Best for analysis in Excel or Google Sheets."
        }
    }
}

// MARK: - Export Data Model

struct ExportData: Codable {
    let version: Int
    let exportedAt: Date
    let appVersion: String
    let dives: [DiveLog]
    let sites: [DiveSite]
    let sightings: [WildlifeSighting]
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        DataExportView()
    }
}
