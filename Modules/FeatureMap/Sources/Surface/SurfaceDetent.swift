import SwiftUI

/// Detent positions for the unified bottom surface.
enum SurfaceDetent: Equatable, CaseIterable {
    /// Hidden - ultra-minimal mode with no bottom sheet visible.
    case hidden

    /// Minimal peek showing summary info (~15% or 132pt min).
    case peek

    /// Medium height showing list content (~60%).
    case medium

    /// Fully expanded (~full height - 44pt for status bar).
    case expanded

    /// Calculate the height for this detent given a container height.
    func height(in containerHeight: CGFloat) -> CGFloat {
        switch self {
        case .hidden:
            return 0
        case .peek:
            // 132pt min: drag handle (29pt) + header row (~60pt) + vertical padding (~43pt).
            // Peek shows only the area summary — no carousel. Cards appear at .medium.
            // 15% keeps it compact on larger screens while ensuring the summary fits.
            return max(containerHeight * 0.15, 132)
        case .medium:
            return containerHeight * 0.60
        case .expanded:
            return containerHeight - 44
        }
    }

    /// Get the allowed detents for a given UI mode.
    static func allowed(for mode: MapUIMode) -> [SurfaceDetent] {
        switch mode {
        case .explore:
            return [.peek, .medium, .expanded]
        case .inspectSite:
            return [.medium, .expanded]
        case .filter, .search:
            return [.expanded]
        case .plan:
            return [.medium, .expanded]
        case .clusterExpand:
            return [.peek, .medium, .expanded]
        case .nearMe:
            return [.peek, .medium, .expanded]
        }
    }

    /// Get the default detent for a given UI mode.
    static func defaultDetent(for mode: MapUIMode) -> SurfaceDetent {
        switch mode {
        case .explore:
            return .peek
        case .inspectSite:
            return .medium
        case .filter, .search:
            return .expanded
        case .plan:
            return .expanded
        case .clusterExpand:
            return .medium
        case .nearMe:
            return .medium
        }
    }

    /// Find the nearest allowed detent to the current position.
    static func nearest(
        to height: CGFloat,
        in containerHeight: CGFloat,
        allowed: [SurfaceDetent]
    ) -> SurfaceDetent {
        guard !allowed.isEmpty else { return .peek }

        var nearest = allowed[0]
        var nearestDistance = abs(height - allowed[0].height(in: containerHeight))

        for detent in allowed.dropFirst() {
            let distance = abs(height - detent.height(in: containerHeight))
            if distance < nearestDistance {
                nearest = detent
                nearestDistance = distance
            }
        }

        return nearest
    }
}
