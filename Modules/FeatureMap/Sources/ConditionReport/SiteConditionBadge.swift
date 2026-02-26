import SwiftUI
import UmiDB

/// Compact badge showing the latest conditions for a site.
/// Designed to be embedded in site cards / inspect views.
public struct SiteConditionBadge: View {
    let summary: SiteConditionSummary

    public init(summary: SiteConditionSummary) {
        self.summary = summary
    }

    public var body: some View {
        if summary.freshness == .none {
            EmptyView()
        } else {
            HStack(spacing: 8) {
                freshnessIndicator

                if let vis = summary.avgVisibility {
                    Label("\(Int(vis))m", systemImage: "eye")
                        .font(.caption2)
                }

                if let temp = summary.avgTemperature {
                    Label("\(Int(temp))\u{00B0}", systemImage: "thermometer.medium")
                        .font(.caption2)
                }

                if let current = summary.dominantCurrent, current != .none {
                    Label(current.displayName, systemImage: "wind")
                        .font(.caption2)
                }

                if summary.reportCount24h > 0 {
                    Text("\(summary.reportCount24h) today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var freshnessIndicator: some View {
        Circle()
            .fill(freshnessColor)
            .frame(width: 6, height: 6)
    }

    private var freshnessColor: Color {
        switch summary.freshness {
        case .live: return .green
        case .recent: return .yellow
        case .stale: return .orange
        case .old: return .gray
        case .none: return .clear
        }
    }
}
