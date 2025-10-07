import SwiftUI

public struct DashboardView: View {
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
                    StatCard(value: "0", label: "Total Dives", color: .oceanBlue)
                    StatCard(value: "0m", label: "Max Depth", color: .diveTeal)
                    StatCard(value: "0", label: "Sites Visited", color: .seaGreen)
                    StatCard(value: "0", label: "Species Spotted", color: .divePurple)
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
                            Text("0 sites visited • Discover more")
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
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        }
                        .padding(.horizontal)
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
