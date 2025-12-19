import Foundation
import SwiftUI
import FeatureMap
import FeatureHome
import FeatureLiveLog
import FeatureHistory
import FeatureSites
import FeatureSettings
import UmiDesignSystem
import UmiDB
import UmiLocationKit
import os

@main
struct UmiLogApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

/// Root view with tab navigation (map-first design)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .map
    @State private var showingWizard = false
    @State private var showingQuickLog = false
    @State private var showingLogLauncher = false
    @State private var pendingLiveLogSite: DiveSite?
    @State private var isTabBarHidden = false
    
    var body: some View {
        ZStack {
            if appState.underwaterThemeEnabled {
                UnderwaterThemeView { tabs }
                    .wateryTransition()
            } else {
                tabs
            }
        }
        .environment(\.underwaterThemeBinding, underwaterThemeBinding)
        .onReceive(NotificationCenter.default.publisher(for: .tabBarVisibilityShouldChange)) { notification in
            guard let hidden = notification.userInfo?["hidden"] as? Bool else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isTabBarHidden = hidden
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .log {
                selectedTab = .map
                showingLogLauncher = true
            }
        }
        .sheet(isPresented: $showingWizard) {
            LiveLogWizardView(initialSite: pendingLiveLogSite)
                .wateryTransition()
        }
        .sheet(isPresented: $showingQuickLog) {
            QuickLogView()
                .wateryTransition()
        }
        .sheet(isPresented: $showingLogLauncher) {
            LogLauncherView(
                startQuickLog: {
                    showingLogLauncher = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showingQuickLog = true
                    }
                },
                startLiveLog: {
                    showingLogLauncher = false
                    pendingLiveLogSite = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        showingWizard = true
                    }
                },
                onClose: {
                    showingLogLauncher = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .onReceive(NotificationCenter.default.publisher(for: .startLiveLogRequested)) { notification in
            guard let site = notification.object as? DiveSite else { return }
            pendingLiveLogSite = site
            showingWizard = true
        }
        .onChange(of: showingWizard) { isPresented in
            if !isPresented {
                pendingLiveLogSite = nil
            }
        }
    }
}

private extension ContentView {
    var underwaterThemeBinding: Binding<Bool> {
        Binding(
            get: { appState.underwaterThemeEnabled },
            set: { appState.underwaterThemeEnabled = $0 }
        )
    }

    @ViewBuilder var tabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                NewMapView()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Map", systemImage: "map.fill") }
            .tag(Tab.map)

            NavigationStack { DiveHistoryView() }
            .tabItem { Label("History", systemImage: "clock.fill") }
            .tag(Tab.history)

            // Empty placeholder for center FAB
            Text("")
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(Tab.log)

            NavigationStack { WildlifeView() }
            .tabItem { Label("Wildlife", systemImage: "fish.fill") }
            .tag(Tab.wildlife)

            NavigationStack { ProfileView() }
            .tabItem { Label("Profile", systemImage: "person.fill") }
            .tag(Tab.profile)
        }
        .tint(.oceanBlue)
        .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
    }
}

struct LogLauncherView: View {
    let startQuickLog: () -> Void
    let startLiveLog: () -> Void
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Choose how to log") {
                    Button(action: handleQuickLog) {
                        Label("Quick Log", systemImage: "bolt.fill")
                            .font(.body.weight(.semibold))
                    }
                    Button(action: handleLiveLog) {
                        Label("Start Live Log", systemImage: "waveform.path.ecg")
                            .font(.body.weight(.semibold))
                    }
                }
                Section("Tips") {
                    Text("Quick Log saves a dive in under a minute. Live Log tracks depth, time, and reminders during your dive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Log a Dive")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", role: .cancel) { close() }
                }
            }
        }
    }
    
    private func close() {
        dismiss()
        onClose()
    }
    
    private func handleQuickLog() {
        dismiss()
        startQuickLog()
    }
    
    private func handleLiveLog() {
        dismiss()
        startLiveLog()
    }
}

enum Tab: Hashable {
    case map
    case history
    case log  // FAB trigger
    case wildlife
    case profile
}

/// Global app state
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var requiresFaceID: Bool = false
    @Published var underwaterThemeEnabled: Bool {
        didSet {
            guard oldValue != underwaterThemeEnabled else { return }
            defaults.set(underwaterThemeEnabled, forKey: Self.underwaterThemeDefaultsKey)
        }
    }
    @Published var isDatabaseSeeded: Bool = false
    private static let underwaterThemeDefaultsKey = "app.umilog.preferences.underwaterThemeEnabled"
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "app.umilog", category: "AppState")
    private let geofenceManager = GeofenceManager.shared
    private var seedTask: Task<Void, Never>?
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedThemeEnabled = defaults.object(forKey: Self.underwaterThemeDefaultsKey) as? Bool ?? true
        self.underwaterThemeEnabled = storedThemeEnabled
        logger.log("AppState init, underwaterThemeEnabled=\(self.underwaterThemeEnabled, privacy: .public)")

        // Setup notification categories for geofencing
        geofenceManager.setupNotificationCategories()

        // Start geofence monitoring
        geofenceManager.startMonitoring()

        // Seed database with test data on first launch
        seedTask = Task.detached(priority: .background) { [weak self] in
            do {
                try DatabaseSeeder.seedIfNeeded()
                await MainActor.run {
                    self?.logger.log("Seed complete")
                    self?.isDatabaseSeeded = true
                }
            } catch {
                await MainActor.run {
                    self?.logger.error("Seed failed: \(error.localizedDescription, privacy: .public)")
                    self?.isDatabaseSeeded = true
                }
            }
        }
    }
    
    func ensureDatabaseSeeded() async {
        if isDatabaseSeeded {
            return
        }
        
        if let seedTask {
            _ = await seedTask.value
            return
        }
        
        await Task.detached(priority: .background) { [weak self] in
            do {
                try DatabaseSeeder.seedIfNeeded()
                await MainActor.run {
                    self?.logger.log("Seed complete (late ensure)")
                    self?.isDatabaseSeeded = true
                }
            } catch {
                await MainActor.run {
                    self?.logger.error("Seed failed (late ensure): \\(error.localizedDescription, privacy: .public)")
                    self?.isDatabaseSeeded = true
                }
            }
        }.value
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
