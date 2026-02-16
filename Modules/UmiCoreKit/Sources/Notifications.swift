import Foundation

public extension Notification.Name {
    // Namespaced to prevent cross-app notification conflicts
    static let diveLogUpdated = Notification.Name("app.umilog.diveLogUpdated")
    static let wishlistUpdated = Notification.Name("app.umilog.wishlistUpdated")
    static let startLiveLogRequested = Notification.Name("app.umilog.startLiveLogRequested")
    static let tabBarVisibilityShouldChange = Notification.Name("app.umilog.tabBarVisibilityShouldChange")
    static let diveLogSavedSuccessfully = Notification.Name("app.umilog.diveLogSavedSuccessfully")
    static let showLogLauncher = Notification.Name("app.umilog.showLogLauncher")  // Fix UX-013: CTA for empty states
    static let networkStatusChanged = Notification.Name("app.umilog.networkStatusChanged")
    static let seedDataDidRefresh = Notification.Name("app.umilog.seedDataDidRefresh")
    static let mapDidBecomeInteractive = Notification.Name("app.umilog.mapDidBecomeInteractive")
    static let launchSafeModeDidChange = Notification.Name("app.umilog.launchSafeModeDidChange")
    static let launchSafeModeActivationRequested = Notification.Name("app.umilog.launchSafeModeActivationRequested")
}
