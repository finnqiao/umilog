import SwiftUI

/// Reusable card component matching design system
public struct Card<Content: View>: View {
    private let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

/// Stat card for displaying metrics
public struct StatCard: View {
    let value: String
    let label: String
    let color: Color
    
    public init(value: String, label: String, color: Color = .oceanBlue) {
        self.value = value
        self.label = label
        self.color = color
    }
    
    public var body: some View {
        Card {
            VStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

#Preview("Card") {
    VStack(spacing: 16) {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Card Title")
                    .font(.headline)
                Text("This is a card with some content inside it.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(value: "42", label: "Total Dives", color: .oceanBlue)
            StatCard(value: "35m", label: "Max Depth", color: .diveTeal)
            StatCard(value: "12", label: "Sites Visited", color: .seaGreen)
            StatCard(value: "89", label: "Species Spotted", color: .divePurple)
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
