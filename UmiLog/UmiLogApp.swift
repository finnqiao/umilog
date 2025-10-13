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
import DiveMap

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
        Group {
            if appState.underwaterThemeEnabled {
                UnderwaterThemeView { tabs }
                    .wateryTransition()
            } else {
                tabs
            }
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == .log {
                showingWizard = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { selectedTab = .map }
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
                if appState.useMapLibre {
                    DiveMapView()
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    NewMapView()
                        .navigationBarTitleDisplayMode(.inline)
                }
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
    @Published var useMapLibre: Bool = false
    private let logger = Logger(subsystem: "app.umilog", category: "AppState")
    
    init() {
        // Initialize app state
        logger.log("AppState init, underwaterThemeEnabled=\\(self.underwaterThemeEnabled, privacy: .public)")
        
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
