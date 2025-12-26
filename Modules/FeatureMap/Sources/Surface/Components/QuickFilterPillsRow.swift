import SwiftUI
import UmiDB
import UmiDesignSystem

/// Horizontal scrollable row of quick filter pills for the Explore view.
/// Allows users to quickly toggle lens and difficulty filters.
struct QuickFilterPillsRow: View {
    // MARK: - Properties

    @Binding var filterLens: FilterLens?
    @Binding var difficulties: Set<DiveSite.Difficulty>

    // MARK: - Body

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Lens pills
                lensPill(title: "All", lens: nil)
                ForEach(FilterLens.allCases, id: \.self) { lens in
                    lensPill(title: lens.displayName, lens: lens)
                }

                // Divider
                Capsule()
                    .fill(Color.ocean.opacity(0.3))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 4)

                // Difficulty pills
                ForEach(DiveSite.Difficulty.allCases, id: \.self) { difficulty in
                    difficultyPill(difficulty: difficulty)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Lens Pill

    private func lensPill(title: String, lens: FilterLens?) -> some View {
        let isSelected = filterLens == lens

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                filterLens = lens
            }
            Haptics.soft()
        } label: {
            HStack(spacing: 4) {
                if let lens = lens {
                    Image(systemName: lens.iconName)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? Color.foam : Color.mist)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.lagoon : Color.trench)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Difficulty Pill

    private func difficultyPill(difficulty: DiveSite.Difficulty) -> some View {
        let isSelected = difficulties.contains(difficulty)

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                if isSelected {
                    difficulties.remove(difficulty)
                } else {
                    difficulties.insert(difficulty)
                }
            }
            Haptics.soft()
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                Text(difficulty.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? Color.foam : Color.mist)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? difficultyColor(difficulty) : Color.trench)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(difficulty.rawValue) difficulty filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func difficultyColor(_ difficulty: DiveSite.Difficulty) -> Color {
        switch difficulty {
        case .beginner:
            return Color.difficultyBeginner
        case .intermediate:
            return Color.difficultyIntermediate
        case .advanced:
            return Color.difficultyAdvanced
        }
    }
}

#if DEBUG
struct QuickFilterPillsRow_Previews: PreviewProvider {
    static var previews: some View {
        QuickFilterPillsRow(
            filterLens: .constant(.saved),
            difficulties: .constant([.beginner])
        )
        .padding()
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
