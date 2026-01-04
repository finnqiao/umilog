import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit
import os

/// View for managing dives logged with GPS coordinates that haven't been linked to a site yet.
public struct PendingSitesView: View {
    @StateObject private var viewModel = PendingSitesViewModel()
    @State private var selectedDive: DiveLog?
    @State private var showingCreateSite = false
    @State private var showingLinkSite = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.pendingDives.isEmpty {
                EmptyStateView()
            } else {
                List {
                    Section {
                        ForEach(viewModel.pendingDives) { dive in
                            PendingDiveRow(dive: dive) {
                                selectedDive = dive
                                showingCreateSite = true
                            } onLink: {
                                selectedDive = dive
                                showingLinkSite = true
                            }
                        }
                    } header: {
                        Text("\(viewModel.pendingDives.count) dive\(viewModel.pendingDives.count == 1 ? "" : "s") with pending locations")
                    } footer: {
                        Text("These dives were logged with GPS coordinates but haven't been linked to a named dive site yet.")
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Pending Sites")
        .task {
            await viewModel.loadPendingDives()
        }
        .sheet(isPresented: $showingCreateSite) {
            if let dive = selectedDive,
               let lat = dive.pendingLatitude,
               let lon = dive.pendingLongitude {
                CreateSiteFromGPSSheet(
                    diveId: dive.id,
                    latitude: lat,
                    longitude: lon,
                    onComplete: {
                        Task {
                            await viewModel.loadPendingDives()
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingLinkSite) {
            if let dive = selectedDive {
                LinkToExistingSiteSheet(dive: dive) {
                    Task {
                        await viewModel.loadPendingDives()
                    }
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class PendingSitesViewModel: ObservableObject {
    @Published var pendingDives: [DiveLog] = []
    @Published var isLoading = false

    private let diveRepository = DiveRepository(database: AppDatabase.shared)

    func loadPendingDives() async {
        isLoading = true
        defer { isLoading = false }

        do {
            pendingDives = try diveRepository.fetchPendingGPS()
        } catch {
            Log.diveLog.error("Error loading pending dives: \(error.localizedDescription)")
            pendingDives = []
        }
    }
}

// MARK: - Components

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("All Caught Up!")
                .font(.headline)

            Text("All your dives have been linked to named dive sites.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PendingDiveRow: View {
    let dive: DiveLog
    let onCreate: () -> Void
    let onLink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Location and date
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundStyle(Color.lagoon)

                        Text(formatCoordinates())
                            .font(.subheadline)
                            .fontDesign(.monospaced)
                    }

                    Text(dive.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Dive stats
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(dive.maxDepth))m")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(dive.bottomTime) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: onCreate) {
                    Label("Create Site", systemImage: "plus.circle")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: onLink) {
                    Label("Link Existing", systemImage: "link")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCoordinates() -> String {
        guard let lat = dive.pendingLatitude, let lon = dive.pendingLongitude else {
            return "Unknown"
        }
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        return String(format: "%.4f°%@ %.4f°%@", abs(lat), latDir, abs(lon), lonDir)
    }
}

// MARK: - Create Site Sheet

private struct CreateSiteFromGPSSheet: View {
    @Environment(\.dismiss) private var dismiss
    let diveId: String
    let latitude: Double
    let longitude: Double
    let onComplete: () -> Void

    @State private var siteName = ""
    @State private var location = ""
    @State private var siteType: DiveSite.SiteType = .reef
    @State private var difficulty: DiveSite.Difficulty = .intermediate
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private let database = AppDatabase.shared
    private var siteRepository: SiteRepository { SiteRepository(database: database) }
    private var diveRepository: DiveRepository { DiveRepository(database: database) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.lagoon)
                        Text(formatCoordinates())
                            .fontDesign(.monospaced)
                    }
                } header: {
                    Text("GPS Coordinates")
                }

                Section {
                    TextField("Site Name", text: $siteName)
                    TextField("Location (e.g., Okinawa, Japan)", text: $location)
                } header: {
                    Text("Details")
                }

                Section {
                    Picker("Site Type", selection: $siteType) {
                        ForEach(DiveSite.SiteType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(DiveSite.Difficulty.allCases, id: \.self) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                }
            }
            .navigationTitle("Create Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await createSite() }
                    }
                    .disabled(siteName.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Failed to create site")
            }
        }
    }

    private func formatCoordinates() -> String {
        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"
        return String(format: "%.4f°%@ %.4f°%@", abs(latitude), latDir, abs(longitude), lonDir)
    }

    private func createSite() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let site = DiveSite(
                name: siteName,
                location: location.isEmpty ? formatCoordinates() : location,
                latitude: latitude,
                longitude: longitude,
                region: location,
                averageDepth: 18,
                maxDepth: 25,
                averageTemp: 26,
                averageVisibility: 15,
                difficulty: difficulty,
                type: siteType,
                visitedCount: 1
            )

            try siteRepository.create(site)
            try diveRepository.linkToSite(diveId: diveId, siteId: site.id)

            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)

            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Link to Existing Site Sheet

private struct LinkToExistingSiteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let dive: DiveLog
    let onComplete: () -> Void

    @State private var searchText = ""
    @State private var sites: [DiveSite] = []
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false

    private let database = AppDatabase.shared
    private var siteRepository: SiteRepository { SiteRepository(database: database) }
    private var diveRepository: DiveRepository { DiveRepository(database: database) }

    var filteredSites: [DiveSite] {
        if searchText.isEmpty {
            return sites
        }
        return sites.filter { site in
            site.name.localizedCaseInsensitiveContains(searchText) ||
            site.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredSites.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("No sites found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredSites) { site in
                        Button(action: {
                            Task { await linkToSite(site) }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(site.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(site.location)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if let diveLat = dive.pendingLatitude,
                                   let diveLon = dive.pendingLongitude {
                                    let distance = calculateDistance(
                                        lat1: diveLat, lon1: diveLon,
                                        lat2: site.latitude, lon2: site.longitude
                                    )
                                    Text(formatDistance(distance))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search dive sites")
            .navigationTitle("Link to Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await loadSites()
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Failed to link dive")
            }
        }
    }

    private func loadSites() async {
        do {
            sites = try siteRepository.fetchAll()

            // Sort by distance from dive location
            if let diveLat = dive.pendingLatitude,
               let diveLon = dive.pendingLongitude {
                sites.sort { site1, site2 in
                    let d1 = calculateDistance(lat1: diveLat, lon1: diveLon, lat2: site1.latitude, lon2: site1.longitude)
                    let d2 = calculateDistance(lat1: diveLat, lon1: diveLon, lat2: site2.latitude, lon2: site2.longitude)
                    return d1 < d2
                }
            }
        } catch {
            Log.map.error("Error loading sites: \(error.localizedDescription)")
        }
    }

    private func linkToSite(_ site: DiveSite) async {
        isSaving = true
        defer { isSaving = false }

        do {
            try diveRepository.linkToSite(diveId: dive.id, siteId: site.id)

            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)

            onComplete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        // Haversine formula
        let R = 6371.0 // Earth's radius in km
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private func formatDistance(_ km: Double) -> String {
        if km < 1 {
            return String(format: "%.0fm", km * 1000)
        } else if km < 10 {
            return String(format: "%.1fkm", km)
        } else {
            return String(format: "%.0fkm", km)
        }
    }
}
