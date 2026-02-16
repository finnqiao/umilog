import SwiftUI
import UmiDesignSystem

struct CollectionCard: View {
    let title: String
    let icon: String
    let count: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)

                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
            }
            .padding(.vertical, 12)
            .frame(width: 110)
            .background(Color.trench)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) collection, \(count) sites")
    }
}

#if DEBUG
struct CollectionCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            CollectionCard(title: "Saved", icon: "heart.fill", count: 12, tint: .pink, action: {})
            CollectionCard(title: "Logged", icon: "checkmark.seal.fill", count: 4, tint: .lagoon, action: {})
        }
        .padding()
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
