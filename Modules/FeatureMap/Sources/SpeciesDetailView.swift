import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit

/// Detailed view for a wildlife species showing reference photos, sighting history, and habitats.
public struct SpeciesDetailView: View {
    @StateObject private var viewModel: SpeciesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    public init(species: WildlifeSpecies) {
        _viewModel = StateObject(wrappedValue: SpeciesDetailViewModel(species: species))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero image
                HeroImageSection(
                    speciesId: viewModel.species.id,
                    category: viewModel.species.category,
                    imageUrl: viewModel.species.imageUrl.flatMap { URL(string: $0) },
                    seen: viewModel.sightingCount > 0
                )

                // Content sections
                VStack(spacing: 24) {
                    // Species name and scientific name
                    HeaderSection(species: viewModel.species)

                    // Quick facts
                    QuickFactsSection(
                        species: viewModel.species,
                        sightingCount: viewModel.sightingCount
                    )

                    // Reference photos
                    if !viewModel.referenceImages.isEmpty {
                        ReferencePhotosSection(images: viewModel.referenceImages)
                    }

                    // Description
                    if let description = viewModel.species.description, !description.isEmpty {
                        DescriptionSection(description: description)
                    }

                    // Sighting history
                    if !viewModel.sightings.isEmpty {
                        SightingHistorySection(sightings: viewModel.sightings)
                    }

                    // Sightings map
                    if !viewModel.habitats.isEmpty {
                        SightingsMapSection(
                            habitats: viewModel.habitats,
                            sightingCounts: viewModel.sightingCountsBySite
                        )
                    }

                    // Where to find
                    if !viewModel.habitats.isEmpty {
                        HabitatSection(habitats: viewModel.habitats)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.abyss.ignoresSafeArea())
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Hero Image Section

private struct HeroImageSection: View {
    let speciesId: String
    let category: WildlifeSpecies.Category
    let imageUrl: URL?
    let seen: Bool

    @State private var loadedImage: UIImage?
    @State private var isLoading = false

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if isLoading {
                    // Loading state
                    ZStack {
                        LinearGradient(
                            colors: [categoryColor.opacity(0.2), categoryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        ProgressView()
                            .scaleEffect(1.5)
                    }
                } else {
                    // Fallback gradient with category icon
                    ZStack {
                        LinearGradient(
                            colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        Image(systemName: categoryIcon)
                            .font(.system(size: 80))
                            .foregroundStyle(categoryColor.opacity(0.6))
                    }
                }
            }
            .frame(width: geometry.size.width, height: 280)
            .clipped()
        }
        .frame(height: 280)
        .task(id: speciesId) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // 1. Check bundle first
        if let bundled = UIImage(named: "species_\(speciesId)") {
            loadedImage = bundled
            return
        }

        // 2. Try cache/network
        guard imageUrl != nil else { return }

        isLoading = true
        defer { isLoading = false }

        let cacheKey = "species_\(speciesId)"
        let image = await ImageCacheService.shared.image(for: cacheKey, url: imageUrl)
        loadedImage = image
    }

    private var categoryIcon: String {
        switch category {
        case .fish: return "fish.fill"
        case .coral: return "sparkles"
        case .mammal: return "hare.fill"
        case .invertebrate: return "ladybug.fill"
        case .reptile: return "tortoise.fill"
        }
    }

    private var categoryColor: Color {
        switch category {
        case .fish: return .blue
        case .coral: return .orange
        case .mammal: return .purple
        case .invertebrate: return .pink
        case .reptile: return .green
        }
    }
}

// MARK: - Header Section

private struct HeaderSection: View {
    let species: WildlifeSpecies

    var body: some View {
        VStack(spacing: 4) {
            Text(species.name)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color.foam)

            Text(species.scientificName)
                .font(.subheadline)
                .foregroundStyle(Color.mist)
                .italic()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Facts Section

private struct QuickFactsSection: View {
    let species: WildlifeSpecies
    let sightingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Category badge
                FactBadge(
                    icon: categoryIcon,
                    label: species.category.rawValue,
                    color: categoryColor
                )

                // Rarity badge
                FactBadge(
                    icon: "star.fill",
                    label: species.rarity.rawValue,
                    color: rarityColor
                )

                // Conservation status if available
                if let status = species.conservationStatus {
                    FactBadge(
                        icon: "leaf.fill",
                        label: status,
                        color: conservationColor(for: status)
                    )
                }
            }

            // Sighting count
            if sightingCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(Color.lagoon)
                    Text("You've spotted this species \(sightingCount) time\(sightingCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryIcon: String {
        switch species.category {
        case .fish: return "fish.fill"
        case .coral: return "sparkles"
        case .mammal: return "hare.fill"
        case .invertebrate: return "ladybug.fill"
        case .reptile: return "tortoise.fill"
        }
    }

    private var categoryColor: Color {
        switch species.category {
        case .fish: return .blue
        case .coral: return .orange
        case .mammal: return .purple
        case .invertebrate: return .pink
        case .reptile: return .green
        }
    }

    private var rarityColor: Color {
        switch species.rarity {
        case .common: return .green
        case .uncommon: return .blue
        case .rare: return .purple
        case .veryRare: return .orange
        }
    }

    private func conservationColor(for status: String) -> Color {
        switch status.uppercased() {
        case "LC": return .green // Least Concern
        case "NT": return .teal // Near Threatened
        case "VU": return .yellow // Vulnerable
        case "EN": return .orange // Endangered
        case "CR": return .red // Critically Endangered
        default: return .gray
        }
    }
}

private struct FactBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .cornerRadius(12)
    }
}

// MARK: - Reference Photos Section

private struct ReferencePhotosSection: View {
    let images: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reference Photos")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(images, id: \.self) { imageName in
                        if let uiImage = UIImage(named: imageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 160, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Description Section

private struct DescriptionSection: View {
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(Color.mist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sighting History Section

private struct SightingHistorySection: View {
    let sightings: [SpeciesSightingInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Sightings")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(sightings.prefix(5)) { sighting in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sighting.siteName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(sighting.date, style: .date)
                                .font(.caption)
                                .foregroundStyle(Color.mist)
                        }

                        Spacer()

                        if sighting.count > 1 {
                            Text("x\(sighting.count)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.lagoon.opacity(0.15))
                                .foregroundStyle(Color.lagoon)
                                .cornerRadius(8)
                        }
                    }
                    .padding(12)
                    .background(Color.trench)
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Sightings Map Section

private struct SightingsMapSection: View {
    let habitats: [SpeciesHabitatInfo]
    let sightingCounts: [String: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sighting Locations")
                .font(.headline)

            SightingsMapView(
                locations: habitats.map { habitat in
                    habitat.toSightingLocation(
                        sightingCount: sightingCounts[habitat.siteId] ?? 0
                    )
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Habitat Section

private struct HabitatSection: View {
    let habitats: [SpeciesHabitatInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where to Find")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(habitats.prefix(5)) { habitat in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habitat.siteName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(habitat.siteLocation)
                                .font(.caption)
                                .foregroundStyle(Color.mist)
                        }

                        Spacer()

                        LikelihoodBadge(likelihood: habitat.likelihood)
                    }
                    .padding(12)
                    .background(Color.trench)
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LikelihoodBadge: View {
    let likelihood: SiteSpeciesLink.Likelihood

    var body: some View {
        Text(likelihood.rawValue.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(likelihoodColor.opacity(0.15))
            .foregroundStyle(likelihoodColor)
            .cornerRadius(8)
    }

    private var likelihoodColor: Color {
        switch likelihood {
        case .common: return .green
        case .occasional: return .orange
        case .rare: return .red
        }
    }
}

// MARK: - Supporting Types

struct SpeciesSightingInfo: Identifiable {
    let id: String
    let siteName: String
    let date: Date
    let count: Int
}

struct SpeciesHabitatInfo: Identifiable {
    let id: String
    let siteId: String
    let siteName: String
    let siteLocation: String
    let likelihood: SiteSpeciesLink.Likelihood
    let latitude: Double
    let longitude: Double

    /// Convert to SightingLocation for map display
    func toSightingLocation(sightingCount: Int = 1) -> SightingLocation {
        SightingLocation(
            id: id,
            siteId: siteId,
            siteName: siteName,
            latitude: latitude,
            longitude: longitude,
            sightingCount: sightingCount
        )
    }
}
