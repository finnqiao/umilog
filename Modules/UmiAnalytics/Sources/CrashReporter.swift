import Foundation
import Sentry
import os

private let logger = Logger(subsystem: "app.umilog", category: "CrashReporter")

/// Manages crash reporting and error tracking via Sentry
public enum CrashReporter {

    /// Whether crash reporting is enabled
    public private(set) static var isEnabled = false

    /// Initialize Sentry with the provided DSN
    /// - Parameter dsn: Sentry DSN from your project settings. Pass nil to disable.
    public static func start(dsn: String? = nil) {
        // Check for DSN from environment or parameter
        let sentryDSN = dsn ?? ProcessInfo.processInfo.environment["SENTRY_DSN"]

        guard let dsn = sentryDSN, !dsn.isEmpty else {
            logger.info("Sentry DSN not configured, crash reporting disabled")
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn

            // Privacy: Don't send PII
            options.beforeSend = { event in
                event.user = nil
                return event
            }

            // Performance
            options.tracesSampleRate = 0.1  // 10% of transactions
            options.profilesSampleRate = 0.1

            // Session tracking
            options.enableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30000  // 30 seconds

            // Crash handling
            options.attachStacktrace = true
            options.enableCaptureFailedRequests = false  // Privacy

            // Debug (only in DEBUG builds)
            #if DEBUG
            options.debug = true
            #endif

            // App context
            options.environment = {
                #if DEBUG
                return "development"
                #else
                return "production"
                #endif
            }()
        }

        isEnabled = true
        logger.info("Sentry crash reporting initialized")
    }

    /// Add a breadcrumb for debugging context
    public static func addBreadcrumb(
        category: String,
        message: String,
        level: SentryLevel = .info,
        data: [String: Any]? = nil
    ) {
        guard isEnabled else { return }

        let crumb = Breadcrumb()
        crumb.category = category
        crumb.message = message
        crumb.level = level
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb)
    }

    /// Capture a non-fatal error
    public static func captureError(_ error: Error, context: [String: Any]? = nil) {
        guard isEnabled else {
            logger.error("Error (not sent - Sentry disabled): \(error.localizedDescription)")
            return
        }

        SentrySDK.capture(error: error) { scope in
            if let context = context {
                scope.setContext(value: context, key: "custom")
            }
        }
    }

    /// Capture a message for debugging
    public static func captureMessage(_ message: String, level: SentryLevel = .info) {
        guard isEnabled else { return }
        SentrySDK.capture(message: message)
    }
}
