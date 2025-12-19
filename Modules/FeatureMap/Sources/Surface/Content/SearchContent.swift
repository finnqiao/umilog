import SwiftUI
import UmiDB
import UmiDesignSystem

/// Content view for Search mode in the unified bottom surface.
/// Shows search field and results list.
struct SearchContent: View {
    // MARK: - Properties

    @Binding var query: String
    let sites: [DiveSite]

    var onSelect: (DiveSite) -> Void
    var onDismiss: () -> Void

    // MARK: - State

    @FocusState private var isSearchFocused: Bool
    @State private var hasAppeared = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if query.isEmpty {
                recentSearches
            } else if filteredSites.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .onAppear {
            // Focus the search field on appear (with slight delay for animation)
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSearchFocused = true
                }
            }
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            TextField("Search dive sites...", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        query = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Filtered Sites

    private var filteredSites: [DiveSite] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()
        return sites.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.location.lowercased().contains(lowercased)
        }
        .prefix(20)
        .map { $0 }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredSites) { site in
                    SearchResultRow(site: site) {
                        Haptics.soft()
                        isSearchFocused = false
                        onSelect(site)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Recent Searches (placeholder)

    private var recentSearches: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("Search for dive sites")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Find sites by name or location")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text("No sites found")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 48)
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let site: DiveSite
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(uiColor: .label))

                    Text(site.location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        if site.visitedCount > 0 {
            return Color.oceanBlue
        } else if site.wishlist {
            return Color.yellow
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}
