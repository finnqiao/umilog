import UIKit
import QuartzCore

/// Manages map marker animations using CADisplayLink for smooth 60fps updates.
/// Handles selection pulse animations and cluster expansion bounce effects.
public final class MapAnimator {
    // MARK: - Properties

    private var displayLink: CADisplayLink?
    private var selectionAnimation: SelectionAnimation?
    private var bounceAnimation: BounceAnimation?

    /// Callback invoked each frame with updated animation values.
    /// Parameters: (siteId, scale, offsetY)
    public var onAnimationFrame: ((String, CGFloat, CGFloat) -> Void)?

    /// Callback invoked when all animations complete.
    public var onAnimationsComplete: (() -> Void)?

    // MARK: - Animation State

    private struct SelectionAnimation {
        let siteId: String
        let startTime: CFTimeInterval
        let duration: CFTimeInterval
        var isComplete = false

        init(siteId: String) {
            self.siteId = siteId
            self.startTime = CACurrentMediaTime()
            self.duration = MapIcons.AnimationConfig.selectionPulseDuration
        }
    }

    private struct BounceAnimation {
        let siteIds: [String]
        let startTime: CFTimeInterval
        let staggerDelay: CFTimeInterval
        let duration: CFTimeInterval
        var completedCount = 0

        init(siteIds: [String]) {
            self.siteIds = siteIds
            self.startTime = CACurrentMediaTime()
            self.staggerDelay = MapIcons.AnimationConfig.bounceStaggerDelay
            self.duration = MapIcons.AnimationConfig.bounceDuration
        }

        var isComplete: Bool {
            completedCount >= siteIds.count
        }

        var totalDuration: CFTimeInterval {
            duration + Double(siteIds.count) * staggerDelay
        }
    }

    // MARK: - Initialization

    public init() {}

    deinit {
        stopDisplayLink()
    }

    // MARK: - Public API

    /// Start a selection pulse animation for the given site.
    /// The marker will scale up and pulse, then settle at a slightly larger size.
    public func startSelectionAnimation(for siteId: String) {
        selectionAnimation = SelectionAnimation(siteId: siteId)
        startDisplayLink()

        // Trigger haptic feedback
        if MapTheme.Animation.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: MapTheme.Animation.selectionHapticStyle)
            generator.impactOccurred()
        }
    }

    /// Start a bounce animation for multiple sites (e.g., after cluster expansion).
    /// Sites will bounce in with a staggered delay.
    public func startBounceAnimation(for siteIds: [String]) {
        guard !siteIds.isEmpty else { return }
        bounceAnimation = BounceAnimation(siteIds: siteIds)
        startDisplayLink()

        // Trigger haptic feedback
        if MapTheme.Animation.enableHaptics {
            let generator = UIImpactFeedbackGenerator(style: MapTheme.Animation.clusterHapticStyle)
            generator.impactOccurred()
        }
    }

    /// Cancel all running animations.
    public func cancelAnimations() {
        selectionAnimation = nil
        bounceAnimation = nil
        stopDisplayLink()
    }

    /// Check if any animations are currently running.
    public var isAnimating: Bool {
        selectionAnimation != nil || bounceAnimation != nil
    }

    // MARK: - Display Link Management

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateFrame(_ link: CADisplayLink) {
        let currentTime = CACurrentMediaTime()

        // Update selection animation
        if var selection = selectionAnimation {
            updateSelectionAnimation(&selection, at: currentTime)
            if selection.isComplete {
                selectionAnimation = nil
            } else {
                selectionAnimation = selection
            }
        }

        // Update bounce animation
        if var bounce = bounceAnimation {
            updateBounceAnimation(&bounce, at: currentTime)
            if bounce.isComplete {
                bounceAnimation = nil
            } else {
                bounceAnimation = bounce
            }
        }

        // Stop display link if all animations complete
        if selectionAnimation == nil && bounceAnimation == nil {
            stopDisplayLink()
            onAnimationsComplete?()
        }
    }

    // MARK: - Selection Animation

    private func updateSelectionAnimation(_ animation: inout SelectionAnimation, at currentTime: CFTimeInterval) {
        let elapsed = currentTime - animation.startTime
        let progress = min(elapsed / animation.duration, 1.0)

        // Pulse effect: ease-in-out oscillation that dampens over time
        let pulseScale = MapIcons.AnimationConfig.selectionPulseScale
        let finalScale = MapIcons.AnimationConfig.selectionFinalScale
        let dampening = 1.0 - progress

        // Scale oscillates and settles at finalScale
        let oscillation = sin(progress * .pi * 2) * dampening
        let scale = 1.0 + (pulseScale - 1.0) * oscillation + (finalScale - 1.0) * progress

        onAnimationFrame?(animation.siteId, CGFloat(scale), 0)

        if progress >= 1.0 {
            // Final state: keep at finalScale
            onAnimationFrame?(animation.siteId, finalScale, 0)
            animation.isComplete = true
        }
    }

    // MARK: - Bounce Animation

    private func updateBounceAnimation(_ animation: inout BounceAnimation, at currentTime: CFTimeInterval) {
        let baseElapsed = currentTime - animation.startTime

        for (index, siteId) in animation.siteIds.enumerated() {
            let staggeredElapsed = baseElapsed - Double(index) * animation.staggerDelay

            // Skip if this site hasn't started yet
            guard staggeredElapsed >= 0 else { continue }

            let progress = min(staggeredElapsed / animation.duration, 1.0)

            // Spring bounce: overshoot then settle
            let bounceOffset = MapIcons.AnimationConfig.bounceOffsetY
            let springValue = calculateSpring(progress: progress)
            let offsetY = bounceOffset * (1.0 - springValue)

            onAnimationFrame?(siteId, 1.0, CGFloat(offsetY))

            if progress >= 1.0 {
                // Ensure final state is at rest
                onAnimationFrame?(siteId, 1.0, 0)
                animation.completedCount = max(animation.completedCount, index + 1)
            }
        }
    }

    /// Spring interpolation with overshoot and settle.
    private func calculateSpring(progress: Double) -> Double {
        // Damped harmonic oscillator approximation
        let frequency: Double = 3.0
        let damping: Double = 0.6
        let decay = exp(-damping * progress * 10)
        let oscillation = cos(progress * .pi * frequency)
        return 1.0 - decay * oscillation * (1.0 - progress)
    }
}
