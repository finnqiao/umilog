import SwiftUI
import UmiDesignSystem
import UmiDB
import CoreLocation

/// A Resy-style floating action button for quick dive logging.
/// Shows context (nearby site name or GPS location) and surface interval.
struct QuickCaptureFAB: View {
    let nearbySite: DiveSite?
    let surfaceInterval: TimeInterval?
    var onTap: (DiveSite?) -> Void

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Surface interval indicator (shown when expanded)
            if isExpanded, let interval = surfaceInterval {
                SurfaceIntervalBadge(interval: interval)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }

            // Main FAB
            Button(action: handleTap) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20, weight: .semibold))

                    if isExpanded {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log Dive")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let site = nearbySite {
                                Text(site.name)
                                    .font(.caption)
                                    .opacity(0.8)
                                    .lineLimit(1)
                            } else {
                                Text("Current location")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }
                    }
                }
                .foregroundStyle(Color.abyss)
                .padding(.horizontal, isExpanded ? 16 : 14)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.reef, Color.pinVisited],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.reef.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log new dive")
            .accessibilityHint(nearbySite != nil ? "At \(nearbySite!.name)" : "Using current location")
        }
        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    private func handleTap() {
        if isExpanded {
            // Second tap - trigger action
            onTap(nearbySite)
            if reduceMotion {
                isExpanded = false
            } else {
                withAnimation {
                    isExpanded = false
                }
            }
        } else {
            // First tap - expand to show context
            if reduceMotion {
                isExpanded = true
            } else {
                withAnimation {
                    isExpanded = true
                }
            }
            // Auto-collapse after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if reduceMotion {
                    isExpanded = false
                } else {
                    withAnimation {
                        isExpanded = false
                    }
                }
            }
        }
    }
}

// MARK: - Surface Interval Badge

/// Shows time since last dive (surface interval) for safety awareness.
private struct SurfaceIntervalBadge: View {
    let interval: TimeInterval

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)
            Text(formatInterval(interval))
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(Color.foam)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.glass)
        )
    }

    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m surface"
        }
        return "\(minutes)m surface"
    }
}

// MARK: - Preview

#Preview("FAB - Collapsed") {
    ZStack {
        Color.abyss.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                Spacer()
                QuickCaptureFAB(
                    nearbySite: nil,
                    surfaceInterval: 3600 * 2 + 45 * 60,
                    onTap: { _ in }
                )
                .padding(24)
            }
        }
    }
}

#Preview("FAB - With Site") {
    ZStack {
        Color.abyss.ignoresSafeArea()
        VStack {
            Spacer()
            HStack {
                Spacer()
                QuickCaptureFAB(
                    nearbySite: DiveSite(
                        id: "test",
                        name: "Blue Corner",
                        location: "Palau",
                        latitude: 7.0,
                        longitude: 134.0,
                        region: "Koror",
                        averageDepth: 20,
                        maxDepth: 35,
                        averageTemp: 28,
                        averageVisibility: 30,
                        difficulty: .intermediate,
                        type: .wall
                    ),
                    surfaceInterval: 90 * 60,
                    onTap: { _ in }
                )
                .padding(24)
            }
        }
    }
}
