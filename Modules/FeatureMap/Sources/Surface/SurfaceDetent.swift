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
    ///
    /// `containerHeight` should be the *effective* usable height — i.e. the raw
    /// geometry height already reduced by the tab bar height so the expanded sheet
    /// never extends into the tab bar area. `UnifiedBottomSurface` handles this
    /// reduction before calling here.
    func height(in containerHeight: CGFloat) -> CGFloat {
        switch self {
        case .hidden:
            return 0
        case .peek:
            // Fixed 128pt: drag handle (29pt) + title row (~20pt) + subtitle (~14pt)
            // + vertical padding (~40pt) + 25pt breathing room. Compact summary tray —
            // no carousel, no chips. Content-driven so it feels identical on every device.
            return 128
        case .medium:
            // Cards-first browse state. Content budget: handle (29) + top pad (4) +
            // header (~20) + gap (12) + carousel (~82) + bottom (16) ≈ 163pt.
            // Clamp to 252–288pt so there is comfortable breathing room without dead air.
            return min(max(containerHeight * 0.36, 252), 288)
        case .expanded:
            // Take almost the full usable height, leaving 44pt at the top for the
            // status-bar area. containerHeight has already had tabBarHeight subtracted
            // by the caller, so the sheet bottom sits flush against the tab bar top.
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
