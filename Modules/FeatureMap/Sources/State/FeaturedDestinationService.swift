import Foundation
import CoreLocation
import os
import UmiDB

private let logger = Logger(subsystem: "app.umilog", category: "FeaturedDestination")

/// Service responsible for featured destination selection and first-launch detection.
/// Provides "inspire my next trip" experience for new users.
@MainActor
public final class FeaturedDestinationService: ObservableObject {
    public static let shared = FeaturedDestinationService()

    private let persistence = MapStatePersistence.shared
    private let geographyRepository: GeographyRepository

    /// The currently selected featured destination (nil if returning user)
    @Published public private(set) var activeDestination: FeaturedDestination?

    /// Whether the featured experience is still active
    @Published public private(set) var isShowingFeatured: Bool = false

    public init(database: AppDatabase = .shared) {
        self.geographyRepository = GeographyRepository(database: database)
    }

    // MARK: - Public Interface

    /// Check if this is a first-time launch and select a featured destination.
    /// Returns the destination to show, or nil for returning users.
    public func checkAndSelectFeatured() -> FeaturedDestination? {
        // Returning users skip featured experience
        guard !persistence.hasLaunchedBefore else {
            return nil
        }

        // Don't show featured if user has saved camera position (they've used the app before)
        // This handles edge case of reinstall with restored data
        if persistence.loadCamera() != nil {
            return nil
        }

        // Select destination based on day of year (deterministic daily rotation)
        let destination = selectDestinationForToday()

        // Validate destination has sites in database
        if let validatedDestination = validateDestination(destination) {
            activeDestination = validatedDestination
            isShowingFeatured = true
            return validatedDestination
        }

        // Fallback: try other destinations
        return selectFallbackDestination()
    }

    /// Mark the featured experience as complete.
    /// Called after user interaction with the map.
    public func completeFeaturedExperience() {
        isShowingFeatured = false
        activeDestination = nil
        persistence.hasLaunchedBefore = true
    }

    /// Dismiss without completing (user can still see it on next cold launch).
    public func dismissTemporarily() {
        isShowingFeatured = false
        activeDestination = nil
    }

    // MARK: - Selection Logic

    private func selectDestinationForToday() -> FeaturedDestination {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % FeaturedDestination.curated.count
        return FeaturedDestination.curated[index]
    }

    private func validateDestination(_ destination: FeaturedDestination) -> FeaturedDestination? {
        // Check if the region exists and has sites in the database
        do {
            if let bounds = try geographyRepository.fetchBounds(regionId: destination.regionId) {
                // Region exists with sites - use database bounds for better centering
                return FeaturedDestination(
                    id: destination.id,
                    regionId: destination.regionId,
                    displayName: destination.displayName,
                    tagline: destination.tagline,
                    latitude: bounds.centerLat,
                    longitude: bounds.centerLon,
                    zoomLevel: destination.zoomLevel
                )
            }
        } catch {
            // Region lookup failed, log and use hardcoded coordinates
            logger.warning("Failed to fetch bounds for \(destination.regionId, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }

        // Fall back to hardcoded coordinates - region might exist with different ID
        return destination
    }

    private func selectFallbackDestination() -> FeaturedDestination? {
        // Try each destination in shuffled order until one works
        for destination in FeaturedDestination.curated.shuffled() {
            if let validated = validateDestination(destination) {
                activeDestination = validated
                isShowingFeatured = true
                return validated
            }
        }

        // Absolute fallback: use first curated destination with hardcoded coords
        let first = FeaturedDestination.curated[0]
        activeDestination = first
        isShowingFeatured = true
        return first
    }
}
