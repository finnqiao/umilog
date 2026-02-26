import SwiftUI
import UmiDB
import UmiDesignSystem

/// Preview and confirm dive import before saving
public struct ImportPreviewView: View {
    let result: CSVImporter.ImportResult
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss

    public init(
        result: CSVImporter.ImportResult,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.result = result
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    SummaryRow(icon: "checkmark.circle.fill", color: .green, label: "Ready to import", value: "\(result.dives.count) dives")

                    if result.skippedRows > 0 {
                        SummaryRow(icon: "exclamationmark.triangle.fill", color: .orange, label: "Skipped", value: "\(result.skippedRows) rows")
                    }
                } header: {
                    Text("Import Summary")
                }

                // Preview of dives
                if !result.dives.isEmpty {
                    Section {
                        ForEach(result.dives.prefix(10)) { dive in
                            DivePreviewRow(dive: dive)
                        }

                        if result.dives.count > 10 {
                            Text("...and \(result.dives.count - 10) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Preview")
                    }
                }

                // Warnings
                if !result.warnings.isEmpty {
                    Section {
                        ForEach(result.warnings.prefix(5), id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if result.warnings.count > 5 {
                            Text("...and \(result.warnings.count - 5) more warnings")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Warnings")
                    }
                }
            }
            .navigationTitle("Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        performImport()
                    } label: {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Import \(result.dives.count)")
                        }
                    }
                    .disabled(result.dives.isEmpty || isImporting)
                }
            }
        }
    }

    private func performImport() {
        isImporting = true

        Task {
            // Small delay for UI feedback
            try? await Task.sleep(nanoseconds: 300_000_000)

            await MainActor.run {
                onConfirm()
                dismiss()
            }
        }
    }
}

// MARK: - Components

private struct SummaryRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

private struct DivePreviewRow: View {
    let dive: DiveLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formatDate(dive.date))
                .font(.headline)

            HStack(spacing: 16) {
                Label(String(format: "%.1fm", dive.maxDepth), systemImage: "arrow.down")
                Label("\(dive.bottomTime)min", systemImage: "clock")
                Label(String(format: "%.0f°C", dive.temperature), systemImage: "thermometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if dive.siteId == nil {
                Label("No site matched", systemImage: "mappin.slash")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Import Flow Coordinator

/// Manages the file selection and import flow
public struct ImportFlowView: View {
    @State private var isShowingFilePicker = false
    @State private var importResult: CSVImporter.ImportResult?
    @State private var errorMessage: String?
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss

    private let database = AppDatabase.shared
    private let diveRepository: DiveRepository
    private let siteRepository: SiteRepository

    public init() {
        self.diveRepository = DiveRepository(database: AppDatabase.shared)
        self.siteRepository = SiteRepository(database: AppDatabase.shared)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Instructions
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.oceanBlue)

                    Text("Import Dive Logs")
                        .font(.title2.bold())

                    Text("Import dives from CSV, UDDF, or Subsurface files exported from other dive log applications or dive computers.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Supported formats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Supported Formats")
                        .font(.headline)

                    FormatRow(icon: "doc.text", title: "CSV", description: "Comma-separated values with headers")
                    FormatRow(icon: "doc.richtext", title: "UDDF", description: "Universal Dive Data Format (XML)")
                    FormatRow(icon: "doc.richtext", title: "Subsurface", description: "Subsurface dive log (.ssrf, .xml)")
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Select file button
                Button {
                    isShowingFilePicker = true
                } label: {
                    Label("Select File", systemImage: "folder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .xml, .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(item: $importResult) { result in
                ImportPreviewView(
                    result: result,
                    onConfirm: {
                        performImport(result)
                    },
                    onCancel: {
                        importResult = nil
                    }
                )
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        throw ImportError.invalidFormat("Cannot access file")
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent.lowercased()

                    let parseResult: CSVImporter.ImportResult
                    if fileName.hasSuffix(".ssrf") {
                        let importer = SubsurfaceImporter(siteRepository: siteRepository)
                        parseResult = try importer.parse(data: data)
                    } else if fileName.hasSuffix(".uddf") {
                        let importer = UDDFImporter(siteRepository: siteRepository)
                        parseResult = try importer.parse(data: data)
                    } else if fileName.hasSuffix(".xml") {
                        // Detect format: check for Subsurface or UDDF root element
                        let xmlString = String(data: data.prefix(500), encoding: .utf8) ?? ""
                        if xmlString.contains("<divelog") || xmlString.contains("subsurface") {
                            let importer = SubsurfaceImporter(siteRepository: siteRepository)
                            parseResult = try importer.parse(data: data)
                        } else {
                            let importer = UDDFImporter(siteRepository: siteRepository)
                            parseResult = try importer.parse(data: data)
                        }
                    } else {
                        parseResult = try CSVImporter.parse(data: data, siteRepository: siteRepository)
                    }

                    await MainActor.run {
                        importResult = parseResult
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func performImport(_ result: CSVImporter.ImportResult) {
        Task {
            var imported = 0
            var skipped = 0

            for dive in result.dives {
                do {
                    // Check for duplicates (same date and max depth)
                    if try !diveRepository.hasDuplicate(date: dive.date, maxDepth: dive.maxDepth) {
                        try diveRepository.create(dive)
                        imported += 1
                    } else {
                        skipped += 1
                    }
                } catch {
                    // Continue with next dive on error
                    skipped += 1
                }
            }

            await MainActor.run {
                NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
                dismiss()
            }
        }
    }
}

private struct FormatRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.oceanBlue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Identifiable for sheet

extension CSVImporter.ImportResult: Identifiable {
    public var id: Int { dives.count }
}
