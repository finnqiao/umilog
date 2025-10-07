import SwiftUI
import UmiDesignSystem
import UmiDB

public struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("UmiLog")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.oceanBlue)
                        Text("Your dive adventures await")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Label("Log Dive", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.oceanBlue)
                }
                .padding(.horizontal)
                
                // Quick Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(value: "\(viewModel.stats.totalDives)", label: "Total Dives", color: .oceanBlue)
                    StatCard(value: String(format: "%.0fm", viewModel.stats.maxDepth), label: "Max Depth", color: .diveTeal)
                    StatCard(value: "\(viewModel.stats.sitesVisited)", label: "Sites Visited", color: .seaGreen)
                    StatCard(value: "\(viewModel.stats.speciesSpotted)", label: "Species Spotted", color: .divePurple)
                }
                .padding(.horizontal)
                
                // Hero Map Card
                Card {
                    ZStack(alignment: .bottomLeading) {
                        Rectangle()
                            .fill(Color.oceanBlue.opacity(0.2))
                            .frame(height: 200)
                        
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Explore Dive Sites")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("\(viewModel.stats.sitesVisited) sites visited • Discover more")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding()
                    }
                }
                .padding(.horizontal)
                
                // Recent Dives
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Label("Recent Dives", systemImage: "calendar")
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Button("View All") {}
                            .font(.subheadline)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        if viewModel.recentDives.isEmpty {
                            // Empty state
                            Card {
                                VStack(spacing: 16) {
                                    Image(systemName: "fish.fill")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.oceanBlue.opacity(0.5))
                                    
                                    Text("No dives logged yet")
                                        .font(.headline)
                                    
                                    Text("Start your diving journey by logging your first dive!")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Button("Load Sample Data") {
                                        Task {
                                            await viewModel.seedSampleData()
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.oceanBlue)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            }
                            .padding(.horizontal)
                        } else {
                            // Dive list
                            ForEach(viewModel.recentDives) { dive in
                                DiveRow(dive: dive)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Quick Actions
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    QuickActionCard(
                        icon: "map.fill",
                        title: "Site Explorer",
                        description: "Find new dive sites",
                        color: .oceanBlue
                    )
                    
                    QuickActionCard(
                        icon: "chart.bar.fill",
                        title: "Statistics",
                        description: "View your progress",
                        color: .seaGreen
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DiveRow: View {
    let dive: DiveLog
    
    var body: some View {
        Card {
            HStack(spacing: 16) {
                // Icon
                Circle()
                    .fill(Color.oceanBlue.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "fish.fill")
                            .foregroundStyle(.oceanBlue)
                    }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(formatDate(dive.date))
                            .font(.headline)
                        
                        if dive.signed {
                            Image(systemName: "rosette")
                                .font(.caption)
                                .foregroundStyle(.seaGreen)
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Label(String(format: "%.1fm", dive.maxDepth), systemImage: "arrow.down")
                        Label("\(dive.bottomTime)min", systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    if !dive.notes.isEmpty {
                        Text(dive.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

private struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            Card {
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundStyle(color)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
    }
}
