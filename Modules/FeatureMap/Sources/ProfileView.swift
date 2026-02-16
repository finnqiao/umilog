import SwiftUI
import UmiDB
import UmiDesignSystem
import GRDB
import UmiCoreKit
import FeatureSettings
import FeatureHome
import FeatureSites
import FeatureLiveLog
import UmiWatchKit
import os

public struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.underwaterThemeBinding) private var underwaterThemeBinding
    @State private var showingImport = false
    @State private var showingBackfill = false
    @State private var showingWatchConnect = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @StateObject private var watchManager = WatchConnectivityManager.shared

    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Certification header - improved contrast for AA compliance
                VStack(spacing: 8) {
                    Text("Certification")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Advanced Open Water")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Diving since 3/15/2022")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        LinearGradient(colors: [.oceanBlue, .diveTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
                        // Dark overlay for improved text contrast (AA compliance)
                        Color.black.opacity(0.15)
                    }
                )
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
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
                            .accessibilityLabel("Cloud backup")
                            .accessibilityHint("Syncs your dive logs to iCloud")
                    }
                }
                .padding(16)
                .background(Color.trench)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                
                // Get Started section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Get Started")
                        .font(.headline)
                        .padding(.horizontal, 16)
                    
                    ActionRow(icon: "applewatch", title: "Apple Watch", subtitle: watchManager.isPaired ? "Connected" : "Tap to connect", color: .oceanBlue) {
                        showingWatchConnect = true
                    }
                    ActionRow(icon: "arrow.up.doc", title: "Import from CSV/UDDF", subtitle: "Bring existing logs", color: .divePurple) {
                        showingImport = true
                    }
                    ActionRow(icon: "plus.square", title: "Backfill Past Dives", subtitle: "Add multiple dives quickly", color: .oceanBlue) {
                        showingBackfill = true
                    }
                    ActionRow(icon: "square.and.arrow.down", title: "Export All Data", subtitle: "Download your dive logs", color: .seaGreen) {
                        exportDiveData()
                    }
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
                            .accessibilityLabel("Underwater Theme")
                            .accessibilityHint("Enables ocean-themed visual styling")
                    }
                    .padding(16)
                    .background(Color.trench)
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
                        Toggle("", isOn: Binding(
                            get: { viewModel.isLockEnabled },
                            set: { newValue in
                                Task {
                                    await viewModel.toggleLock(enabled: newValue)
                                }
                            }
                        ))
                            .accessibilityLabel("Face ID Lock")
                            .accessibilityHint("Require Face ID to open the app")
                    }
                    .padding(16)
                    .background(Color.trench)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)

                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isDeleting ? "Deleting..." : "Delete All Data")
                        }
                        .font(.body)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal, 16)
                    .accessibilityLabel("Delete All Data")
                    .accessibilityHint("Permanently removes all dive logs and settings")
                    .confirmationDialog(
                        "Delete All Data?",
                        isPresented: $showingDeleteConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete Everything", role: .destructive) {
                            deleteAllData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all your dive logs and sightings. This action cannot be undone.")
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.abyss.ignoresSafeArea())
        .navigationTitle("Profile")
        .underwaterAccent()
        .sheet(isPresented: $showingImport) {
            ImportFlowView()
        }
        .sheet(isPresented: $showingBackfill) {
            BackfillView()
        }
        .sheet(isPresented: $showingWatchConnect) {
            WatchConnectView()
        }
        .onAppear {
            watchManager.activate()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink {
                        DashboardView()
                    } label: {
                        Label("Dashboard", systemImage: "rectangle.3.group")
                    }

                    NavigationLink {
                        SiteExplorerView()
                    } label: {
                        Label("Site Explorer", systemImage: "list.bullet")
                    }

                    Divider()

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("More options")
                }
            }
        }
    }
    
    private func exportDiveData() {
        // Placeholder: in production this would generate CSV/JSON and send via email
        Log.app.info("Export data initiated")
    }

    private func deleteAllData() {
        isDeleting = true
        Task {
            do {
                // Delete user data from database
                try AppDatabase.shared.deleteAllUserData()

                // Clear image cache
                await ImageCacheService.shared.clearCache()

                // Reset relevant UserDefaults
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: "selectedTab")
                defaults.removeObject(forKey: "app.umilog.hasLaunchedBefore")

                // Haptic feedback
                await MainActor.run {
                    Haptics.success()
                    isDeleting = false
                    // Refresh stats
                    viewModel.loadStats()
                }

                Log.app.info("All user data deleted successfully")

                // Post notification so other views can refresh
                NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
            } catch {
                await MainActor.run {
                    isDeleting = false
                    Haptics.error()
                }
                Log.app.error("Failed to delete user data: \(error.localizedDescription)")
            }
        }
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
        .background(Color.trench)
        .cornerRadius(16)
    }
}

struct AchievementBadge: View {
    let title: String
    let icon: String
    let color: Color

    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 60
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: badgeSize, height: badgeSize)

                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(color)
            }

            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.trench)
        .cornerRadius(16)
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var action: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .body) private var iconCircleSize: CGFloat = 40

    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: iconCircleSize, height: iconCircleSize)

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
            .background(Color.trench)
            .cornerRadius(16)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint("Double tap to \(title.lowercased())")
    }
}

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var totalDives: Int = 0
    @Published var maxDepth: Int = 0
    @Published var sitesVisited: Int = 0
    @Published var speciesCount: Int = 0
    @Published var totalBottomTime: String = "0h 0m"
    @Published var isLockEnabled: Bool = false

    private let diveRepository = DiveRepository(database: AppDatabase.shared)
    private let database = AppDatabase.shared

    init() {
        loadStats()
        loadLockState()
    }

    private func loadLockState() {
        Task {
            let enabled = await AppLockService.shared.isLockEnabled()
            await MainActor.run {
                self.isLockEnabled = enabled
            }
        }
    }

    func toggleLock(enabled: Bool) async {
        if enabled {
            // Authenticate before enabling
            let success = await AppLockService.shared.authenticate(reason: "Enable Face ID Lock")
            if success {
                await AppLockService.shared.setLockEnabled(true)
                await MainActor.run {
                    self.isLockEnabled = true
                    Haptics.success()
                }
            }
        } else {
            await AppLockService.shared.setLockEnabled(false)
            await MainActor.run {
                self.isLockEnabled = false
                Haptics.soft()
            }
        }
    }
    
    func loadStats() {
        Task {
            do {
                let stats = try diveRepository.calculateStats()
                updateStats(stats)
            } catch {
                // Use zero/default values on error
                Log.diveLog.error("Error loading dive stats: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func updateStats(_ stats: DiveStats) {
        self.totalDives = stats.totalDives
        self.maxDepth = Int(stats.maxDepth)
        self.sitesVisited = stats.sitesVisited
        self.totalBottomTime = DurationFormatter.format(seconds: stats.totalBottomTime)
        
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
                Log.wildlife.error("Error loading species count: \(error.localizedDescription)")
            }
        }
    }
}
