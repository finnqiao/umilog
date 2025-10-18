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
                .environment(\.underwaterThemeBinding, $appState.underwaterThemeEnabled)
        }
    }
}

/// Root view with tab navigation (map-first design)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .map
    @State private var showingWizard = false
    
    var body: some View {
        ZStack {
            if appState.underwaterThemeEnabled {
                UnderwaterThemeView { tabs }
                    .wateryTransition()
            } else {
                tabs
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .log {
                Task { @MainActor in
                    showingWizard = true
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    selectedTab = .map
                }
            }
        }
        .sheet(isPresented: $showingWizard) {
            LiveLogWizardView()
                .wateryTransition()
        }
    }
}

private extension ContentView {
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
    @Published var underwaterThemeEnabled: Bool = true
    @Published var useMapLibre: Bool = true  // MapLibre is the default map engine; set false for MapKit fallback
    private let logger = Logger(subsystem: "app.umilog", category: "AppState")
    
    init() {
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
