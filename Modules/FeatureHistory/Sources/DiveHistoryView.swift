import SwiftUI
import Charts
import UmiDB
import UmiDesignSystem
import UmiCoreKit

public struct DiveHistoryView: View {
    @StateObject private var viewModel = DiveHistoryViewModel()
    @State private var showFilterSheet = false

    public init() {}

    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.dives.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredDives.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    // Quick filter row
                    if !viewModel.dives.isEmpty {
                        quickFilterRow
                            .padding(.vertical, 8)
                    }

                    List {
                        ForEach(viewModel.filteredDives) { dive in
                            NavigationLink {
                                DiveDetailView(dive: dive, site: viewModel.getSite(for: dive))
                            } label: {
                                DiveHistoryRow(dive: dive, site: viewModel.getSite(for: dive))
                            }
                            .listRowBackground(Color.trench)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteDive(dive)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Dive History")
        .searchable(text: $viewModel.searchText, prompt: "Search dives, sites, or notes")
        .refreshable {
            await viewModel.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterButton
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            HistoryFilterSheet(viewModel: viewModel)
        }
        .background(Color.abyss.ignoresSafeArea())
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Dives Found", systemImage: "fish")
        } description: {
            if viewModel.filters.isActive {
                Text("No dives match your filters. Try adjusting them.")
            } else if !viewModel.searchText.isEmpty {
                Text("No dives match your search")
            } else {
                Text("Log your first dive to see it here")
            }
        } actions: {
            if viewModel.filters.isActive {
                Button {
                    viewModel.resetFilters()
                } label: {
                    Text("Clear Filters")
                }
                .buttonStyle(.bordered)
            } else if viewModel.searchText.isEmpty {
                Button {
                    Haptics.soft()
                    NotificationCenter.default.post(name: .showLogLauncher, object: nil)
                } label: {
                    Text("Start Logging")
                }
                .buttonStyle(.borderedProminent)
                .tint(.oceanBlue)
            }
        }
    }

    // MARK: - Quick Filter Row

    private var quickFilterRow: some View {
        FilterChipsRow {
            // Lens pills
            FilterPill(
                title: "All",
                isSelected: viewModel.filters.lens == nil,
                action: { viewModel.setLens(nil) }
            )

            ForEach(FilterLensType.allCases) { lens in
                FilterPill(
                    title: lens.displayName,
                    icon: lens.iconName,
                    isSelected: viewModel.filters.lens == lens,
                    action: { viewModel.setLens(lens) }
                )
            }

            FilterDivider()

            // Difficulty pills
            ForEach(DifficultyLevel.allCases) { difficulty in
                FilterPill(
                    title: difficulty.displayName,
                    isSelected: viewModel.filters.difficulty.contains(difficulty.rawValue),
                    selectedColor: difficultyColor(difficulty.rawValue),
                    action: { viewModel.toggleDifficulty(difficulty.rawValue) }
                )
            }
        }
    }

    // MARK: - Filter Button

    private var filterButton: some View {
        Button {
            showFilterSheet = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease.circle")

                if viewModel.filters.activeCount > 0 {
                    Text("\(viewModel.filters.activeCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.lagoon)
                        .clipShape(Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .accessibilityLabel("Filter dives")
        .accessibilityValue(viewModel.filters.activeCount > 0 ? "\(viewModel.filters.activeCount) filters active" : "No filters active")
        .accessibilityHint("Opens filter options")
    }

    // MARK: - Helpers

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "Beginner": return .difficultyBeginner
        case "Intermediate": return .difficultyIntermediate
        case "Advanced": return .difficultyAdvanced
        default: return .lagoon
        }
    }
}

private struct DiveHistoryRow: View {
    let dive: DiveLog
    let site: DiveSite?

    private var isRecentlyLogged: Bool {
        // Check if dive was logged in the past 7 days
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return dive.date > sevenDaysAgo
    }

    private var accessibilitySummary: String {
        let siteName = site?.name ?? "Unknown site"
        let dateString = formatDate(dive.date)
        var summary = "\(siteName), \(dateString). "
        summary += "Depth \(String(format: "%.1f", dive.maxDepth)) meters, "
        summary += "bottom time \(dive.bottomTime) minutes, "
        summary += "water temperature \(String(format: "%.0f", dive.temperature)) degrees."
        if isRecentlyLogged {
            summary += " Recently logged."
        }
        if dive.signed {
            summary += " Instructor signed."
        }
        return summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                if let site = site {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.name)
                            .font(.headline)
                        Text(site.location)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unknown Site")
                        .font(.headline)
                }

                Spacer()

                HStack(spacing: 8) {
                    if isRecentlyLogged {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.seaGreen)
                            .cornerRadius(4)
                    }

                    if dive.signed {
                        Image(systemName: "rosette")
                            .foregroundStyle(Color.seaGreen)
                    }
                }
            }

