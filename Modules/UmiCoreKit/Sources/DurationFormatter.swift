import Foundation

/// Centralized duration formatting for consistent time display across the app.
/// Handles both seconds and minutes input with smart formatting.
public enum DurationFormatter {
    /// Format duration in seconds to human-readable string.
    /// - Under 60 minutes: "X min"
    /// - 60+ minutes: "Xh Ym"
    /// - Parameter seconds: Duration in seconds
    /// - Returns: Formatted string
    public static func format(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours == 0 {
            return "\(minutes) min"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }

    /// Format duration in minutes to human-readable string.
    /// - Under 60 minutes: "X min"
    /// - 60+ minutes: "Xh Ym"
    /// - Parameter minutes: Duration in minutes
    /// - Returns: Formatted string
    public static func format(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours == 0 {
            return "\(mins) min"
        } else {
            return "\(hours)h \(mins)m"
        }
    }

    /// Compact format for small UI spaces (no space before unit).
    /// - Under 60 minutes: "Xmin"
    /// - 60+ minutes: "Xh Ym"
    /// - Parameter minutes: Duration in minutes
    /// - Returns: Compact formatted string
    public static func formatCompact(minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60

        if hours == 0 {
            return "\(mins)min"
        } else {
            return "\(hours)h \(mins)m"
        }
    }
}
