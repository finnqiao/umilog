import Foundation

/// Centralized filter persistence for History tab.
/// Manages saving and loading of filter state to UserDefaults.
public final class FilterPersistence {
    public static let shared = FilterPersistence()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let historyFilters = "umilog.history.filters"
    }

    private init() {}

    // MARK: - History Filters

    /// Save history filters to UserDefaults.
    public func saveHistoryFilters(_ filters: UnifiedFilters) {
        guard let data = try? JSONEncoder().encode(filters) else {
            Log.settings.error("Failed to encode history filters")
            return
        }
        defaults.set(data, forKey: Keys.historyFilters)
        Log.settings.debug("Saved history filters: \(filters.activeCount) active")
    }

    /// Load history filters from UserDefaults.
    public func loadHistoryFilters() -> UnifiedFilters {
        guard let data = defaults.data(forKey: Keys.historyFilters),
              let filters = try? JSONDecoder().decode(UnifiedFilters.self, from: data) else {
            return .default
        }
        return filters
    }

    /// Clear history filters.
    public func clearHistoryFilters() {
        defaults.removeObject(forKey: Keys.historyFilters)
        Log.settings.debug("Cleared history filters")
    }
}