            // Stats
            HStack(spacing: 16) {
                Label(String(format: "%.1fm", dive.maxDepth), systemImage: "arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(Color.diveTeal)

                Label(DurationFormatter.formatCompact(minutes: dive.bottomTime), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label(String(format: "%.0f°C", dive.temperature), systemImage: "thermometer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Date
            Text(formatDate(dive.date))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Notes preview
            if !dive.notes.isEmpty {
                Text(dive.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("Double tap to view dive details")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct DiveDetailView: View {
    let dive: DiveLog
    let site: DiveSite?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var sightingDetails: [DiveSightingDetail] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // Site Info
                if let site = site {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(site.name)
                            .font(.title)
                            .bold()
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                            Text(site.location)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Dive Details
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dive Details")
                        .font(.headline)

                    DetailRow(label: "Max Depth", value: String(format: "%.1f m", dive.maxDepth), icon: "arrow.down")
                    DetailRow(label: "Bottom Time", value: DurationFormatter.format(minutes: dive.bottomTime), icon: "clock")
                    DetailRow(label: "Temperature", value: String(format: "%.0f°C", dive.temperature), icon: "thermometer")
                    DetailRow(label: "Visibility", value: String(format: "%.0f m", dive.visibility), icon: "eye")
                    DetailRow(label: "Current", value: dive.current.rawValue, icon: "wind")
                    DetailRow(label: "Conditions", value: dive.conditions.rawValue, icon: "sun.max")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // Depth Profile Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Depth Profile")
                        .font(.headline)

                    DepthProfileChart(
                        maxDepth: dive.maxDepth,
                        averageDepth: dive.averageDepth,
                        bottomTime: dive.bottomTime,
                        showSafetyStop: dive.maxDepth > 10
                    )
                    .accessibilityLabel("Depth profile chart showing dive to \(String(format: "%.0f", dive.maxDepth)) meters over \(dive.bottomTime) minutes")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Tank Info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tank Pressure")
                        .font(.headline)
                    
                    DetailRow(label: "Start", value: "\(dive.startPressure) bar", icon: "gauge.high")
                    DetailRow(label: "End", value: "\(dive.endPressure) bar", icon: "gauge.low")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Notes
                if !dive.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(dive.notes)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }

                if !sightingDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sightings")
                            .font(.headline)

                        ForEach(sightingDetails) { detail in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(detail.speciesName)
                                            .font(.subheadline.weight(.semibold))
                                        if let scientific = detail.speciesScientificName, !scientific.isEmpty {
                                            Text(scientific)
                                                .font(.caption)
                                                .italic()
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("x\(detail.sighting.count)")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.diveTeal.opacity(0.2))
                                        .clipShape(Capsule())
                                }

                                if let notes = detail.sighting.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if !detail.photos.isEmpty {
                                    SightingGalleryView(photos: detail.photos)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Instructor
                if let instructor = dive.instructorName {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Instructor Sign-off")
                            .font(.headline)
                        HStack {
                            Image(systemName: dive.signed ? "checkmark.seal.fill" : "xmark.seal")
                                .foregroundStyle(dive.signed ? Color.seaGreen : Color.gray)
                            VStack(alignment: .leading) {
                                Text(instructor)
                                if let number = dive.instructorNumber {
                                    Text(number)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle(formatDate(dive.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareItems = ShareCardGenerator.share(dive: dive, site: site)
                    showingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share dive")
                .accessibilityHint("Share this dive log as an image")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .task {
            await loadSightings()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func loadSightings() async {
        do {
            let details = try SightingsRepository(database: AppDatabase.shared).fetchDetailedByDive(dive.id)
            await MainActor.run {
                sightingDetails = details
            }
        } catch {
            await MainActor.run {
                sightingDetails = []
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct SightingGalleryView: View {
    let photos: [SightingPhoto]
    @State private var showingFullScreen = false
    @State private var selectedIndex = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    let image = thumbnailImage(for: photo)
                    Button {
                        selectedIndex = index
                        showingFullScreen = true
                    } label: {
                        Group {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(Image(systemName: "photo"))
                            }
                        }
                        .frame(width: 82, height: 82)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .fullScreenCover(isPresented: $showingFullScreen) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                TabView(selection: $selectedIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        Group {
                            if let image = fullImage(for: photo) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))

                Button {
                    showingFullScreen = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                        .padding()
                }
            }
        }
    }

    private func thumbnailImage(for photo: SightingPhoto) -> UIImage? {
        if let url = SightingPhotoStorageService.shared.imageURL(forRelativePath: photo.thumbnailFilename) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }

    private func fullImage(for photo: SightingPhoto) -> UIImage? {
        if let url = SightingPhotoStorageService.shared.imageURL(forRelativePath: photo.filename) {
            return UIImage(contentsOfFile: url.path)
        }
        return nil
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

#Preview {
    NavigationStack {
        DiveHistoryView()
    }
}
