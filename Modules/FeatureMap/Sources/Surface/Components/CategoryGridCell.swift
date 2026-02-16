import SwiftUI
import UmiDesignSystem

struct CategoryGridCell: View {
    let category: SearchCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(isSelected ? 0.25 : 0.15))
                        .frame(width: 30, height: 30)

                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(category.color)
                }

                Text(category.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Color.mist.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.trench.opacity(0.8) : Color.trench)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.displayName) category")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
struct CategoryGridCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            CategoryGridCell(category: .wrecks, isSelected: false, action: {})
            CategoryGridCell(category: .nightDiving, isSelected: true, action: {})
        }
        .padding()
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
