import SwiftUI
import FeatureMap
import FeatureHome
import FeatureLiveLog
import FeatureHistory
import FeatureSites
import FeatureSettings
import UmiDesignSystem
import UmiDB

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
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    NewMapView()
                }
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(Tab.map)
                
                NavigationStack {
                    DiveHistoryView()
                }
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(Tab.history)
                
                // Empty placeholder for center FAB
                Text("")
                    .tabItem {
                        Label("Log", systemImage: "plus.circle.fill")
                    }
                    .tag(Tab.log)
                
                NavigationStack {
                    WildlifeView()
                }
                .tabItem {
                    Label("Wildlife", systemImage: "fish.fill")
                }
                .tag(Tab.wildlife)
                
                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
            }
            .tint(.oceanBlue)
            .onChange(of: selectedTab) { newTab in
                if newTab == .log {
                    showingWizard = true
                    // Revert to previous tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedTab = .map
                    }
                }
            }
        }
        .sheet(isPresented: $showingWizard) {
            LiveLogWizardView()
        }
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
    
    init() {
        // Initialize app state
        // TODO: Check authentication status
        
        // Seed database with test data on first launch
        Task {
            do {
                try DatabaseSeeder.seedIfNeeded()
            } catch {
                print("❌ Failed to seed database: \(error)")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
