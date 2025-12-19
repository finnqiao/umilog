import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit
import FeatureLiveLog

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

    // MARK: - State

    @State private var isWishlist: Bool
    @State private var isUpdatingWishlist = false
    @State private var wishlistError: String?
    @State private var showingLogWizard = false

    // MARK: - Init

    init(
        context: SiteInspectionContext,
        site: DiveSite?,
        detent: SurfaceDetent,
        onDismiss: @escaping () -> Void,
        onLog: @escaping () -> Void = {},
        onSave: @escaping () -> Void = {}
    ) {
        self.context = context
        self.site = site
        self.detent = detent
        self.onDismiss = onDismiss
        self.onLog = onLog
        self.onSave = onSave
        _isWishlist = State(initialValue: site?.wishlist ?? false)
    }

    // MARK: - Body

    var body: some View {
        if let site = site {
            VStack(alignment: .leading, spacing: 0) {
                siteHeader(site: site)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                if detent == .medium || detent == .expanded {
                    actionsRow(site: site)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                if detent == .expanded {
                    expandedContent(site: site)
                }
            }
            .sheet(isPresented: $showingLogWizard) {
                LiveLogWizardView(initialSite: site)
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
                    .foregroundStyle(.primary)

                Text(site.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Quick stats at medium/expanded
                if detent != .peek {
                    HStack(spacing: 12) {
                        Label(site.difficulty.rawValue, systemImage: "gauge.medium")
                        Label("\(Int(site.maxDepth))m", systemImage: "arrow.down")
                        Label("\(Int(site.averageTemp))°C", systemImage: "thermometer.medium")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
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

            // Plan button (future feature)
            ActionButton(
                icon: "calendar",
                title: "Plan",
                isActive: false,
                isPrimary: false
            ) {
                // Future: open trip planner
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
            VStack(alignment: .leading, spacing: 20) {
                // Hero image placeholder
                ZStack(alignment: .bottomLeading) {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.oceanBlue.opacity(0.6), .diveTeal],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)

                // Quick facts chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        QuickFactChip(text: site.difficulty.rawValue)
                        QuickFactChip(text: "Max \(Int(site.maxDepth))m")
                        QuickFactChip(text: "\(Int(site.averageTemp))°C")
                        QuickFactChip(text: "\(Int(site.averageVisibility))m viz")
                        QuickFactChip(text: site.type.rawValue)
                    }
                    .padding(.horizontal, 16)
                }

                // Description
                if let description = site.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                }

                // Difficulty strip
                HStack {
                    Text("Difficulty Level")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(site.difficulty.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(difficultyColor(site.difficulty.rawValue))
                }
                .padding(16)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Not Found View

    private var notFoundView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("Site not found")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button("Dismiss", action: onDismiss)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
    }

    // MARK: - Helpers

    private func statusColor(for site: DiveSite) -> Color {
        if site.visitedCount > 0 {
            return .green
        } else if site.wishlist {
            return .blue
        } else {
            return .gray.opacity(0.5)
        }
    }

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }

    private func toggleWishlist(site: DiveSite) {
        guard !isUpdatingWishlist else { return }
        isUpdatingWishlist = true
        let targetId = site.id
        let currentWishlist = isWishlist

        Task.detached {
            do {
                let repository = SiteRepository(database: AppDatabase.shared)
                try repository.toggleWishlist(siteId: targetId)
                let newValue = !currentWishlist
                await MainActor.run {
                    self.isWishlist = newValue
                    self.isUpdatingWishlist = false
                    Haptics.soft()
                    NotificationCenter.default.post(
                        name: .wishlistUpdated,
                        object: targetId,
                        userInfo: ["wishlist": newValue]
                    )
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingWishlist = false
                    self.wishlistError = "Couldn't update wishlist. Please try again."
                }
            }
        }
    }
}
