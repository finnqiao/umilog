import Foundation
import Sentry
import os

private let logger = Logger(subsystem: "app.umilog", category: "Analytics")

/// Service for tracking user analytics events
public enum AnalyticsService {

    /// Track an analytics event
    /// Events are added as Sentry breadcrumbs for debugging context
    public static func track(_ event: AnalyticsEvent) {
        // Log in debug builds
        #if DEBUG
        logger.debug("[\(event.name)] \(event.properties)")
        #endif

        // Add as Sentry breadcrumb for crash context
        CrashReporter.addBreadcrumb(
            category: "analytics",
            message: event.name,
            level: .info,
            data: event.properties
        )
    }

    /// Track app launch
    public static func trackAppLaunch(isFirstLaunch: Bool) {
        track(.appLaunched(firstLaunch: isFirstLaunch))
    }

    /// Track dive logged
    public static func trackDiveLogged(type: AnalyticsEvent.LogType, hasSite: Bool) {
        track(.diveLogged(logType: type, hasSite: hasSite))
    }

    /// Track site viewed
    public static func trackSiteViewed(siteId: String, fromSearch: Bool = false) {
        track(.siteViewed(siteId: siteId, fromSearch: fromSearch))
    }

    /// Track site saved
    public static func trackSiteSaved(siteId: String, action: AnalyticsEvent.SaveAction) {
        track(.siteSaved(siteId: siteId, action: action))
    }
}
