import Foundation
import os

/// Centralized logging for UmiLog app
/// Usage: Log.database.info("Message here")
public enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.umilog"

    /// Database operations (GRDB, seeding, migrations)
    public static let database = Logger(subsystem: subsystem, category: "Database")

    /// Map and location services
    public static let map = Logger(subsystem: subsystem, category: "Map")

    /// Dive logging and live log operations
    public static let diveLog = Logger(subsystem: subsystem, category: "DiveLog")

    /// Wildlife and species tracking
    public static let wildlife = Logger(subsystem: subsystem, category: "Wildlife")

    /// Settings and user preferences
    public static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// Location and geofencing
    public static let location = Logger(subsystem: subsystem, category: "Location")

    /// General app lifecycle and UI events
    public static let app = Logger(subsystem: subsystem, category: "App")

    /// Network and sync operations
    public static let network = Logger(subsystem: subsystem, category: "Network")

    /// Image loading and caching
    public static let images = Logger(subsystem: subsystem, category: "Images")
}
