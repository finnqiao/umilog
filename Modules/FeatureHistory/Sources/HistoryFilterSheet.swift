import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiCoreKit

/// Filter sheet for the History tab with full filter options.
struct HistoryFilterSheet: View {
    @ObservedObject var viewModel: DiveHistoryViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    mySitesSection
                    difficultySection
                    siteTypeSection
                }
                .padding()
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset", role: .destructive) {
                        viewModel.resetFilters()
                    }
                    .disabled(!viewModel.filters.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .background(Color.abyss.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - My Sites Section

    private var mySitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Sites")
                .font(.headline)

            FlowLayout(spacing: 8) {
                FilterPill(
                    title: "All",
                    isSelected: viewModel.filters.lens == nil,
                    action: { viewModel.setLens(nil) }
                )

                ForEach(FilterLensType.allCases) { lens in
                    FilterPill(
                        title: lens.displayName,
                        icon: lens.iconName,
                        isSelected: viewModel.filters.lens == lens,
                        action: { viewModel.setLens(lens) }
                    )
                }
            }
        }
    }

    // MARK: - Difficulty Section

    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Difficulty")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(DifficultyLevel.allCases) { difficulty in
                    FilterPill(
                        title: difficulty.displayName,
                        isSelected: viewModel.filters.difficulty.contains(difficulty.rawValue),
                        selectedColor: difficultyColor(difficulty.rawValue),
                        action: { viewModel.toggleDifficulty(difficulty.rawValue) }
                    )
                }
            }
        }
    }

    // MARK: - Site Type Section

    private var siteTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Site Type")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(SiteTypeFilter.allCases) { siteType in
                    FilterPill(
                        title: siteType.displayName,
                        icon: siteType.iconName,
                        isSelected: viewModel.filters.siteType.contains(siteType.rawValue),
                        selectedColor: siteTypeColor(siteType.rawValue),
                        action: { viewModel.toggleSiteType(siteType.rawValue) }
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty {
        case "Beginner": return .difficultyBeginner
        case "Intermediate": return .difficultyIntermediate
        case "Advanced": return .difficultyAdvanced
        default: return .lagoon
        }
    }

    private func siteTypeColor(_ siteType: String) -> Color {
        switch siteType {
        case "Wreck": return .amber
        case "Reef": return .reef
        case "Cave": return .trench
        default: return .lagoon
        }
    }
}

#Preview("History Filter Sheet") {
    HistoryFilterSheet(viewModel: DiveHistoryViewModel())
}
