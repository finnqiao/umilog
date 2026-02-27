import Foundation

/// Centralized timing and configuration constants for the app (TD-002)
public enum AppConstants {
    /// Timing constants for UI animations and delays
    public enum Timing {
        /// Delay before showing permission explainer (allows map to load first)
        public static let permissionExplainerDelay: TimeInterval = 1.5

        /// Minimum duration for splash/loading screen
        public static let minimumSplashDuration: TimeInterval = 0.8

        /// Timeout for database seeding operation
        public static let seedingTimeout: TimeInterval = 30

        /// Grace period before app lock engages after backgrounding
        public static let lockGracePeriod: TimeInterval = 5

        /// Geofence radius for dive site detection (meters)
        public static let geofenceRadius: Double = 500

        /// Distance threshold for nearby sites (kilometers)
        public static let nearbySitesRadius: Double = 50

        /// Notification reminder delay after arriving at site (seconds)
        public static let arrivalReminderDelay: TimeInterval = 900  // 15 minutes

        /// Delay before marking launch as stable (seconds)
        public static let launchStabilityDelay: TimeInterval = 12
    }

    /// Launch stability thresholds and limits
    public enum LaunchStability {
        /// Number of consecutive incomplete launches before enabling safe mode
        public static let crashLoopSafeModeThreshold: Int = 2

        /// Max annotations rendered in normal mode
        public static let mapKitAnnotationLimit: Int = 3_000

        /// Max annotations rendered in safe mode
        public static let mapKitSafeModeAnnotationLimit: Int = 1_000

        /// Upper bound for "expand to all sites" behavior in normal mode
        public static let allSitesExpansionThreshold: Int = 2_500

        /// Upper bound for "expand to all sites" behavior in safe mode
        public static let allSitesExpansionSafeModeThreshold: Int = 800

        /// Initial site payload for map boot in normal mode
        public static let initialSiteLoadLimit: Int = 8_000

        /// Initial site payload for map boot in safe mode
        public static let initialSiteLoadSafeModeLimit: Int = 2_000

        /// Max viewport rows queried in normal mode
        public static let viewportSiteQueryLimit: Int = 4_000

        /// Max viewport rows queried in safe mode
        public static let viewportSiteQuerySafeModeLimit: Int = 1_200

        /// Slow viewport query threshold used by adaptive limit controller
        public static let slowViewportQueryThreshold: TimeInterval = 0.35

        /// Number of repeated slow viewport queries before escalating safe mode
        public static let viewportSlowQueryEscalationThreshold: Int = 4

        /// Number of repeated viewport query failures before escalating safe mode
        public static let viewportFailureEscalationThreshold: Int = 3
    }

    /// UserDefaults keys (namespaced to prevent conflicts)
    public enum UserDefaultsKeys {
        public static let hasLaunchedBefore = "app.umilog.hasLaunchedBefore"
        public static let underwaterThemeEnabled = "app.umilog.preferences.underwaterThemeEnabled"
        public static let boatModeEnabled = "app.umilog.preferences.boatModeEnabled"
        public static let siteArrivalNotificationsEnabled = "app.umilog.preferences.siteArrivalNotificationsEnabled"
        public static let locationPermissionPhase = "app.umilog.locationPermissionPhase"
        public static let hasSeenLocationExplainer = "app.umilog.hasSeenLocationExplainer"
        public static let hasSeenMapCoachMarks = "app.umilog.hasSeenMapCoachMarks"
        public static let launchInProgress = "app.umilog.launch.inProgress"
        public static let launchCheckpoint = "app.umilog.launch.checkpoint"
        public static let launchCrashLoopCount = "app.umilog.launch.crashLoopCount"
        public static let launchSafeModeEnabled = "app.umilog.launch.safeModeEnabled"
        public static let launchStartedAt = "app.umilog.launch.startedAt"
        public static let seedRefreshPipelineVersion = "app.umilog.seedRefresh.pipelineVersion"
        public static let seedRefreshLastStep = "app.umilog.seedRefresh.lastStep"
        public static let seedRefreshLastError = "app.umilog.seedRefresh.lastError"
        public static let seedRefreshLastRunAt = "app.umilog.seedRefresh.lastRunAt"
    }
}
