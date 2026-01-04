import SwiftUI
import UmiDB
import UmiDesignSystem

/// Multi-dive entry form for quickly logging past dives
public struct BackfillView: View {
    @StateObject private var viewModel = BackfillViewModel()
    @State private var showSitePicker = false
    @State private var editingEntryIndex: Int?
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Options section
                Section {
                    Toggle("Use same site for all dives", isOn: $viewModel.useSameSiteForAll)
                        .onChange(of: viewModel.useSameSiteForAll) { oldValue, newValue in
                            if newValue, let firstSiteId = viewModel.diveEntries.first?.siteId {
                                for i in 0..<viewModel.diveEntries.count {
                                    viewModel.diveEntries[i].siteId = firstSiteId
                                }
                            }
                        }
                } header: {
                    Text("Options")
                }

                // Dive entries
                Section {
                    ForEach(Array(viewModel.diveEntries.enumerated()), id: \.element.id) { index, entry in
                        DiveEntryRow(
                            entry: binding(for: index),
                            index: index,
                            onSelectSite: {
                                editingEntryIndex = index
                                showSitePicker = true
                            },
                            onDelete: viewModel.diveEntries.count > 1 ? {
                                viewModel.removeEntry(at: index)
                            } : nil
                        )
                    }

                    Button {
                        viewModel.addEntry()
                    } label: {
                        Label("Add Another Dive", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.oceanBlue)
                    }
                } header: {
                    Text("Dives (\(viewModel.totalDives))")
                } footer: {
                    Text("Add basic info for each dive. Dates auto-increment when adding new entries.")
                }
            }
            .navigationTitle("Backfill Dives")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await viewModel.saveAll()
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save \(viewModel.totalDives)")
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
            .sheet(isPresented: $showSitePicker) {
                SitePickerSheet(
                    selectedSiteId: editingEntryIndex.flatMap { viewModel.diveEntries[$0].siteId },
                    onSelect: { siteId in
                        if let index = editingEntryIndex {
                            viewModel.updateEntrySite(siteId, at: index)
                        }
                        showSitePicker = false
                    }
                )
            }
            .alert("Dives Saved", isPresented: $viewModel.showSavedAlert) {
                Button("Done") { dismiss() }
            } message: {
                Text("\(viewModel.savedCount) dive\(viewModel.savedCount == 1 ? "" : "s") saved to your log.")
            }
            .alert("Import Issue", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }

    private func binding(for index: Int) -> Binding<DiveEntry> {
        Binding(
            get: { viewModel.diveEntries[index] },
            set: { viewModel.diveEntries[index] = $0 }
        )
    }
}

// MARK: - Dive Entry Row

private struct DiveEntryRow: View {
    @Binding var entry: DiveEntry
    let index: Int
    let onSelectSite: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with dive number and delete
            HStack {
                Text("Dive \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(Color.oceanBlue)

                Spacer()

                if let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                }
            }

            // Date picker
            DatePicker("Date", selection: $entry.date, displayedComponents: [.date, .hourAndMinute])
                .font(.subheadline)

            // Site selection
            Button(action: onSelectSite) {
                HStack {
                    Text("Site")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(entry.siteId == nil ? "Select site..." : "Selected")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)

            // Core metrics in a grid
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Depth (m)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", value: $entry.maxDepth, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Time (min)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("0", value: $entry.bottomTime, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }

            // Optional: Temperature and visibility
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Temp (°C)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("26", value: $entry.temperature, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Vis (m)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("15", value: $entry.visibility, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
            }

            // Notes
            TextField("Notes (optional)", text: $entry.notes)
                .font(.subheadline)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Site Picker Sheet

private struct SitePickerSheet: View {
    let selectedSiteId: String?
    let onSelect: (String?) -> Void

    @State private var searchText = ""
    @State private var searchResults: [DiveSite] = []
    @Environment(\.dismiss) private var dismiss

    private let siteRepository = SiteRepository(database: AppDatabase.shared)

    var body: some View {
        NavigationStack {
            List {
                if searchText.isEmpty {
                    Section {
                        Button {
                            onSelect(nil)
                        } label: {
                            Label("No Site", systemImage: "mappin.slash")
                        }
                    }
                } else {
                    Section {
                        siteResultsList
                    }

                    if searchResults.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dive sites")
            .onChange(of: searchText) { oldValue, newValue in
                performSearch(query: newValue)
            }
            .navigationTitle("Select Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var siteResultsList: some View {
        SwiftUI.ForEach(Array(searchResults.enumerated()), id: \.offset) { (index: Int, site: DiveSite) in
            Button {
                onSelect(site.id)
            } label: {
                SiteSearchRow(name: site.name, region: site.region)
            }
        }
    }

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        do {
            searchResults = try siteRepository.search(query: query)
        } catch {
            searchResults = []
        }
    }
}

// MARK: - Site Search Row

private struct SiteSearchRow: View {
    let name: String
    let region: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .foregroundStyle(.primary)
            if !region.isEmpty {
                Text(region)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
