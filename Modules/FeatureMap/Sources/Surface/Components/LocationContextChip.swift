import SwiftUI
import UmiDesignSystem

struct LocationContextChip: View {
    let title: String
    var onClear: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(Color.lagoon)

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.foam)

            if let onClear {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear location context")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.trench)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Location context: \(title)")
    }
}

#if DEBUG
struct LocationContextChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            LocationContextChip(title: "Near Kona, Hawaii")
            LocationContextChip(title: "Near You", onClear: {})
        }
        .padding()
        .background(Color.midnight)
        .previewLayout(.sizeThatFits)
    }
}
#endif
