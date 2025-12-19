import Foundation
import UmiDB

/// State for the proximity-triggered log prompt overlay.
/// This appears when the user enters a dive site's geofence.
struct ProximityPromptState: Equatable {
    /// The dive site the user is near.
    let site: DiveSite

    /// When the user entered the geofence.
    let enteredAt: Date

    /// Whether the user has dismissed this prompt.
    var isDismissed: Bool = false

    init(site: DiveSite, enteredAt: Date = Date(), isDismissed: Bool = false) {
        self.site = site
        self.enteredAt = enteredAt
        self.isDismissed = isDismissed
    }
}
