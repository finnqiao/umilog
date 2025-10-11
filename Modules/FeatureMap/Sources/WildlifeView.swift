import SwiftUI
import UmiDB

public struct WildlifeView: View {
    @State private var searchText = ""
    @State private var scope: WildlifeScope = .allTime
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Scope chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ScopeChip(title: "All-time", isSelected: scope == .allTime) {
                        scope = .allTime
                    }
                    ScopeChip(title: "This area", isSelected: scope == .thisArea) {
                        scope = .thisArea
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            
            // Placeholder content
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(0..<6) { index in
                        SpeciesCard(name: "Species \(index + 1)", seen: index % 2 == 0)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Wildlife")
        .searchable(text: $searchText, prompt: "Search species...")
    }
}

struct ScopeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SwiftUI.Font.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.purple : Color.gray.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct SpeciesCard: View {
    let name: String
    let seen: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(seen ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "fish.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(seen ? .purple : .gray)
            }
            
            Text(name)
                .font(SwiftUI.Font.subheadline)
                .fontWeight(.medium)
            
            if seen {
                Text("Seen 3x")
                    .font(SwiftUI.Font.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

enum WildlifeScope {
    case allTime, thisArea
}
