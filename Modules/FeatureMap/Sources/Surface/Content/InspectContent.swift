import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit
import FeatureLiveLog
import UmiLocationKit
import os

/// Content view for Inspect mode in the unified bottom surface.
/// Shows site details at medium detent, full details when expanded.
struct InspectContent: View {
    // MARK: - Properties

    let context: SiteInspectionContext
    let site: DiveSite?
    let detent: SurfaceDetent

    var onDismiss: () -> Void
    var onLog: () -> Void
    var onSave: () -> Void
    var onOpenPlan: (String) -> Void

    // MARK: - State

    @State private var isWishlist: Bool
    @State private var isUpdatingWishlist = false
    @State private var wishlistError: String?
    @State private var showingLogWizard = false
    @State private var showingConditionReport = false
    @State private var conditionSummary: SiteConditionSummary?
    @State private var mediaURL: URL?
    @State private var entryModes: [String] = []

    // MARK: - Init

    init(
        context: SiteInspectionContext,
        site: DiveSite?,
        detent: SurfaceDetent,
        onDismiss: @escaping () -> Void,
        onLog: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {},
        onOpenPlan: @escaping (String) -> Void = { _ in }
    ) {
        self.context = context
        self.site = site
        self.detent = detent
        self.onDismiss = onDismiss
        self.onLog = onLog
        self.onSave = onSave
        self.onOpenPlan = onOpenPlan
        _isWishlist = State(initialValue: site?.wishlist ?? false)
    }

    // MARK: - Body

    var body: some View {
        if let site = site {
            VStack(alignment: .leading, spacing: 0) {
                siteHeader(site: site)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                if detent == .medium || detent == .expanded {
                    // Hero image - always show at medium and expanded
                    heroImage(for: site)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    actionsRow(site: site)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    // Quick facts - always show at medium and expanded
                    quickFactsRow(for: site)
                        .padding(.bottom, 12)

                    if detent == .medium {
                        if let description = site.description, !description.isEmpty {
                            Text(description)
                                .font(.callout)
                                .foregroundStyle(Color.mist)
                                .lineLimit(4)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        } else {
                            Text("No description available yet")
                                .font(.callout)
                                .foregroundStyle(Color.mist.opacity(0.5))
                                .italic()
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                        }

                        if !entryModes.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(entryModes, id: \.self) { mode in
                                        Label(mode, systemImage: entryModeIcon(mode))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.mist)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.kelp.opacity(0.4))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 12)
                        }
                    }
                }

