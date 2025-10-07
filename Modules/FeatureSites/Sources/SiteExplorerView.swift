import SwiftUI
import UmiDB
import UmiDesignSystem

public struct SiteExplorerView: View {
    @StateObject private var viewModel = SiteExplorerViewModel()
    
    public init() {}
    
    public var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sites.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredSites.isEmpty {
                ContentUnavailableView(
                    "No Sites Found",
                    systemImage: "map",
                    description: Text(viewModel.searchText.isEmpty ? "Load some sample data to get started" : "No sites match your search")
                )
            } else {
                List {
                    ForEach(viewModel.filteredSites) { site in
                        NavigationLink {
                            SiteDetailView(site: site, viewModel: viewModel)
                        } label: {
                            SiteRow(site: site)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Dive Sites")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Filter", selection: $viewModel.filter) {
                        ForEach(SiteExplorerViewModel.SiteFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search sites, locations, or regions")
        .refreshable {
            await viewModel.refresh()
        }
    }
}

private struct SiteRow: View {
    let site: DiveSite
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle")
                            .font(.caption)
                        Text(site.location)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    DifficultyBadge(difficulty: site.difficulty)
                    if site.wishlist {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.coralRed)
                            .font(.caption)
                    }
                }
            }
            
            HStack(spacing: 16) {
                Label(String(format: "%.0fm", site.maxDepth), systemImage: "arrow.down")
                    .font(.caption)
                    .foregroundStyle(.diveTeal)
                
                Label(String(format: "%.0f°C", site.averageTemp), systemImage: "thermometer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Label(site.type.rawValue, systemImage: typeIcon(for: site.type))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func typeIcon(for type: DiveSite.SiteType) -> String {
        switch type {
        case .reef: return "brain"
        case .wreck: return "sailboat"
        case .wall: return "square.stack.3d.down.right"
        case .cave: return "cave.fill"
        case .shore: return "beach.umbrella"
        case .drift: return "wind"
        }
    }
}

private struct DifficultyBadge: View {
    let difficulty: DiveSite.Difficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
    
    private var color: Color {
        switch difficulty {
        case .beginner: return .seaGreen
        case .intermediate: return .oceanBlue
        case .advanced: return .coralRed
        }
    }
}

private struct SiteDetailView: View {
    let site: DiveSite
    @ObservedObject var viewModel: SiteExplorerViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.name)
                                .font(.title.bold())
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                Text(site.location)
                            }
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            Task {
                                await viewModel.toggleWishlist(site: site)
                            }
                        } label: {
                            Image(systemName: site.wishlist ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(site.wishlist ? .coralRed : .secondary)
                        }
                    }
                    
                    HStack {
                        DifficultyBadge(difficulty: site.difficulty)
                        Text(site.type.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.oceanBlue.opacity(0.2))
                            .foregroundStyle(.oceanBlue)
                            .cornerRadius(4)
                        Text(site.region)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.secondarySystemFill))
                            .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Site Stats
                VStack(alignment: .leading, spacing: 16) {
                    Text("Site Information")
                        .font(.headline)
                    
                    DetailRow(label: "Max Depth", value: String(format: "%.0f m", site.maxDepth), icon: "arrow.down")
                    DetailRow(label: "Avg Depth", value: String(format: "%.0f m", site.averageDepth), icon: "arrow.down.right")
                    DetailRow(label: "Temperature", value: String(format: "%.0f°C", site.averageTemp), icon: "thermometer")
                    DetailRow(label: "Visibility", value: String(format: "%.0f m", site.averageVisibility), icon: "eye")
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Description
                if let description = site.description {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        Text(description)
                            .font(.body)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Coordinates
                VStack(alignment: .leading, spacing: 8) {
                    Text("Coordinates")
                        .font(.headline)
                    Text(String(format: "%.4f°, %.4f°", site.latitude, site.longitude))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle(site.name)
        .navigationBarTitleDisplayMode(.inline)
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
        SiteExplorerView()
    }
}
