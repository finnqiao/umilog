import SwiftUI
import UmiCoreKit
import UmiDesignSystem

/// Navigation row that lives at the bottom of the unified dock surface.
/// Has no background of its own — it sits directly on the parent surface
/// so there is one material, one silhouette, one shadow system.
struct DockNavRow: View {

    var body: some View {
        HStack(spacing: 0) {
            discoverItem
            navItem(icon: "clock.fill",   label: "History") {
                NotificationCenter.default.post(
                    name: .switchToTab, object: nil,
                    userInfo: ["tab": "history"]
                )
            }
            logItem
            navItem(icon: "fish.fill",    label: "Wildlife") {
                NotificationCenter.default.post(
                    name: .switchToTab, object: nil,
                    userInfo: ["tab": "wildlife"]
                )
            }
            navItem(icon: "person.fill",  label: "Profile") {
                NotificationCenter.default.post(
                    name: .switchToTab, object: nil,
                    userInfo: ["tab": "profile"]
                )
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Items

    /// Discover is always the active tab when this row is visible.
    private var discoverItem: some View {
        VStack(spacing: 3) {
            Image(systemName: "map.fill")
                .font(.system(size: 20, weight: .medium))
            Text("Discover")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(Color.lagoon)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.lagoon.opacity(0.14), in: Capsule())
    }

    private func navItem(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Color.mist)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var logItem: some View {
        Button {
            NotificationCenter.default.post(name: .showLogLauncher, object: nil)
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.lagoon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }
}