                if detent == .expanded {
                    expandedContent(site: site)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("diveMap.siteDetails")
            .sheet(isPresented: $showingLogWizard) {
                LiveLogWizardView(initialSite: site)
            }
            .sheet(isPresented: $showingConditionReport) {
                QuickReportSheet(
                    siteId: site.id,
                    siteName: site.name,
                    onDismiss: { showingConditionReport = false }
                )
            }
            .task(id: site.id) {
                await loadEntryModes(for: site.id)
            }
            .alert("Wishlist Error", isPresented: Binding(
                get: { wishlistError != nil },
                set: { if !$0 { wishlistError = nil } }
            )) {
                Button("OK", role: .cancel) { wishlistError = nil }
            } message: {
                Text(wishlistError ?? "")
            }
        } else {
            notFoundView
        }
    }

    // MARK: - Hero Image

    private func heroImage(for site: DiveSite) -> some View {
        let imageHeight: CGFloat = detent == .medium ? 120 : 160

        return GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Render at full container width so the image fills the banner.
                // AsyncSiteImage is always square; we clip to landscape height externally.
                AsyncSiteImage(
                    site: site,
                    mediaURL: mediaURL,
                    size: geo.size.width,
                    cornerRadius: 0
                )
                .frame(width: geo.size.width, height: imageHeight)
                .clipped()

                // Site type badge
                Text(site.type.rawValue)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.foam)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.abyss.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(10)

                // Condition badge (bottom-right)
                if let summary = conditionSummary {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            SiteConditionBadge(summary: summary)
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(height: imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.ocean.opacity(0.3), lineWidth: 1)
        )
        .task(id: site.id) {
            await loadMedia(for: site.id)
            await loadConditions(for: site.id)
        }
    }

    // MARK: - Media Loading

    private func loadMedia(for siteId: String) async {
        let mediaRepo = SiteMediaRepository(database: AppDatabase.shared)
        do {
            if let media = try mediaRepo.fetchMedia(for: siteId) {
                mediaURL = URL(string: media.url)
            } else {
                mediaURL = nil
            }
        } catch {
            mediaURL = nil
        }
    }

    // MARK: - Conditions Loading

    private func loadConditions(for siteId: String) async {
        let repo = AppDatabase.shared.conditionReportRepository
        do {
            let summary = try repo.summary(siteId: siteId)
            await MainActor.run {
                conditionSummary = summary
            }
        } catch {
            conditionSummary = nil
        }
    }

    // MARK: - Quick Facts Row

    private func quickFactsRow(for site: DiveSite) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickFactChip(text: site.difficulty.rawValue)
                QuickFactChip(text: "Max \(Int(site.maxDepth))m")
                QuickFactChip(text: "\(Int(site.averageTemp))°C")
                QuickFactChip(text: "\(Int(site.averageVisibility))m viz")
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Site Header

    private func siteHeader(site: DiveSite) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor(for: site))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(Color.foam)

                Text(site.location)
                    .font(.subheadline)
                    .foregroundStyle(Color.mist)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.lagoon)
                    .frame(width: 36, height: 36)
                    .background(Color.trench.opacity(0.72))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityIdentifier("diveMap.siteDetails.back")
        }
        .accessibilityHint("Swipe down to dismiss")
    }

    // MARK: - Actions Row

    private func actionsRow(site: DiveSite) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ActionButton(
                    icon: "location.fill",
                    title: "Navigate",
                    isActive: false,
                    isPrimary: false,
                    accessibilityIdentifier: "diveMap.siteDetails.navigate"
                ) {
                    SiteNavigationService.navigate(to: site, entryModes: entryModes)
                    Haptics.soft()
                }

                ActionButton(
                    icon: "doc.on.doc",
                    title: "Copy GPS",
                    isActive: false,
                    isPrimary: false,
                    accessibilityIdentifier: "diveMap.siteDetails.copyCoordinates"
                ) {
                    _ = SiteNavigationService.copyCoordinates(of: site)
                    Haptics.success()
                }

                ActionButton(
                    icon: "waveform",
                    title: "Log",
                    isActive: false,
                    isPrimary: true,
                    accessibilityIdentifier: "diveMap.siteDetails.log"
                ) {
                    showingLogWizard = true
                }

                ActionButton(
                    icon: isWishlist ? "star.fill" : "star",
                    title: isWishlist ? "Saved" : "Save",
                    isActive: isWishlist,
                    isPrimary: false,
                    isLoading: isUpdatingWishlist
                ) {
                    toggleWishlist(site: site)
                }

                ActionButton(
                    icon: "calendar.badge.plus",
                    title: "Plan",
                    isActive: false,
                    isPrimary: false
                ) {
                    onOpenPlan(site.id)
                }

                ActionButton(
                    icon: "cloud.sun",
                    title: "Report",
                    isActive: false,
                    isPrimary: false
                ) {
                    showingConditionReport = true
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Expanded Content

    private func expandedContent(site: DiveSite) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundStyle(Color.foam)
                    if let description = site.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(Color.mist)
                    } else {
                        Text("No description available yet")
                            .font(.body)
                            .foregroundStyle(Color.mist.opacity(0.5))
                            .italic()
                    }
                }
                .padding(.horizontal, 16)

                // Difficulty strip
                HStack {
                    Text("Difficulty Level")
                        .font(.subheadline)
                        .foregroundStyle(Color.mist)
                    Spacer()
                    Text(site.difficulty.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(difficultyColor(site.difficulty.rawValue))
                }
                .padding(16)
                .background(Color.trench)
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Not Found View

    private var notFoundView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(Color.mist.opacity(0.5))

            Text("Site not found")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Button("Dismiss", action: onDismiss)
                .buttonStyle(.bordered)
                .tint(Color.lagoon)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    // MARK: - Helpers

    private func statusColor(for site: DiveSite) -> Color {
        if site.visitedCount > 0 {
            return Color.lagoon
        } else if site.wishlist {
            return Color.statusSaved
        } else {
            return Color.mist.opacity(0.5)
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return Color.difficultyBeginner
        case "intermediate": return Color.difficultyIntermediate
        case "advanced": return Color.difficultyAdvanced
        default: return Color.mist
        }
    }

    private func toggleWishlist(site: DiveSite) {
        guard !isUpdatingWishlist else { return }
        isUpdatingWishlist = true
        let targetId = site.id
        let currentWishlist = isWishlist

        Task {
            do {
                let repository = SiteRepository(database: AppDatabase.shared)
                try repository.toggleWishlist(siteId: targetId)
                let newValue = !currentWishlist
                isWishlist = newValue
                isUpdatingWishlist = false
                Haptics.soft()
                NotificationCenter.default.post(
                    name: .wishlistUpdated,
                    object: targetId,
                    userInfo: ["wishlist": newValue]
                )
            } catch {
                isUpdatingWishlist = false
                wishlistError = "Couldn't update wishlist: \(error.localizedDescription)"
                Log.map.error("Wishlist error for site \(targetId): \(error.localizedDescription)")
            }
        }
    }

    private func entryModeIcon(_ mode: String) -> String {
        switch mode.lowercased() {
        case "boat": return "ferry"
        case "shore": return "figure.walk"
        case "liveaboard": return "sailboat"
        default: return "water.waves"
        }
    }

    private func loadEntryModes(for siteId: String) async {
        let repository = SiteFacetRepository(database: AppDatabase.shared)
        do {
            let fetched = try repository.fetchEntryModes(siteId: siteId)
            await MainActor.run {
                entryModes = fetched
            }
        } catch {
            await MainActor.run {
                entryModes = []
            }
        }
    }
}
