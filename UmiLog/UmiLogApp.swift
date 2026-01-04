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
import UmiAnalytics
import UmiCoreKit
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
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedTab") private var selectedTabRaw: String = Tab.map.rawValue
    @State private var showingWizard = false

    /// Computed binding for tab selection with persistence
    private var selectedTab: Binding<Tab> {
        Binding(
            get: { Tab(rawValue: selectedTabRaw) ?? .map },
            set: { selectedTabRaw = $0.rawValue }
        )
    }
    @State private var showingQuickLog = false
    @State private var showingLogLauncher = false
    @State private var pendingLiveLogSite: DiveSite?
    @State private var isTabBarHidden = false

    var body: some View {
        ZStack {
            if appState.isDatabaseSeeded {
                if appState.underwaterThemeEnabled {
                    UnderwaterThemeView { tabs }
                        .wateryTransition()
                } else {
                    tabs
                }
            } else {
                // Show loading state while database seeds
                seedingLoadingView
                    .transition(.opacity)
            }

            // Lock screen overlay
            if appState.isLockEnabled && !appState.isUnlocked {
                lockScreenView
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.isDatabaseSeeded)
        .animation(.easeOut(duration: 0.2), value: appState.isUnlocked)
        .environment(\.underwaterThemeBinding, underwaterThemeBinding)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tabBarVisibilityShouldChange)) { notification in
            guard let hidden = notification.userInfo?["hidden"] as? Bool else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isTabBarHidden = hidden
            }
        }
        .onChange(of: selectedTab.wrappedValue) { oldTab, newTab in
            // Reset tab bar visibility when switching tabs (fix for UX-008)
            // Always reset, not just when hidden, to fix potential state desync
            withAnimation(.easeInOut(duration: 0.15)) {
                isTabBarHidden = false
            }
            if newTab == .log {
                selectedTab.wrappedValue = .map
                showingLogLauncher = true
            }
        }
        .task(id: appState.isDatabaseSeeded) {
            // Initialize geofencing after database is seeded (deferred to avoid white screen)
            if appState.isDatabaseSeeded {
                appState.initializeGeofencing()
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
        .onReceive(NotificationCenter.default.publisher(for: .diveLogSavedSuccessfully)) { _ in
            // Navigate to History tab after successful save
            withAnimation {
                selectedTab.wrappedValue = .history
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showLogLauncher)) { _ in
            // Fix UX-013: Show log launcher from empty state CTAs
            showingLogLauncher = true
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

    /// Loading view shown while database is seeding
    var seedingLoadingView: some View {
        ZStack {
            LinearGradient(colors: [.oceanBlue, .diveTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "water.waves")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse.byLayer, options: .repeating)

                Text("UmiLog")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text("Loading dive sites...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    /// Lock screen shown when app lock is enabled
    var lockScreenView: some View {
        ZStack {
            LinearGradient(colors: [.oceanBlue, .diveTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)

                Text("UmiLog is Locked")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Button {
                    Task {
                        await appState.unlockApp()
                    }
                } label: {
                    HStack {
                        Image(systemName: "faceid")
                        Text("Unlock with Face ID")
                    }
                    .font(.headline)
                    .foregroundStyle(Color.oceanBlue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.white)
                    .cornerRadius(12)
                }
            }
        }
    }

    /// Handle scene phase changes for app lock
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock the app when going to background
            appState.lockApp()
        case .active:
            // Attempt to unlock when becoming active (if locked)
            if appState.isLockEnabled && !appState.isUnlocked {
                Task {
                    await appState.unlockApp()
                }
            }
        case .inactive:
            // No action needed for inactive state
            break
        @unknown default:
            break
        }
    }

    @ViewBuilder var tabs: some View {
        TabView(selection: selectedTab) {
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

enum Tab: String, Hashable {
    case map
    case history
    case log  // FAB trigger
    case wildlife
    case profile
}

/// Global app state
@MainActor
class AppState: ObservableObject {
    /// Whether the app is currently unlocked (used for Face ID lock)
    @Published var isUnlocked: Bool = true
    /// Whether Face ID lock is enabled (loaded from Keychain)
    @Published var isLockEnabled: Bool = false
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
    
    /// Whether geofencing has been initialized (deferred to avoid blocking launch)
    private(set) var geofencingInitialized = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedThemeEnabled = defaults.object(forKey: Self.underwaterThemeDefaultsKey) as? Bool ?? true
        self.underwaterThemeEnabled = storedThemeEnabled
        logger.log("AppState init, underwaterThemeEnabled=\(self.underwaterThemeEnabled, privacy: .public)")

        // Load lock preference from Keychain
        Task {
            let lockEnabled = await AppLockService.shared.isLockEnabled()
            await MainActor.run {
                self.isLockEnabled = lockEnabled
                // If lock is enabled, start locked
                if lockEnabled {
                    self.isUnlocked = false
                }
            }
            self.logger.log("App lock enabled=\(lockEnabled, privacy: .public)")
        }

        // NOTE: Crash reporting and analytics deferred to after first frame for faster cold start
        // NOTE: Geofence setup moved to initializeGeofencing() to avoid blocking launch UI

        // Seed database with test data on first launch
        // Start seeding immediately - the loading view will be shown by SwiftUI
        seedTask = Task { [weak self] in
            // CRITICAL: Yield to allow SwiftUI to render the loading view first
            // This prevents the white screen on cold launch (UX-001)
            await Task.yield()
            try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame at 60fps

            let startTime = Date()

            await Task.detached(priority: .userInitiated) {
                do {
                    try DatabaseSeeder.seedIfNeeded()
                } catch {
                    await MainActor.run {
                        self?.logger.error("Seed failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }.value

            // Ensure minimum splash duration for smooth UX (prevents flash)
            let elapsed = Date().timeIntervalSince(startTime)
            let minimumDuration: TimeInterval = 0.8  // 800ms minimum
            if elapsed < minimumDuration {
                try? await Task.sleep(nanoseconds: UInt64((minimumDuration - elapsed) * 1_000_000_000))
            }

            await MainActor.run { [defaults] in
                self?.logger.log("Seed complete, transitioning to main app")

                // Initialize crash reporting after first frame (deferred for faster cold start)
                CrashReporter.start()

                // Track app launch after first frame
                let isFirstLaunch = !defaults.bool(forKey: "app.umilog.hasLaunchedBefore")
                if isFirstLaunch {
                    defaults.set(true, forKey: "app.umilog.hasLaunchedBefore")
                }
                AnalyticsService.trackAppLaunch(isFirstLaunch: isFirstLaunch)

                withAnimation(.easeOut(duration: 0.3)) {
                    self?.isDatabaseSeeded = true
                }
            }
        }
    }
    
    /// Initialize geofencing after the UI is ready (deferred from init to avoid blocking launch)
    func initializeGeofencing() {
        guard !geofencingInitialized else { return }
        geofencingInitialized = true
        logger.log("Initializing geofencing...")
        geofenceManager.setupNotificationCategories()
        geofenceManager.startMonitoring()
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

    // MARK: - App Lock

    /// Lock the app (called when going to background)
    func lockApp() {
        guard isLockEnabled else { return }
        isUnlocked = false
        logger.log("App locked")
    }

    /// Attempt to unlock the app with biometrics
    func unlockApp() async {
        guard !isUnlocked else { return }

        let success = await AppLockService.shared.authenticate(reason: "Unlock UmiLog to access your dive logs")
        await MainActor.run {
            if success {
                self.isUnlocked = true
                self.logger.log("App unlocked")
            }
        }
    }

    /// Toggle the app lock setting
    func toggleLock(enabled: Bool) async {
        if enabled {
            // Verify with biometrics before enabling
            let success = await AppLockService.shared.authenticate(reason: "Enable Face ID Lock")
            if success {
                await AppLockService.shared.setLockEnabled(true)
                await MainActor.run {
                    self.isLockEnabled = true
                    self.logger.log("App lock enabled")
                }
            }
        } else {
            await AppLockService.shared.setLockEnabled(false)
            await MainActor.run {
                self.isLockEnabled = false
                self.isUnlocked = true
                self.logger.log("App lock disabled")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
