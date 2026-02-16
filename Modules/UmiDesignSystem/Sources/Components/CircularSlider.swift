import SwiftUI

/// A circular slider control for numerical input with drag gesture support.
/// Designed for depth and time inputs in the dive logging flow.
public struct CircularSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let label: String
    var accentColor: Color = .lagoon
    var trackColor: Color = .glass
    var diameter: CGFloat = 120

    @State private var isDragging = false
    @GestureState private var dragAngle: Double = 0

    public init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        unit: String,
        label: String,
        accentColor: Color = .lagoon,
        trackColor: Color = .glass,
        diameter: CGFloat = 120
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.label = label
        self.accentColor = accentColor
        self.trackColor = trackColor
        self.diameter = diameter
    }

    // Normalized value 0...1
    private var normalizedValue: Double {
        let rangeSpan = range.upperBound - range.lowerBound
        guard rangeSpan > 0 else { return 0 }
        return (value - range.lowerBound) / rangeSpan
    }

    // Arc spans from -135° to +135° (270° total)
    private let startAngle: Double = -135
    private let endAngle: Double = 135
    private var totalArcAngle: Double { endAngle - startAngle }

    private var currentAngle: Double {
        startAngle + (normalizedValue * totalArcAngle)
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track (background arc)
                Circle()
                    .trim(from: angleToTrim(startAngle), to: angleToTrim(endAngle))
                    .stroke(trackColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Active arc
                Circle()
                    .trim(from: angleToTrim(startAngle), to: angleToTrim(currentAngle))
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.interactiveSpring(response: 0.2), value: value)

                // Thumb indicator
                Circle()
                    .fill(accentColor)
                    .frame(width: 20, height: 20)
                    .shadow(color: accentColor.opacity(0.5), radius: isDragging ? 8 : 4)
                    .offset(thumbOffset)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .animation(.spring(response: 0.2), value: isDragging)

                // Center value display
                VStack(spacing: 2) {
                    Text(formattedValue)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text(unit)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
            .gesture(dragGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label): \(formattedValue) \(unit)")
            .accessibilityValue("\(formattedValue) \(unit)")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    adjustValue(by: step)
                case .decrement:
                    adjustValue(by: -step)
                @unknown default:
                    break
                }
            }

            // Label below
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computed Properties

    private var formattedValue: String {
        if step >= 1 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private var thumbOffset: CGSize {
        let radius = (diameter - 24) / 2
        let angleRadians = currentAngle * .pi / 180
        // Offset from center, accounting for -90° rotation
        let x = cos(angleRadians - .pi / 2) * radius
        let y = sin(angleRadians - .pi / 2) * radius
        return CGSize(width: x, height: y)
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDragging {
                    isDragging = true
                    Haptics.tap()
                }

                let center = CGPoint(x: diameter / 2, y: diameter / 2)
                let location = gesture.location

                // Calculate angle from center
                let dx = location.x - center.x
                let dy = location.y - center.y
                var angle = atan2(dy, dx) * 180 / .pi

                // Convert to our coordinate system (0° at top)
                angle += 90
                if angle < -180 { angle += 360 }
                if angle > 180 { angle -= 360 }

                // Clamp to arc range
                let clampedAngle = min(max(angle, startAngle), endAngle)

                // Convert angle to value
                let normalizedAngle = (clampedAngle - startAngle) / totalArcAngle
                let rawValue = range.lowerBound + (normalizedAngle * (range.upperBound - range.lowerBound))

                // Snap to step
                let steppedValue = round(rawValue / step) * step
                let clampedValue = min(max(steppedValue, range.lowerBound), range.upperBound)

                // Only update if value changed (for haptic feedback)
                if clampedValue != value {
                    value = clampedValue
                    Haptics.soft()
                }
            }
            .onEnded { _ in
                isDragging = false
                Haptics.tap()
            }
    }

    // MARK: - Helpers

    private func angleToTrim(_ angle: Double) -> Double {
        // Convert our angle (-135 to 135) to trim value (0 to 1)
        // Total arc is 270°, which is 0.75 of the circle
        // Starting at -135° (which is 0.625 in trim space with -90° rotation)
        let normalized = (angle + 180) / 360
        return normalized
    }

    private func adjustValue(by delta: Double) {
        let newValue = min(max(value + delta, range.lowerBound), range.upperBound)
        if newValue != value {
            value = newValue
            Haptics.soft()
        }
    }
}

// MARK: - Convenience Initializers

public extension CircularSlider {
    /// Depth slider with sensible defaults for dive logging (0-60m)
    static func depth(value: Binding<Double>, unit: String = "m") -> CircularSlider {
        CircularSlider(
            value: value,
            range: 0...60,
            step: 1,
            unit: unit,
            label: "Max Depth",
            accentColor: .lagoon
        )
    }

    /// Time slider with sensible defaults for dive logging (0-120min)
    static func time(value: Binding<Double>, unit: String = "min") -> CircularSlider {
        CircularSlider(
            value: value,
            range: 0...120,
            step: 5,
            unit: unit,
            label: "Bottom Time",
            accentColor: .reef
        )
    }
}

// MARK: - Preview

#Preview("CircularSlider") {
    struct PreviewWrapper: View {
        @State private var depth: Double = 32
        @State private var time: Double = 45

        var body: some View {
            VStack(spacing: 32) {
                HStack(spacing: 24) {
                    CircularSlider.depth(value: $depth)
                    CircularSlider.time(value: $time)
                }

                Text("Depth: \(Int(depth))m, Time: \(Int(time))min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.abyss)
        }
    }

    return PreviewWrapper()
}
