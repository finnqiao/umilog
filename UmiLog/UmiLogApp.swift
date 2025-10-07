import SwiftUI
import FeatureHome
import FeatureLiveLog
import FeatureHistory
import FeatureSites
import FeatureSettings
import UmiDesignSystem

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

/// Root view with tab navigation
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(Tab.home)
            
            NavigationStack {
                DiveLoggerView()
            }
            .tabItem {
                Label("Log", systemImage: "plus.circle.fill")
            }
            .tag(Tab.log)
            
            NavigationStack {
                DiveHistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.fill")
            }
            .tag(Tab.history)
            
            NavigationStack {
                SiteExplorerView()
            }
            .tabItem {
                Label("Sites", systemImage: "map.fill")
            }
            .tag(Tab.sites)
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("More", systemImage: "ellipsis.circle.fill")
            }
            .tag(Tab.more)
        }
        .tint(.oceanBlue)
    }
}

enum Tab: Hashable {
    case home
    case log
    case history
    case sites
    case more
}

/// Global app state
@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var requiresFaceID: Bool = false
    
    init() {
        // Initialize app state
        // TODO: Check authentication status
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
