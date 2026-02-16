import SwiftUI
import UmiDB
import UmiDesignSystem

/// Content view for Filter mode in the unified bottom surface.
/// Shows filter options for My Sites lens, difficulty, site type, and shops.
struct FilterContent: View {
    // MARK: - Properties

    @Binding var exploreFilters: ExploreFilters
    @Binding var filterLens: FilterLens?

    var onApply: () -> Void
    var onCancel: () -> Void

    // MARK: - Local State (for editing before apply)

    @State private var localFilters: ExploreFilters
    @State private var localLens: FilterLens?

    // MARK: - Init

    init(
        exploreFilters: Binding<ExploreFilters>,
        filterLens: Binding<FilterLens?>,
        onApply: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _exploreFilters = exploreFilters
        _filterLens = filterLens
        _localFilters = State(initialValue: exploreFilters.wrappedValue)
        _localLens = State(initialValue: filterLens.wrappedValue)
        self.onApply = onApply
        self.onCancel = onCancel
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            // Filter sections
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    mySitesSection
                    difficultySection
                    siteTypeSection
                    timePeriodSection
                    depthRangeSection
                    entryTypeSection
                    shopsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }

            // Footer
            footer
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Filters")
                .font(.headline)
                .foregroundStyle(Color.foam)
            Spacer()
            Button("Cancel") {
                onCancel()
            }
            .foregroundStyle(Color.mist)
            .accessibilityLabel("Cancel filter changes")
        }
    }

    // MARK: - My Sites Section

    private var mySitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Sites")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.mist)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                lensChip(title: "All", lens: nil, isSelected: localLens == nil)

                ForEach(FilterLens.allCases, id: \.self) { lens in
                    lensChip(title: lens.displayName, lens: lens, isSelected: localLens == lens)
                }
            }
        }
    }

    private func lensChip(title: String, lens: FilterLens?, isSelected: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                localLens = lens
            }
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.foam : Color.mist)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.lagoon : Color.trench)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Difficulty Section

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Difficulty")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.mist)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: 8) {
                ForEach(DiveSite.Difficulty.allCases, id: \.self) { difficulty in
                    filterChip(
                        title: difficulty.rawValue,
                        isSelected: localFilters.difficulty.contains(difficulty)
                    ) {
                        toggleDifficulty(difficulty)
                    }
                }
            }
        }
    }

    private func toggleDifficulty(_ difficulty: DiveSite.Difficulty) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if localFilters.difficulty.contains(difficulty) {
                localFilters.difficulty.remove(difficulty)
            } else {
                localFilters.difficulty.insert(difficulty)
            }
        }
    }

    // MARK: - Site Type Section

    private var siteTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Site Type")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.mist)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: 8) {
                ForEach(DiveSite.SiteType.allCases, id: \.self) { siteType in
                    filterChip(
                        title: siteType.rawValue,
                        isSelected: localFilters.siteType.contains(siteType)
                    ) {
                        toggleSiteType(siteType)
                    }
                }
            }
        }
    }

    private func toggleSiteType(_ siteType: DiveSite.SiteType) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if localFilters.siteType.contains(siteType) {
                localFilters.siteType.remove(siteType)
            } else {
                localFilters.siteType.insert(siteType)
            }
        }
    }

    // MARK: - Time Period Section (Resy-style)

    private var timePeriodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Period")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.mist)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                ForEach(ExploreFilters.TimePeriod.allCases, id: \.self) { period in
                    filterChip(
                        title: period.rawValue,
                        isSelected: localFilters.timePeriod == period
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            localFilters.timePeriod = period
                        }
                    }
                }
            }
        }
    }

    // MARK: - Depth Range Section (Resy-style)

    private var depthRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Depth Range")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.mist)
                .accessibilityAddTraits(.isHeader)

            FlowLayout(spacing: 8) {
                ForEach(ExploreFilters.DepthRange.allCases, id: \.self) { range in
                    filterChip(
                        title: range.rawValue,
                        isSelected: localFilters.depthRanges.contains(range)
                    ) {
                        toggleDepthRange(range)
                    }
                }
            }
        }
    }

    private func toggleDepthRange(_ range: ExploreFilters.DepthRange) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if localFilters.depthRanges.contains(range) {
                localFilters.depthRanges.remove(range)
            } else {
                localFilters.depthRanges.insert(range)
            }
        }
    }

    // MARK: - Entry Type Section (Resy-style)

    private var entryTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Entry Type")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.mist)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                ForEach(ExploreFilters.EntryType.allCases, id: \.self) { type in
                    filterChip(
                        title: type.rawValue,
                        isSelected: localFilters.entryType.contains(type)
                    ) {
                        toggleEntryType(type)
                    }
                }
            }
        }
    }

    private func toggleEntryType(_ type: ExploreFilters.EntryType) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if localFilters.entryType.contains(type) {
                localFilters.entryType.remove(type)
            } else {
                localFilters.entryType.insert(type)
            }
        }
    }

    // MARK: - Shops Section

    private var shopsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dive Shops")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.foam)
                    .accessibilityAddTraits(.isHeader)
                Text("Show dive shop locations on the map")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }
            Spacer()
            Toggle("", isOn: $localFilters.showShops)
                .labelsHidden()
                .tint(Color.lagoon)
        }
        .padding(16)
        .background(Color.trench)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Filter Chip

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            // Announce state change to VoiceOver
            let announcement = isSelected ? "\(title) filter disabled" : "\(title) filter enabled"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                Text(title)
                    .font(.subheadline)
            }
            .foregroundStyle(isSelected ? Color.foam : Color.mist)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.lagoon : Color.trench)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter")
        .accessibilityValue(isSelected ? "enabled" : "disabled")
        .accessibilityHint("Double tap to toggle")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.ocean.opacity(0.3))

            HStack {
                Button("Reset") {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        localFilters = .default
                        localLens = nil
                    }
                }
                .foregroundStyle(Color.danger)
                .accessibilityLabel("Reset all filters")

                Spacer()

                if activeCount > 0 {
                    Text("\(activeCount) active")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                        .accessibilityLabel("\(activeCount) filters active")
                }

                Button(action: applyFilters) {
                    Text("Apply")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.lagoon)
                .accessibilityLabel("Apply filters")
            }
            .padding(16)
        }
    }

    private var activeCount: Int {
        var count = localFilters.activeCount
        if localLens != nil { count += 1 }
        return count
    }

    private func applyFilters() {
        exploreFilters = localFilters
        filterLens = localLens
        onApply()
    }
}

// MARK: - Flow Layout

/// Simple flow layout for wrapping chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = flowLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func flowLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

