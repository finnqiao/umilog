import SwiftUI
import UmiDesignSystem
import UmiDB

/// A compact prompt card that appears when the user enters a dive site's geofence.
/// Offers quick access to start logging a dive at the current location.
struct ProximityPromptCard: View {
    let state: ProximityPromptState
    var onAccept: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Site info
            VStack(alignment: .leading, spacing: 2) {
                Text("You're at")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
                Text(state.site.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.mist)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.kelp.opacity(0.5))
                        )
                }
                .accessibilityLabel("Dismiss")

                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Log")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(Color.abyss)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.reef)
                    )
                }
                .accessibilityLabel("Start logging dive at \(state.site.name)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.reef.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dive site proximity alert: You're at \(state.site.name)")
    }
}

#Preview {
    ZStack {
        Color.abyss
        VStack {
            Spacer()
            ProximityPromptCard(
                state: ProximityPromptState(
                    site: DiveSite(
                        id: "preview",
                        name: "Blue Corner",
                        location: "Palau",
                        latitude: 7.0,
                        longitude: 134.0,
                        region: "Micronesia",
                        averageDepth: 20.0,
                        maxDepth: 35.0,
                        averageTemp: 28.0,
                        averageVisibility: 30.0,
                        type: .reef
                    )
                ),
                onAccept: { print("Accept") },
                onDismiss: { print("Dismiss") }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 200)
        }
    }
}
