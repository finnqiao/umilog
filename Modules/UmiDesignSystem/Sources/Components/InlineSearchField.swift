import SwiftUI

/// Inline search field sized to live at the top of a list/browse surface,
/// directly under filter chips. Replaces `.searchable()` where we don't want
/// the iOS 17 system bottom dock placement.
///
/// Plan §7 / §9: consistent top-placed search across History and Wildlife.
public struct InlineSearchField: View {
    @Binding var text: String
    let placeholder: String
    let trailingIcon: String?
    let trailingAction: (() -> Void)?

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String,
        trailingIcon: String? = nil,
        trailingAction: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.trailingIcon = trailingIcon
        self.trailingAction = trailingAction
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.mist.opacity(0.8))

            TextField(placeholder, text: $text)
                .font(.subheadline)
                .foregroundStyle(Color.foam)
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                    Haptics.soft()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.mist.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            if let trailingIcon, let trailingAction {
                Divider()
                    .frame(height: 20)
                    .overlay(Color.mist.opacity(0.2))
                Button(action: {
                    trailingAction()
                    Haptics.soft()
                }) {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.lagoon)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.trench.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isFocused ? Color.lagoon.opacity(0.5) : Color.mist.opacity(0.12),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview("InlineSearchField") {
    struct PreviewWrapper: View {
        @State private var text = ""
        var body: some View {
            VStack(spacing: 16) {
                InlineSearchField(text: $text, placeholder: "Search dives, sites, or notes")
                InlineSearchField(
                    text: $text,
                    placeholder: "Search species",
                    trailingIcon: "line.3.horizontal.decrease",
                    trailingAction: {}
                )
            }
            .padding()
            .background(Color.abyss)
        }
    }
    return PreviewWrapper()
}
