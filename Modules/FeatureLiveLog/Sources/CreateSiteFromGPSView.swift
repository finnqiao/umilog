import SwiftUI
import UmiDB
import UmiDesignSystem

/// Sheet shown after saving a GPS-only dive to create a new site from the coordinates
public struct CreateSiteFromGPSView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateSiteFromGPSViewModel

    private let onSiteCreated: ((DiveSite) -> Void)?

    public init(
        diveId: String,
        latitude: Double,
        longitude: Double,
        locationName: String?,
        onSiteCreated: ((DiveSite) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: CreateSiteFromGPSViewModel(
            diveId: diveId,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        ))
        self.onSiteCreated = onSiteCreated
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with GPS info
                    GPSInfoHeader(
                        latitude: viewModel.latitude,
                        longitude: viewModel.longitude,
                        locationName: viewModel.locationName
                    )

                    // Site details form
                    VStack(spacing: 16) {
                        // Site name
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Site Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("Enter site name", text: $viewModel.siteName)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Location description
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Location")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField("e.g., Okinawa, Japan", text: $viewModel.location)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Site type picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Site Type")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(DiveSite.SiteType.allCases, id: \.self) { type in
                                        TypeChip(
                                            type: type,
                                            isSelected: viewModel.siteType == type
                                        ) {
                                            viewModel.siteType = type
                                        }
                                    }
                                }
                            }
                        }

                        // Difficulty picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Difficulty")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                ForEach(DiveSite.Difficulty.allCases, id: \.self) { difficulty in
                                    DifficultyChip(
                                        difficulty: difficulty,
                                        isSelected: viewModel.difficulty == difficulty
                                    ) {
                                        viewModel.difficulty = difficulty
                                    }
                                }
                            }
                        }

                        // Average depth (pre-filled from dive)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Average Depth")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    TextField("0", value: $viewModel.averageDepth, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)

                                    Text("m")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Max Depth")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack {
                                    TextField("0", value: $viewModel.maxDepth, format: .number)
                                        .textFieldStyle(.roundedBorder)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)

                                    Text("m")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: createSite) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                Text("Create Site")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!viewModel.canCreate)

                        Button(action: { dismiss() }) {
                            Text("Skip for Now")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Name This Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Failed to create site")
            }
        }
    }

    private func createSite() {
        Task {
            if let site = await viewModel.createSiteAndLink() {
                onSiteCreated?(site)
                dismiss()
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class CreateSiteFromGPSViewModel: ObservableObject {
    let diveId: String
    let latitude: Double
    let longitude: Double
    let locationName: String?

    @Published var siteName: String = ""
    @Published var location: String = ""
    @Published var siteType: DiveSite.SiteType = .reef
    @Published var difficulty: DiveSite.Difficulty = .intermediate
    @Published var averageDepth: Double = 18.0
    @Published var maxDepth: Double = 25.0

    @Published var showingError = false
    @Published var errorMessage: String?

    private let database = AppDatabase.shared
    private let siteRepository: SiteRepository
    private let diveRepository: DiveRepository

    var canCreate: Bool {
        !siteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(diveId: String, latitude: Double, longitude: Double, locationName: String?) {
        self.diveId = diveId
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.siteRepository = SiteRepository(database: database)
        self.diveRepository = DiveRepository(database: database)

        // Pre-fill location from geocoded name
        if let name = locationName {
            // Remove "Near " prefix if present
            let cleanName = name.hasPrefix("Near ") ? String(name.dropFirst(5)) : name
            self.location = cleanName
        }
    }

    func createSiteAndLink() async -> DiveSite? {
        guard canCreate else { return nil }

        do {
            // Create new site
            let site = DiveSite(
                name: siteName.trimmingCharacters(in: .whitespacesAndNewlines),
                location: location.isEmpty ? formatCoordinates() : location,
                latitude: latitude,
                longitude: longitude,
                region: location.isEmpty ? "" : location,
                averageDepth: averageDepth,
                maxDepth: maxDepth,
                averageTemp: 26,
                averageVisibility: 15,
                difficulty: difficulty,
                type: siteType,
                visitedCount: 1
            )

            try siteRepository.create(site)

            // Link the dive to this site
            try diveRepository.linkToSite(diveId: diveId, siteId: site.id)

            // Post notification for map update
            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)

            return site

        } catch {
            errorMessage = "Failed to create site: \(error.localizedDescription)"
            showingError = true
            return nil
        }
    }

    private func formatCoordinates() -> String {
        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"
        return String(format: "%.4f°%@ %.4f°%@", abs(latitude), latDir, abs(longitude), lonDir)
    }
}

// MARK: - Components

private struct GPSInfoHeader: View {
    let latitude: Double
    let longitude: Double
    let locationName: String?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.lagoon.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "location.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.lagoon)
            }

            VStack(spacing: 4) {
                Text("Dive Logged!")
                    .font(.headline)

                if let name = locationName {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(formatCoordinates())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fontDesign(.monospaced)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }

    private func formatCoordinates() -> String {
        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"
        return String(format: "%.4f°%@ %.4f°%@", abs(latitude), latDir, abs(longitude), lonDir)
    }
}

private struct TypeChip: View {
    let type: DiveSite.SiteType
    let isSelected: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        isSelected ? Color.lagoon : Color.gray.opacity(0.15)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                Text(type.rawValue)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .foregroundColor(isSelected ? .white : Color(.label))
            .cornerRadius(20)
        }
    }

    private var iconName: String {
        switch type {
        case .reef: return "waveform"
        case .wreck: return "ferry"
        case .wall: return "arrow.down.to.line"
        case .cave: return "mountain.2"
        case .shore: return "beach.umbrella"
        case .drift: return "wind"
        }
    }
}

private struct DifficultyChip: View {
    let difficulty: DiveSite.Difficulty
    let isSelected: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        isSelected ? difficultyColor : Color.gray.opacity(0.15)
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        }
    }

    var body: some View {
        Button(action: action) {
            Text(difficulty.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .foregroundColor(isSelected ? .white : Color(.label))
                .cornerRadius(20)
        }
    }
}

