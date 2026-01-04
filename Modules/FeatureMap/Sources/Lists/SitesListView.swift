import SwiftUI
import UmiDB
import UmiDesignSystem

// MARK: - Sites List

/// Displays a scrollable list of dive sites with selection support
struct SitesListView: View {
    let sites: [DiveSite]
    let selectedSiteId: String?
    let onSiteTap: (DiveSite) -> Void
    var limit: Int? = nil
    var scrollDisabled: Bool = false
    var emptyState: EmptyStateConfiguration? = nil
    @State private var flashId: String?

    var body: some View {
        ScrollViewReader { proxy in
            let displayed = limit.map { Array(sites.prefix($0)) } ?? sites
            if sites.isEmpty {
                if let emptyState {
                    EmptyStateView(
                        icon: emptyState.icon,
                        title: emptyState.title,
                        message: emptyState.message,
                        primaryTitle: emptyState.primaryTitle,
                        primaryAction: emptyState.primaryAction,
                        secondaryTitle: emptyState.secondaryTitle,
                        secondaryAction: emptyState.secondaryAction
                    )
                } else {
                    EmptyStateView(
                        icon: "tray",
                        title: "No sites found",
                        message: "Clear filters or zoom out to reveal more dive sites."
                    )
                }
            } else if displayed.isEmpty {
                EmptyStateView(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Expand to see more",
                    message: "Pull the sheet up or zoom the map to browse sites here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayed) { site in
                            SiteRow(site: site, isHighlighted: flashId == site.id)
                                .id(site.id)
                                .onTapGesture { onSiteTap(site) }
                        }
                    }
                }
                .scrollDisabled(scrollDisabled)
            }
        }
        .onChange(of: selectedSiteId) { newId in
            guard let id = newId else { return }
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    flashId = id
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.3)) { flashId = nil }
            }
        }
    }
}

// MARK: - Site Row

struct SiteRow: View {
    let site: DiveSite
    var isHighlighted: Bool = false

    var statusLabel: String {
        if site.visitedCount > 0 {
            return "Logged, \(site.visitedCount) dive(s)"
        } else if site.wishlist {
            return "Wishlist"
        } else {
            return "Not visited"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(site.visitedCount > 0 ? Color.oceanBlue : (site.wishlist ? Color.yellow : Color.gray.opacity(0.3)))
                .frame(width: 8, height: 8)
                .accessibilityLabel(statusLabel)

            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .accessibilityLabel("Site: \(site.name)")

                Text(site.location)
                    .font(.caption)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    .accessibilityLabel("Location: \(site.location)")

                HStack(spacing: 6) {
                    QuickFactChip(text: site.difficulty.rawValue)
                    QuickFactChip(text: "Max \(Int(site.maxDepth))m")
                    QuickFactChip(text: "\(Int(site.averageTemp))°C")
                }
                .accessibilityLabel("\(site.difficulty.rawValue) difficulty, maximum depth \(Int(site.maxDepth)) meters, average temperature \(Int(site.averageTemp)) degrees")
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.oceanBlue.opacity(isHighlighted ? 0.12 : 0.0))
        )
        .scaleEffect(isHighlighted ? 1.03 : 1.0)
        .shadow(color: isHighlighted ? Color.oceanBlue.opacity(0.25) : .clear, radius: 8, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHighlighted)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Quick Fact Chip

struct QuickFactChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Color.mist)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.trench)
            .cornerRadius(8)
            .accessibilityLabel(text)
    }
}

// MARK: - Shops List

typealias MapDiveShop = UmiDB.DiveShop

struct ShopsListView: View {
    let shops: [MapDiveShop]
    let onShopTap: (MapDiveShop) -> Void
    var limit: Int? = nil
    var scrollDisabled: Bool = false
    var emptyState: EmptyStateConfiguration? = nil

    private var displayedShops: [MapDiveShop] {
        guard let limit else { return shops }
        return Array(shops.prefix(limit))
    }

    var body: some View {
        if shops.isEmpty {
            if let emptyState {
                EmptyStateView(
                    icon: emptyState.icon,
                    title: emptyState.title,
                    message: emptyState.message,
                    primaryTitle: emptyState.primaryTitle,
                    primaryAction: emptyState.primaryAction,
                    secondaryTitle: emptyState.secondaryTitle,
                    secondaryAction: emptyState.secondaryAction
                )
            } else {
                EmptyStateView(
                    icon: "building.2",
                    title: "No shops found",
                    message: "Zoom out or clear filters to see nearby dive shops."
                )
            }
        } else if displayedShops.isEmpty {
            EmptyStateView(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "Expand to see more",
                message: "Pull the sheet up or zoom the map to browse dive shops in this area."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(displayedShops) { shop in
                        ShopRow(shop: shop)
                            .contentShape(Rectangle())
                            .onTapGesture { onShopTap(shop) }
                    }
                }
            }
            .scrollDisabled(scrollDisabled)
        }
    }
}

// MARK: - Shop Row

struct ShopRow: View {
    let shop: MapDiveShop

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 24))
                .foregroundStyle(Color.oceanBlue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name)
                    .font(.body)
                    .foregroundStyle(Color.foam)
                    .accessibilityLabel("Shop: \(shop.name)")
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                }
                if let detail = detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(SwiftUI.Color(UIColor.tertiaryLabel))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String? {
        var components: [String] = []
        if let area = shop.area, !area.isEmpty {
            components.append(area)
        }
        if let country = shop.country, !country.isEmpty {
            components.append(country)
        } else if let region = shop.region, !region.isEmpty {
            components.append(region)
        }
        return components.joined(separator: " · ")
    }

    private var detail: String? {
        if let service = shop.services.first, !service.isEmpty {
            return service
        }
        if let phone = shop.phone, !phone.isEmpty {
            return phone
        }
        if let website = shop.website, !website.isEmpty {
            return website
        }
        return nil
    }
}
