import SwiftUI

/// Helper utilities for surface drag gestures.
enum SurfaceGestures {
    /// Rubber band resistance factor when dragging beyond bounds.
    private static let rubberBandFactor: CGFloat = 0.3

    /// Velocity threshold for flick gesture (points per second).
    private static let flickVelocityThreshold: CGFloat = 500

    /// Determine the final detent after a drag gesture ends.
    /// - Parameters:
    ///   - translation: The drag translation (negative = up, positive = down)
    ///   - velocity: The drag velocity (negative = up, positive = down)
    ///   - containerHeight: The container height for calculating detent heights
    ///   - currentDetent: The detent before dragging
    ///   - allowedDetents: The detents allowed for the current mode
    /// - Returns: The detent to snap to
    static func finalizeDrag(
        translation: CGFloat,
        velocity: CGFloat,
        containerHeight: CGFloat,
        currentDetent: SurfaceDetent,
        allowedDetents: [SurfaceDetent]
    ) -> SurfaceDetent {
        guard !allowedDetents.isEmpty else { return currentDetent }

        let baseHeight = currentDetent.height(in: containerHeight)
        // Translation is negative when dragging up (increasing height)
        let projectedHeight = baseHeight - translation

        // Check for flick gesture
        if abs(velocity) > flickVelocityThreshold {
            // Flicking up (negative velocity) -> go to next higher detent
            // Flicking down (positive velocity) -> go to next lower detent
            if velocity < 0 {
                // Flick up - find next higher detent
                return nextHigherDetent(
                    from: currentDetent,
                    in: allowedDetents,
                    containerHeight: containerHeight
                )
            } else {
                // Flick down - find next lower detent
                return nextLowerDetent(
                    from: currentDetent,
                    in: allowedDetents,
                    containerHeight: containerHeight
                )
            }
        }

        // No flick - snap to nearest detent
        return SurfaceDetent.nearest(
            to: projectedHeight,
            in: containerHeight,
            allowed: allowedDetents
        )
    }

    /// Calculate the rubber band offset when dragging beyond bounds.
    /// - Parameters:
    ///   - translation: The raw drag translation
    ///   - baseHeight: The current detent height
    ///   - minHeight: The minimum allowed height
    ///   - maxHeight: The maximum allowed height
    /// - Returns: The offset to apply (with rubber banding at edges)
    static func computeRubberBandOffset(
        translation: CGFloat,
        baseHeight: CGFloat,
        minHeight: CGFloat,
        maxHeight: CGFloat
    ) -> CGFloat {
        let projectedHeight = baseHeight - translation

        if projectedHeight < minHeight {
            // Below minimum - rubber band
            let overscroll = minHeight - projectedHeight
            let dampedOverscroll = overscroll * rubberBandFactor
            return translation + overscroll - dampedOverscroll
        } else if projectedHeight > maxHeight {
            // Above maximum - rubber band
            let overscroll = projectedHeight - maxHeight
            let dampedOverscroll = overscroll * rubberBandFactor
            return translation - overscroll + dampedOverscroll
        }

        return translation
    }

    /// Get the next higher detent from the current one.
    private static func nextHigherDetent(
        from current: SurfaceDetent,
        in allowed: [SurfaceDetent],
        containerHeight: CGFloat
    ) -> SurfaceDetent {
        let currentHeight = current.height(in: containerHeight)

        // Find allowed detents with greater height
        let higherDetents = allowed.filter { $0.height(in: containerHeight) > currentHeight }

        // Return the one with smallest height (closest higher)
        return higherDetents.min { $0.height(in: containerHeight) < $1.height(in: containerHeight) }
            ?? current
    }

    /// Get the next lower detent from the current one.
    private static func nextLowerDetent(
        from current: SurfaceDetent,
        in allowed: [SurfaceDetent],
        containerHeight: CGFloat
    ) -> SurfaceDetent {
        let currentHeight = current.height(in: containerHeight)

        // Find allowed detents with smaller height
        let lowerDetents = allowed.filter { $0.height(in: containerHeight) < currentHeight }

        // Return the one with greatest height (closest lower)
        return lowerDetents.max { $0.height(in: containerHeight) < $1.height(in: containerHeight) }
            ?? current
    }
}
