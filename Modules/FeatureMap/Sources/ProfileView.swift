import SwiftUI
import UmiDB
import UmiDesignSystem
import GRDB

public struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var mapEnginePreference = UserDefaults.standard.bool(forKey: "app.umilog.preferences.useMapLibre") {
        didSet {
            UserDefaults.standard.set(mapEnginePreference, forKey: "app.umilog.preferences.useMapLibre")
            // Post notification that map engine changed
            NotificationCenter.default.post(name: NSNotification.Name("mapEngineChanged"), object: nil)
        }
    }
    @Environment(\.underwaterThemeBinding) private var underwaterThemeBinding
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Certification header
                VStack(spacing: 8) {
                    Text("Certification")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Advanced Open Water")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Diving since 3/15/2022")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [.oceanBlue, .diveTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // Stats tiles
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatTile(title: "Total Dives", value: "\(viewModel.totalDives)")
                    StatTile(title: "Max Depth", value: "\(viewModel.maxDepth)m")
                    StatTile(title: "Sites Visited", value: "\(viewModel.sitesVisited)")
                    StatTile(title: "Species", value: "\(viewModel.speciesCount)")
                }
                .padding(.horizontal, 16)
                
                StatTile(title: "Total Bottom Time", value: viewModel.totalBottomTime)
                    .padding(.horizontal, 16)
                
                // Achievements
                VStack(alignment: .leading, spacing: 12) {
                    Text("Achievements")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    HStack(spacing: 16) {
                        AchievementBadge(title: "First Dive", icon: "map.fill", color: .blue)
                        AchievementBadge(title: "Deep Diver", icon: "arrow.down.circle.fill", color: .orange)
                    }
                    .padding(.horizontal, 16)
                }
                
                // Cloud backup
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Cloud backup")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text("On")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            Text("Last sync: Just now")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: .constant(true))
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // Get Started section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Get Started")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    ActionRow(icon: "applewatch", title: "Connect Apple Watch", subtitle: "Auto-log dives", color: .blue)
                    ActionRow(icon: "arrow.up.doc", title: "Import from CSV/UDDF", subtitle: "Bring existing logs", color: .purple)
                    ActionRow(icon: "plus.square", title: "Backfill Past Dives", subtitle: "Add multiple dives quickly", color: .blue)
                    ActionRow(icon: "square.and.arrow.down", title: "Export All Data", subtitle: "Download your dive logs", color: .green)
                }
                
                // Developer (Debug)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Developer")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    HStack {
                        Text("Underwater Theme")
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: underwaterThemeBinding ?? .constant(true))
                            .onChange(of: underwaterThemeBinding?.wrappedValue ?? true) {
                                Haptics.soft()
                            }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    HStack {
                        Text("Map Engine")
                            .font(.body)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { mapEnginePreference ? "MapLibre" : "MapKit" },
                            set: { newValue in
                                mapEnginePreference = newValue == "MapLibre"
                                Haptics.soft()
                            }
                        )) {
                            Text("MapLibre").tag("MapLibre")
                            Text("MapKit").tag("MapKit")
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                }
                
                // Privacy & Security
                VStack(alignment: .leading, spacing: 12) {
                    Text("Privacy & Security")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    HStack {
                        Text("Face ID Lock")
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: .constant(false))
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete All Data")
                        }
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
    }
}

struct StatTile: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal, 16)
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var totalDives: Int = 0
    @Published var maxDepth: Int = 0
    @Published var sitesVisited: Int = 0
    @Published var speciesCount: Int = 0
    @Published var totalBottomTime: String = "0h 0m"
    
    private let diveRepository = DiveRepository(database: AppDatabase.shared)
    private let database = AppDatabase.shared
    
    init() {
        loadStats()
    }
    
    func loadStats() {
        Task {
            do {
                let stats = try diveRepository.calculateStats()
                await updateStats(stats)
            } catch {
                // Use zero/default values on error
                print("Error loading dive stats: \(error)")
            }
        }
    }
    
    @MainActor
    private func updateStats(_ stats: DiveStats) {
        self.totalDives = stats.totalDives
        self.maxDepth = Int(stats.maxDepth)
        self.sitesVisited = stats.sitesVisited
        self.totalBottomTime = formatBottomTime(seconds: stats.totalBottomTime)
        
        // Load species count from sightings
        Task {
            do {
                let uniqueSpeciesCount = try database.read { db in
                    let row = try Row.fetchOne(db, sql: "SELECT COUNT(DISTINCT speciesId) as count FROM sightings")
                    return row?["count"] as? Int ?? 0
                }
                await MainActor.run {
                    self.speciesCount = uniqueSpeciesCount
                }
            } catch {
                print("Error loading species count: \(error)")
            }
        }
    }
    
    private func formatBottomTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}
