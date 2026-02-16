import SwiftUI
import Charts

/// Depth profile chart visualization for dive logs
/// Generates a synthetic depth profile from dive parameters
public struct DepthProfileChart: View {
    private let data: DepthProfileData
    private let showSafetyStop: Bool
    private let animate: Bool

    @State private var animationProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        maxDepth: Double,
        averageDepth: Double?,
        bottomTime: Int,
        showSafetyStop: Bool = true,
        animate: Bool = true
    ) {
        self.data = DepthProfileData(
            maxDepth: maxDepth,
            averageDepth: averageDepth ?? maxDepth * 0.7,
            bottomTime: bottomTime
        )
        self.showSafetyStop = showSafetyStop
        self.animate = animate
    }

    /// Whether animation should be used based on settings and Reduce Motion preference
    private var shouldAnimate: Bool {
        animate && !reduceMotion
    }

    public var body: some View {
        Chart {
            // Safety stop zone (3-6m depth range)
            if showSafetyStop && data.maxDepth > 10 {
                RectangleMark(
                    xStart: .value("Start", data.safetyStopStart),
                    xEnd: .value("End", data.safetyStopEnd),
                    yStart: .value("Top", 3),
                    yEnd: .value("Bottom", 6)
                )
                .foregroundStyle(Color.reef.opacity(0.2))
            }

            // Depth profile line
            ForEach(data.points.prefix(animatedPointCount)) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Depth", point.depth)
                )
                .foregroundStyle(Color.lagoon)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }

            // Area fill under the curve
            ForEach(data.points.prefix(animatedPointCount)) { point in
                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("Depth", point.depth)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.lagoon.opacity(0.3), Color.lagoon.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Max depth marker
            if let maxPoint = data.maxDepthPoint, animationProgress >= 0.5 {
                PointMark(
                    x: .value("Time", maxPoint.time),
                    y: .value("Depth", maxPoint.depth)
                )
                .foregroundStyle(Color.reef)
                .symbolSize(50)
                .annotation(position: .bottom, spacing: 4) {
                    Text(String(format: "%.1fm", maxPoint.depth))
                        .font(.caption2)
                        .foregroundStyle(Color.reef)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true, reversed: true))
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let minutes = value.as(Int.self) {
                        Text("\(minutes)m")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let depth = value.as(Double.self) {
                        Text(String(format: "%.0fm", depth))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 200)
        .onAppear {
            if shouldAnimate {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animationProgress = 1
                }
            } else {
                // Show full chart immediately when Reduce Motion is enabled
                animationProgress = 1
            }
        }
    }

    private var animatedPointCount: Int {
        Int(CGFloat(data.points.count) * animationProgress)
    }
}

/// Data model for depth profile points
public struct DepthProfileData {
    let points: [DepthPoint]
    let maxDepth: Double
    let averageDepth: Double
    let bottomTime: Int
    let safetyStopStart: Int
    let safetyStopEnd: Int

    var maxDepthPoint: DepthPoint? {
        points.max(by: { $0.depth < $1.depth })
    }

    init(maxDepth: Double, averageDepth: Double, bottomTime: Int) {
        self.maxDepth = maxDepth
        self.averageDepth = averageDepth
        self.bottomTime = bottomTime

        // Generate synthetic profile points
        self.points = Self.generateProfile(
            maxDepth: maxDepth,
            averageDepth: averageDepth,
            bottomTime: bottomTime
        )

        // Safety stop typically in last 3-5 minutes
        let safetyDuration = min(3, bottomTime / 5)
        self.safetyStopStart = max(0, bottomTime - safetyDuration - 2)
        self.safetyStopEnd = bottomTime - 1
    }

    /// Generate a realistic-looking depth profile curve
    private static func generateProfile(maxDepth: Double, averageDepth: Double, bottomTime: Int) -> [DepthPoint] {
        var points: [DepthPoint] = []

        // Phase durations
        let descentTime = max(1, bottomTime / 8)
        let bottomPhaseEnd = bottomTime - max(2, bottomTime / 6)
        let ascentTime = bottomTime - bottomPhaseEnd

        // Generate points at regular intervals
        let interval = max(1, bottomTime / 30) // ~30 points max

        for minute in stride(from: 0, through: bottomTime, by: interval) {
            let depth: Double

            if minute <= descentTime {
                // Descent phase - quick descent to near max
                let progress = Double(minute) / Double(descentTime)
                depth = maxDepth * 0.9 * easeInOut(progress)
            } else if minute <= bottomPhaseEnd {
                // Bottom phase - oscillate around average depth
                let phaseProgress = Double(minute - descentTime) / Double(bottomPhaseEnd - descentTime)
                let oscillation = sin(phaseProgress * .pi * 4) * (maxDepth - averageDepth) * 0.3
                depth = averageDepth + oscillation + (maxDepth - averageDepth) * 0.1 * sin(phaseProgress * .pi)
            } else {
                // Ascent phase - gradual rise with safety stop
                let ascentProgress = Double(minute - bottomPhaseEnd) / Double(ascentTime)
                if ascentProgress < 0.7 {
                    // Normal ascent
                    depth = averageDepth * (1 - ascentProgress * 0.8)
                } else {
                    // Safety stop zone (~5m)
                    let stopProgress = (ascentProgress - 0.7) / 0.3
                    depth = 5 * (1 - stopProgress * 0.8) // Hover around 5m then surface
                }
            }

            points.append(DepthPoint(time: minute, depth: max(0, depth)))
        }

        // Ensure we end at surface
        if points.last?.depth ?? 0 > 0.5 {
            points.append(DepthPoint(time: bottomTime, depth: 0))
        }

        return points
    }

    private static func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

/// A single point on the depth profile
public struct DepthPoint: Identifiable {
    public let id = UUID()
    public let time: Int // minutes
    public let depth: Double // meters
}

#Preview("30m Deep Dive") {
    VStack {
        Text("30m Dive - 45 minutes")
            .font(.headline)
        DepthProfileChart(
            maxDepth: 30,
            averageDepth: 22,
            bottomTime: 45
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Shallow Dive") {
    VStack {
        Text("12m Dive - 60 minutes")
            .font(.headline)
        DepthProfileChart(
            maxDepth: 12,
            averageDepth: 9,
            bottomTime: 60,
            showSafetyStop: false
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
