import Foundation

public extension Notification.Name {
    // Namespaced to prevent cross-app notification conflicts
    static let diveLogUpdated = Notification.Name("app.umilog.diveLogUpdated")
    static let wishlistUpdated = Notification.Name("app.umilog.wishlistUpdated")
    static let startLiveLogRequested = Notification.Name("app.umilog.startLiveLogRequested")
    static let tabBarVisibilityShouldChange = Notification.Name("app.umilog.tabBarVisibilityShouldChange")
    static let diveLogSavedSuccessfully = Notification.Name("app.umilog.diveLogSavedSuccessfully")
    static let showLogLauncher = Notification.Name("app.umilog.showLogLauncher")  // Fix UX-013: CTA for empty states
}
