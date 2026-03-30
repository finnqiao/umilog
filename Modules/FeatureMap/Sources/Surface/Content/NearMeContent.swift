import SwiftUI
import UmiDB
import UmiDesignSystem
import CoreLocation

/// Content view for Near Me mode in the bottom surface.
/// Shows nearest areas and sites based on user location, with radius selection.
struct NearMeContent: View {
    let sites: [DiveSite]
    let nearbyAreas: [AreaSummary]
    let userLocation: CLLocation?
    let isLoading: Bool

    var onSiteTap: (DiveSite) -> Void
    var onAreaTap: (AreaSummary) -> Void
    var onDismiss: () -> Void

    @State private var selectedRadius: NearMeRadius = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Radius chips
            radiusSelector
                .padding(.bottom, 12)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
            } else if sites.isEmpty && nearbyAreas.isEmpty {
                sparseState
            } else {
                contentList
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.lagoon)
                    Text("Near you")
                        .font(.headline)
                        .foregroundStyle(Color.foam)
                }

                if !sites.isEmpty || !nearbyAreas.isEmpty {
                    let totalCount = sites.count + nearbyAreas.reduce(0, { $0 + $1.siteCount })
                    Text("\(nearbyAreas.count) areas · \(totalCount) sites within \(selectedRadius.displayName)")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.mist.opacity(0.6))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close near me")
        }
    }

    // MARK: - Radius Selector

    private var radiusSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NearMeRadius.allCases) { radius in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedRadius = radius
                        }
                        Haptics.soft()
                    } label: {
                        Text(radius.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(selectedRadius == radius ? Color.foam : Color.mist)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedRadius == radius ? Color.lagoon.opacity(0.3) : Color.trench)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Content List

    private var contentList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Areas section
                if !nearbyAreas.isEmpty {
                    sectionHeader("Dive areas", icon: "map")
                    ForEach(nearbyAreas) { area in
                        NearMeAreaRow(area: area, userLocation: userLocation) {
                            onAreaTap(area)
                        }
                    }
                }

                // Sites section
                if !sites.isEmpty {
                    sectionHeader("Dive sites", icon: "mappin.and.ellipse")
                        .padding(.top, nearbyAreas.isEmpty ? 0 : 16)
                    ForEach(sites) { site in
                        NearMeSiteRow(site: site, userLocation: userLocation) {
                            onSiteTap(site)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.lagoon)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.foam)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Sparse State

    private var sparseState: some View {
        VStack(spacing: 16) {
            Image(systemName: "water.waves")
                .font(.system(size: 40))
                .foregroundStyle(Color.mist.opacity(0.4))

            Text("No dive sites nearby")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text("Try expanding your search radius or explore popular destinations.")
                .font(.subheadline)
                .foregroundStyle(Color.mist)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}

// MARK: - Radius Options

enum NearMeRadius: String, CaseIterable, Identifiable {
    case close = "25km"
    case medium = "100km"
    case wide = "500km"

    var id: String { rawValue }
    var displayName: String { rawValue }
    var kilometers: Double {
        switch self {
        case .close: return 25
        case .medium: return 100
        case .wide: return 500
        }
    }
}

// MARK: - Area Row

private struct NearMeAreaRow: View {
    let area: AreaSummary
    let userLocation: CLLocation?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.reef.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "map")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.reef)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(area.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)
                    HStack(spacing: 4) {
                        Text("\(area.siteCount) sites")
                            .font(.caption)
                            .foregroundStyle(Color.mist)
                        if let distance = distanceText {
                            Text("· \(distance)")
                                .font(.caption)
                                .foregroundStyle(Color.mist)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var distanceText: String? {
        guard let userLoc = userLocation else { return nil }
        let areaLoc = CLLocation(latitude: area.centerLat, longitude: area.centerLon)
        let distKm = userLoc.distance(from: areaLoc) / 1000
        if distKm < 1 { return "<1 km" }
        if distKm < 100 { return "\(Int(distKm)) km" }
        return "\(Int(distKm)) km"
    }
}

// MARK: - Site Row

private struct NearMeSiteRow: View {
    let site: DiveSite
    let userLocation: CLLocation?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 3) {
                    Text(site.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)
                    HStack(spacing: 4) {
                        Text(site.difficulty.rawValue)
                            .font(.caption)
                            .foregroundStyle(Color.mist)
                        if let distance = distanceText {
                            Text("· \(distance)")
                                .font(.caption)
                                .foregroundStyle(Color.mist)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        if site.visitedCount > 0 { return Color.pinVisited }
        if site.wishlist { return Color.pinFavorite }
        return Color.pinDefault.opacity(0.3)
    }

    private var distanceText: String? {
        guard let userLoc = userLocation else { return nil }
        let siteLoc = CLLocation(latitude: site.latitude, longitude: site.longitude)
        let distKm = userLoc.distance(from: siteLoc) / 1000
        if distKm < 1 { return "<1 km" }
        return "\(Int(distKm)) km"
    }
}
