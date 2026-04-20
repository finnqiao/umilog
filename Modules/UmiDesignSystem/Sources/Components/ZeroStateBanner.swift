import SwiftUI

/// Reusable dismissible zero-state banner with title, optional body, primary
/// CTA, optional secondary link. Dismissal persists via `@AppStorage(storageKey)`.
///
/// Plan §5 / §7: one primary action per surface, not a passive "empty" screen.
public struct ZeroStateBanner: View {
    let title: String
    let message: String?
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    let storageKey: String

    @AppStorage private var dismissed: Bool

    public init(
        title: String,
        message: String? = nil,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        storageKey: String
    ) {
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.storageKey = storageKey
        self._dismissed = AppStorage(wrappedValue: false, storageKey)
    }

    public var body: some View {
        if !dismissed {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.foam)
                        if let message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(Color.mist)
                        }
                    }
                    Spacer()
                    Button {
                        dismissed = true
                        Haptics.soft()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.mist.opacity(0.8))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }

                HStack(spacing: 12) {
                    Button {
                        primaryAction()
                        Haptics.tap()
                    } label: {
                        Text(primaryTitle)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.foam)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.lagoon)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if let secondaryTitle, let secondaryAction {
                        Button {
                            secondaryAction()
                            Haptics.soft()
                        } label: {
                            Text(secondaryTitle)
                                .font(.footnote)
                                .foregroundStyle(Color.lagoon)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.trench.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.lagoon.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    ZeroStateBanner(
        title: "Start logging to build your species collection",
        message: "Log dives with sightings to track what you've seen.",
        primaryTitle: "Log a dive",
        primaryAction: {},
        secondaryTitle: "Browse common reef species",
        secondaryAction: {},
        storageKey: "preview.zerostate"
    )
    .padding()
    .background(Color.abyss)
}
