import Foundation
import SwiftUI
import UIKit
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
import UmiCloudKit
import FeatureOnboarding
import os

@main
struct UmiLogApp: App {
    @StateObject private var appState = AppState()

    init() {
        Self.configureTabBarAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(Color.glass).withAlphaComponent(0.85)
        appearance.shadowColor = .clear

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.umiMist
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.umiMist]
        itemAppearance.selected.iconColor = UIColor.umiLagoon
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.umiLagoon]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.isTranslucent = true
    }
}

/// Root view with tab navigation (map-first design)
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedTab") private var selectedTabRaw: String = Tab.map.rawValue
    @State private var showingWizard = false
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared

    // Deep link navigation state
    @State private var pendingDiveId: String?
    @State private var pendingSiteId: String?
    @State private var pendingSpeciesId: String?

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
                if appState.onboardingCompleted {
                    if appState.underwaterThemeEnabled {
                        UnderwaterThemeView { tabs }
                            .wateryTransition()
                    } else {
                        tabs
                    }
                } else {
                    OnboardingWizardView {
                        appState.completeOnboarding()
                    }
                    .transition(.opacity)
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
        .task(id: "\(appState.isDatabaseSeeded)-\(appState.onboardingCompleted)-\(appState.launchSafeModeEnabled)") {
            if appState.isDatabaseSeeded && appState.onboardingCompleted {
                appState.scheduleLaunchStabilityCheckpoint()
                if !appState.launchSafeModeEnabled {
                    // Initialize geofencing once startup seeding is complete and onboarding is finished.
                    // This keeps first-run transition to map responsive.
                    appState.initializeGeofencing()
                }
            } else {
                appState.cancelLaunchStabilityCheckpoint()
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
        .onReceive(NotificationCenter.default.publisher(for: .mapDidBecomeInteractive)) { _ in
            appState.markMapInteractive()
        }
        .onChange(of: showingWizard) { _, isPresented in
            if !isPresented {
                pendingLiveLogSite = nil
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onChange(of: deepLinkRouter.pendingDestination) { _, destination in
            handlePendingDestination(destination)
        }
        .preferredColorScheme(appState.underwaterThemeEnabled ? .dark : nil)
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        deepLinkRouter.handle(url)
    }

    private func handlePendingDestination(_ destination: DeepLinkDestination?) {
        guard let destination else { return }

        switch destination {
        case .tab(let tab):
            withAnimation {
                selectedTab.wrappedValue = tab
            }
            deepLinkRouter.clearPendingDestination()

        case .dive(let id):
            pendingDiveId = id
            withAnimation {
                selectedTab.wrappedValue = .history
            }
            deepLinkRouter.clearPendingDestination()

        case .site(let id):
            pendingSiteId = id
            withAnimation {
                selectedTab.wrappedValue = .map
            }
            deepLinkRouter.clearPendingDestination()

        case .species(let id):
            pendingSpeciesId = id
            withAnimation {
                selectedTab.wrappedValue = .wildlife
            }
            deepLinkRouter.clearPendingDestination()

        case .logLauncher:
            showingLogLauncher = true
            deepLinkRouter.clearPendingDestination()
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

    /// Handle scene phase changes for app lock and sync
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock the app when going to background
            appState.lockApp()
            appState.cancelLaunchStabilityCheckpoint()
        case .active:
            // Attempt to unlock when becoming active (if locked)
            if appState.isLockEnabled && !appState.isUnlocked {
                Task {
                    await appState.unlockApp()
                }
            }
            // Trigger CloudKit sync on app foreground
            appState.syncIfNeeded()
            if appState.isDatabaseSeeded && appState.onboardingCompleted {
                appState.scheduleLaunchStabilityCheckpoint()
            }
        case .inactive:
            appState.cancelLaunchStabilityCheckpoint()
        @unknown default:
            break
        }
    }

    @ViewBuilder var tabs: some View {
        VStack(spacing: 0) {
            // Offline banner
            if !networkMonitor.isConnected {
                OfflineBanner()
                    .animation(.spring(response: 0.3), value: networkMonitor.isConnected)
            }

            TabView(selection: selectedTab) {
                NavigationStack {
                    NewMapView()
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(Tab.map)
                .accessibilityLabel("Map")
                .accessibilityHint("Explore dive sites on the map")

                NavigationStack { DiveHistoryView() }
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(Tab.history)
                .accessibilityLabel("History")
                .accessibilityHint("View your dive log history")

                // Empty placeholder for center FAB
                Text("")
                    .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                    .tag(Tab.log)
                    .accessibilityLabel("Log a dive")
                    .accessibilityHint("Start logging a new dive")

                NavigationStack { WildlifeView() }
                .tabItem { Label("Wildlife", systemImage: "fish.fill") }
                .tag(Tab.wildlife)
                .accessibilityLabel("Wildlife")
                .accessibilityHint("View marine species catalog")

                NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(Tab.profile)
                .accessibilityLabel("Profile")
                .accessibilityHint("View your profile and settings")
            }
            .tint(.oceanBlue)
            .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
        }
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

private enum LaunchCheckpoint: String {
    case boot
    case databaseReady
    case onboardingComplete
    case mapInteractive
    case stable

    var rank: Int {
        switch self {
        case .boot: return 0
        case .databaseReady: return 1
        case .onboardingComplete: return 2
        case .mapInteractive: return 3
        case .stable: return 4
        }
    }
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
    @Published var onboardingCompleted: Bool = false
    @Published private(set) var launchSafeModeEnabled: Bool = false
    @Published private(set) var launchCrashLoopCount: Int = 0

    /// CloudKit sync service - initialized after database is ready
    @Published private(set) var cloudSyncService: CloudSyncService?

    private static let underwaterThemeDefaultsKey = AppConstants.UserDefaultsKeys.underwaterThemeEnabled
    private static let onboardingCompletedKey = "app.umilog.onboardingCompleted"
    private let defaults: UserDefaults
    private let launchArguments: [String]
    private let forceSafeModeForSession: Bool
    private let disableSafeModeAutoRecovery: Bool
    private let logger = Logger(subsystem: "app.umilog", category: "AppState")
    private lazy var geofenceManager = GeofenceManager.shared
    private var seedTask: Task<Void, Never>?
    private var stabilityCheckpointTask: Task<Void, Never>?
    private var memoryWarningObserver: NSObjectProtocol?
    private var thermalStateObserver: NSObjectProtocol?
    private var safeModeActivationObserver: NSObjectProtocol?
    
    /// Whether geofencing has been initialized (deferred to avoid blocking launch)
    private(set) var geofencingInitialized = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let arguments = ProcessInfo.processInfo.arguments
        self.launchArguments = arguments
        self.forceSafeModeForSession = arguments.contains("-ForceLaunchSafeMode")
        self.disableSafeModeAutoRecovery = arguments.contains("-DisableLaunchSafeModeRecovery")
        let storedThemeEnabled = defaults.object(forKey: Self.underwaterThemeDefaultsKey) as? Bool ?? true
        self.underwaterThemeEnabled = storedThemeEnabled

        // Skip onboarding for UI tests if launch argument is present
        if arguments.contains("-SkipOnboarding") {
            self.onboardingCompleted = true
        } else {
            self.onboardingCompleted = defaults.bool(forKey: Self.onboardingCompletedKey)
        }
        beginLaunchSession()
        if onboardingCompleted {
            markLaunchCheckpoint(.onboardingComplete)
        }
        logger.log("AppState init, underwaterThemeEnabled=\(self.underwaterThemeEnabled, privacy: .public), onboardingCompleted=\(self.onboardingCompleted, privacy: .public)")
        setupRuntimeCircuitBreakers()

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

            // Initialize database first
            do {
                try AppDatabase.initialize()
            } catch {
                self?.logger.error("Database initialization failed: \(error.localizedDescription, privacy: .public)")
                // Continue to show error state - the app will show the loading view indefinitely
                // which is better than crashing
                return
            }

            await Task.detached(priority: .userInitiated) {
                do {
                    try DatabaseSeeder.seedCriticalDataIfNeeded()
                } catch {
                    await MainActor.run {
                        self?.logger.error("Seed failed: \(error.localizedDescription, privacy: .public)")
                    }
                }
            }.value

            // Ensure minimum splash duration for smooth UX (prevents flash)
            let elapsed = Date().timeIntervalSince(startTime)
            let minimumDuration = AppConstants.Timing.minimumSplashDuration
            if elapsed < minimumDuration {
                try? await Task.sleep(nanoseconds: UInt64((minimumDuration - elapsed) * 1_000_000_000))
            }

            await MainActor.run { [defaults] in
                self?.logger.log("Seed complete, transitioning to main app")

                // Initialize crash reporting after first frame (deferred for faster cold start)
                CrashReporter.start()

                // Track app launch after first frame
                let isFirstLaunch = !defaults.bool(forKey: AppConstants.UserDefaultsKeys.hasLaunchedBefore)
                if isFirstLaunch {
                    defaults.set(true, forKey: AppConstants.UserDefaultsKeys.hasLaunchedBefore)
                }
                AnalyticsService.trackAppLaunch(isFirstLaunch: isFirstLaunch)

                self?.markLaunchCheckpoint(.databaseReady)

                // Initialize CloudKit sync after database is ready (unless safe mode is active)
                if self?.launchSafeModeEnabled == true {
                    self?.logger.log("Launch safe mode active - deferring CloudKit startup")
                } else {
                    self?.initializeCloudSync()
                }

                withAnimation(.easeOut(duration: 0.3)) {
                    self?.isDatabaseSeeded = true
                }
            }

            let shouldSkipBackgroundRefresh = await MainActor.run {
                self?.launchSafeModeEnabled ?? false
            }
            if shouldSkipBackgroundRefresh {
                await MainActor.run {
                    self?.logger.log("Launch safe mode active - skipping background seed refresh")
                }
            } else {
                Task { [weak self] in
                    let refreshResult = await Task.detached(priority: .utility) {
                        Result { try DatabaseSeeder.seedOrRefreshIfNeeded() }
                    }.value

                    await MainActor.run {
                        switch refreshResult {
                        case .success:
                            NotificationCenter.default.post(name: .seedDataDidRefresh, object: nil)
                            self?.logger.log("Background seed refresh complete")
                        case .failure(let error):
                            self?.logger.error("Background seed refresh failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            }
        }
    }

    deinit {
        if let memoryWarningObserver {
            NotificationCenter.default.removeObserver(memoryWarningObserver)
        }
        if let thermalStateObserver {
            NotificationCenter.default.removeObserver(thermalStateObserver)
        }
        if let safeModeActivationObserver {
            NotificationCenter.default.removeObserver(safeModeActivationObserver)
        }
    }
    
    /// Initialize geofencing after the UI is ready (deferred from init to avoid blocking launch)
    func initializeGeofencing() {
        guard !geofencingInitialized else { return }
        guard !launchSafeModeEnabled else {
            logger.log("Skipping geofencing in launch safe mode")
            return
        }
        geofencingInitialized = true
        logger.log("Initializing geofencing...")
        geofenceManager.setupNotificationCategories()
        geofenceManager.startMonitoring()
    }

    /// Initialize CloudKit sync after database is ready
    func initializeCloudSync() {
        guard cloudSyncService == nil else { return }
        guard !launchSafeModeEnabled else {
            logger.log("Skipping CloudKit sync initialization in launch safe mode")
            return
        }
        do {
            cloudSyncService = try CloudSyncService()
            logger.log("CloudKit sync service initialized")
            // Initialize async (subscribe to changes, setup zone)
            Task {
                await cloudSyncService?.initialize()
            }
        } catch {
            logger.error("Failed to initialize CloudKit sync: \(error.localizedDescription)")
        }
    }

    /// Trigger a sync operation (call on app foreground)
    func syncIfNeeded() {
        guard !launchSafeModeEnabled else { return }
        guard let syncService = cloudSyncService else { return }
        Task {
            await syncService.sync()
        }
    }

    private func setupRuntimeCircuitBreakers() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.activateLaunchSafeMode(reason: "memory_warning")
            }
        }

        thermalStateObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let thermalState = ProcessInfo.processInfo.thermalState
                switch thermalState {
                case .serious:
                    self.activateLaunchSafeMode(reason: "thermal_serious")
                case .critical:
                    self.activateLaunchSafeMode(reason: "thermal_critical")
                default:
                    break
                }
            }
        }

        safeModeActivationObserver = NotificationCenter.default.addObserver(
            forName: .launchSafeModeActivationRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?["reason"] as? String ?? "external_request"
            Task { @MainActor in
                self?.activateLaunchSafeMode(reason: reason)
            }
        }
    }

    private func launchArgumentValue(after flag: String) -> String? {
        guard let index = launchArguments.firstIndex(of: flag) else { return nil }
        let valueIndex = launchArguments.index(after: index)
        guard launchArguments.indices.contains(valueIndex) else { return nil }
        return launchArguments[valueIndex]
    }

    private func setLaunchSafeModeEnabled(_ enabled: Bool, reason: String, persist: Bool = true) {
        let didChange = launchSafeModeEnabled != enabled
        launchSafeModeEnabled = enabled
        if persist {
            defaults.set(enabled, forKey: AppConstants.UserDefaultsKeys.launchSafeModeEnabled)
        }

        guard didChange else { return }

        if enabled {
            if geofencingInitialized {
                geofenceManager.stopMonitoring()
                geofencingInitialized = false
            }
            cloudSyncService = nil
            logger.error("Launch safe mode enabled, reason=\(reason, privacy: .public)")
        } else {
            logger.log("Launch safe mode disabled, reason=\(reason, privacy: .public)")
        }

        NotificationCenter.default.post(
            name: .launchSafeModeDidChange,
            object: nil,
            userInfo: [
                "enabled": enabled,
                "reason": reason
            ]
        )
    }

    func activateLaunchSafeMode(reason: String) {
        setLaunchSafeModeEnabled(true, reason: reason)
    }

    func markMapInteractive() {
        markLaunchCheckpoint(.mapInteractive)
    }

    func scheduleLaunchStabilityCheckpoint() {
        stabilityCheckpointTask?.cancel()
        stabilityCheckpointTask = Task { [weak self] in
            let delay = AppConstants.Timing.launchStabilityDelay
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.markLaunchCheckpoint(.stable)
            }
        }
    }

    func cancelLaunchStabilityCheckpoint() {
        stabilityCheckpointTask?.cancel()
        stabilityCheckpointTask = nil
    }

    func ensureDatabaseSeeded() async {
        if isDatabaseSeeded {
            return
        }
        
        if let seedTask {
            _ = await seedTask.value
            return
        }
        
        let seedResult = await Task.detached(priority: .background) {
            Result { try DatabaseSeeder.seedCriticalDataIfNeeded() }
        }.value

        switch seedResult {
        case .success:
            logger.log("Seed complete (late ensure)")
            markLaunchCheckpoint(.databaseReady)
            isDatabaseSeeded = true
        case .failure(let error):
            logger.error("Seed failed (late ensure): \(error.localizedDescription, privacy: .public)")
            markLaunchCheckpoint(.databaseReady)
            isDatabaseSeeded = true
        }
    }

    // MARK: - Launch Stability

    private func beginLaunchSession() {
        let isUITest = launchArguments.contains("-UITest")
        let simulatedCrashLoopCount = launchArgumentValue(after: "-SimulateCrashLoopCount").flatMap { Int($0) }

        if isUITest {
            let crashLoopCount = max(0, simulatedCrashLoopCount ?? (forceSafeModeForSession ? AppConstants.LaunchStability.crashLoopSafeModeThreshold : 0))
            launchCrashLoopCount = crashLoopCount
            defaults.set(crashLoopCount, forKey: AppConstants.UserDefaultsKeys.launchCrashLoopCount)

            let shouldEnableSafeMode = forceSafeModeForSession || crashLoopCount >= AppConstants.LaunchStability.crashLoopSafeModeThreshold
            setLaunchSafeModeEnabled(shouldEnableSafeMode, reason: shouldEnableSafeMode ? "ui_test_safe_mode" : "ui_test_reset")

            defaults.set(true, forKey: AppConstants.UserDefaultsKeys.launchInProgress)
            defaults.set(Date().timeIntervalSince1970, forKey: AppConstants.UserDefaultsKeys.launchStartedAt)
            defaults.set(LaunchCheckpoint.boot.rawValue, forKey: AppConstants.UserDefaultsKeys.launchCheckpoint)
            logger.log("Launch stability reset for UI test run (safeMode=\(shouldEnableSafeMode, privacy: .public), crashLoops=\(crashLoopCount, privacy: .public))")
            return
        }

        let previousInProgress = defaults.bool(forKey: AppConstants.UserDefaultsKeys.launchInProgress)
        let previousCheckpoint = storedLaunchCheckpoint()
        var crashLoopCount = defaults.integer(forKey: AppConstants.UserDefaultsKeys.launchCrashLoopCount)

        if let simulatedCrashLoopCount {
            crashLoopCount = max(0, simulatedCrashLoopCount)
            logger.log("Using simulated crash loop count=\(crashLoopCount, privacy: .public)")
        }

        if previousInProgress && previousCheckpoint.rank < LaunchCheckpoint.mapInteractive.rank {
            crashLoopCount += 1
            logger.error("Detected incomplete launch at checkpoint=\(previousCheckpoint.rawValue, privacy: .public), crashLoopCount=\(crashLoopCount, privacy: .public)")
        } else {
            crashLoopCount = 0
        }

        launchCrashLoopCount = crashLoopCount
        defaults.set(crashLoopCount, forKey: AppConstants.UserDefaultsKeys.launchCrashLoopCount)

        let shouldEnableSafeMode = forceSafeModeForSession || crashLoopCount >= AppConstants.LaunchStability.crashLoopSafeModeThreshold
        let safeModeReason = forceSafeModeForSession ? "force_launch_arg" : "crash_loop_threshold"
        setLaunchSafeModeEnabled(shouldEnableSafeMode, reason: shouldEnableSafeMode ? safeModeReason : "normal_launch")

        if shouldEnableSafeMode {
            logger.error("Launch safe mode enabled after \(crashLoopCount, privacy: .public) incomplete launches")
        }

        defaults.set(true, forKey: AppConstants.UserDefaultsKeys.launchInProgress)
        defaults.set(Date().timeIntervalSince1970, forKey: AppConstants.UserDefaultsKeys.launchStartedAt)
        defaults.set(LaunchCheckpoint.boot.rawValue, forKey: AppConstants.UserDefaultsKeys.launchCheckpoint)
    }

    private func storedLaunchCheckpoint() -> LaunchCheckpoint {
        guard let rawValue = defaults.string(forKey: AppConstants.UserDefaultsKeys.launchCheckpoint),
              let checkpoint = LaunchCheckpoint(rawValue: rawValue) else {
            return .boot
        }
        return checkpoint
    }

    private func markLaunchCheckpoint(_ checkpoint: LaunchCheckpoint) {
        let current = storedLaunchCheckpoint()
        guard checkpoint.rank >= current.rank else { return }

        defaults.set(checkpoint.rawValue, forKey: AppConstants.UserDefaultsKeys.launchCheckpoint)
        logger.log("Launch checkpoint=\(checkpoint.rawValue, privacy: .public)")

        if checkpoint == .stable {
            cancelLaunchStabilityCheckpoint()
        }

        if checkpoint.rank >= LaunchCheckpoint.mapInteractive.rank {
            markLaunchAsRecovered(trigger: checkpoint)
        }
    }

    private func markLaunchAsRecovered(trigger: LaunchCheckpoint) {
        defaults.set(false, forKey: AppConstants.UserDefaultsKeys.launchInProgress)
        defaults.set(0, forKey: AppConstants.UserDefaultsKeys.launchCrashLoopCount)
        launchCrashLoopCount = 0

        let shouldKeepSafeMode = forceSafeModeForSession || disableSafeModeAutoRecovery
        if launchSafeModeEnabled && !shouldKeepSafeMode {
            setLaunchSafeModeEnabled(false, reason: "launch_recovered_\(trigger.rawValue)")
            logger.log("Launch recovered at checkpoint=\(trigger.rawValue, privacy: .public); disabling safe mode")
            if isDatabaseSeeded {
                initializeCloudSync()
            }
        } else if launchSafeModeEnabled && shouldKeepSafeMode {
            defaults.set(true, forKey: AppConstants.UserDefaultsKeys.launchSafeModeEnabled)
            logger.log("Launch recovered at checkpoint=\(trigger.rawValue, privacy: .public); keeping safe mode due to launch configuration")
        } else {
            defaults.set(false, forKey: AppConstants.UserDefaultsKeys.launchSafeModeEnabled)
        }
    }

    // MARK: - Onboarding

    /// Mark onboarding as completed
    func completeOnboarding() {
        defaults.set(true, forKey: Self.onboardingCompletedKey)
        withAnimation(.easeOut(duration: 0.3)) {
            onboardingCompleted = true
        }
        markLaunchCheckpoint(.onboardingComplete)
        logger.log("Onboarding completed")
    }

    /// Reset onboarding state (for testing)
    func resetOnboarding() {
        defaults.removeObject(forKey: Self.onboardingCompletedKey)
        onboardingCompleted = false
        logger.log("Onboarding reset")
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
