import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit
import FeatureLiveLog
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

                    if detent == .medium, let description = site.description, !description.isEmpty {
                        Text(description)
                            .font(.callout)
                            .foregroundStyle(Color.mist)
                            .lineLimit(4)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }

                if detent == .expanded {
                    expandedContent(site: site)
                }
            }
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
        let imageHeight: CGFloat = detent == .medium ? 100 : 140

        return ZStack(alignment: .bottomLeading) {
            // Use AsyncSiteImage to load actual site photo
            AsyncSiteImage(
                site: site,
                mediaURL: mediaURL,
                size: imageHeight,
                cornerRadius: 12
            )
            .frame(maxWidth: .infinity)
            .frame(height: imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.ocean.opacity(0.3), lineWidth: 1)
            )

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

                // Quick stats at medium/expanded
                if detent != .peek {
                    HStack(spacing: 12) {
                        Label(site.difficulty.rawValue, systemImage: "gauge.medium")
                        Label("\(Int(site.maxDepth))m", systemImage: "arrow.down")
                        Label("\(Int(site.averageTemp))°C", systemImage: "thermometer.medium")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.mist)
                }
            }

            Spacer()
        }
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityHint("Swipe down to dismiss")
    }

    // MARK: - Actions Row

    private func actionsRow(site: DiveSite) -> some View {
        HStack(spacing: 12) {
            // Save button
            ActionButton(
                icon: isWishlist ? "star.fill" : "star",
                title: isWishlist ? "Saved" : "Save",
                isActive: isWishlist,
                isPrimary: false,
                isLoading: isUpdatingWishlist
            ) {
                toggleWishlist(site: site)
            }

            // Plan button
            ActionButton(
                icon: "calendar.badge.plus",
                title: "Plan",
                isActive: false,
                isPrimary: false
            ) {
                onOpenPlan(site.id)
            }

            // Report conditions button
            ActionButton(
                icon: "cloud.sun",
                title: "Report",
                isActive: false,
                isPrimary: false
            ) {
                showingConditionReport = true
            }

            // Log button (primary)
            ActionButton(
                icon: "waveform",
                title: "Log",
                isActive: false,
                isPrimary: true
            ) {
                showingLogWizard = true
            }
        }
    }

    // MARK: - Expanded Content

    private func expandedContent(site: DiveSite) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Description
                if let description = site.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundStyle(Color.foam)
                        Text(description)
                            .font(.body)
                            .foregroundStyle(Color.mist)
                    }
                    .padding(.horizontal, 16)
                }

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
}
