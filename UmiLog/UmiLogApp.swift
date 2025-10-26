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
    @State private var showingLogOptions = false
    
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
        .onChange(of: selectedTab) { newTab in
            if newTab == .log {
                selectedTab = .map
                showingLogOptions = true
            }
        }
        .sheet(isPresented: $showingWizard) {
            LiveLogWizardView()
                .wateryTransition()
        }
        .sheet(isPresented: $showingQuickLog) {
            QuickLogView()
                .wateryTransition()
        }
        .confirmationDialog("Log a Dive", isPresented: $showingLogOptions, titleVisibility: .visible) {
            Button("Quick Log") { showingQuickLog = true }
            Button("Start Live Log Wizard") { showingWizard = true }
            Button("Cancel", role: .cancel) { }
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
                NewMapView(useMapLibre: appState.useMapLibre)
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
    @Published var useMapLibre: Bool = true  // MapLibre is the default map engine; set false for MapKit fallback
    private static let underwaterThemeDefaultsKey = "app.umilog.preferences.underwaterThemeEnabled"
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "app.umilog", category: "AppState")
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedThemeEnabled = defaults.object(forKey: Self.underwaterThemeDefaultsKey) as? Bool ?? true
        self.underwaterThemeEnabled = storedThemeEnabled
        // Initialize app state
        logger.log("AppState init, underwaterThemeEnabled=\\(self.underwaterThemeEnabled, privacy: .public), useMapLibre=\\(self.useMapLibre, privacy: .public)")
        
        // Seed database with test data on first launch
        Task {
            do {
                try DatabaseSeeder.seedIfNeeded()
                logger.log("Seed complete")
            } catch {
                logger.error("Seed failed: \\(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
