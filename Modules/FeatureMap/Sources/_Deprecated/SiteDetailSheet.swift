import SwiftUI
import UmiDB
import FeatureLiveLog
import UmiDesignSystem
import UmiCoreKit

public struct SiteDetailSheet: View {
    let site: DiveSite
    let mode: MapMode
    @Environment(\.dismiss) private var dismiss
    @State private var showingWizard = false
    @State private var isWishlist: Bool
    @State private var isUpdatingWishlist = false
    @State private var wishlistError: String?
    
    init(site: DiveSite, mode: MapMode) {
        self.site = site
        self.mode = mode
        _isWishlist = State(initialValue: site.wishlist)
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero image (placeholder)
                    ZStack(alignment: .bottomLeading) {
                        Rectangle()
                            .fill(LinearGradient(colors: [.oceanBlue.opacity(0.6), .diveTeal], startPoint: .top, endPoint: .bottom))
                            .frame(height: 200)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(site.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("\(site.location)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Quick facts chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                QuickFactChip(text: site.difficulty.rawValue)
                                QuickFactChip(text: "Max \(Int(site.maxDepth))m")
                                QuickFactChip(text: "\(Int(site.averageTemp))°C")
                                QuickFactChip(text: "\(Int(site.averageVisibility))m viz")
                                QuickFactChip(text: site.type.rawValue)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Description
                        if let description = site.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                Text(description)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Difficulty strip
                        HStack {
                            Text("Difficulty Level")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(site.difficulty.rawValue)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(difficultyColor(site.difficulty.rawValue))
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        
                        // Primary CTA
                        if mode == .myMap || site.visitedCount > 0 {
                            Button(action: {
                                showingWizard = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Log Dive at \(site.name)")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.oceanBlue)
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 16)
                        } else {
                            Button(action: toggleWishlist) {
                                HStack {
                                    Image(systemName: isWishlist ? "star.slash.fill" : "star.fill")
                                    Text(isWishlist ? "Remove from Wishlist" : "Add to Wishlist")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isWishlist ? Color.gray.opacity(0.6) : Color.yellow)
                                .cornerRadius(16)
                                .overlay {
                                    if isUpdatingWishlist {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .scaleEffect(0.9)
                                            .tint(.white)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .disabled(isUpdatingWishlist)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingWizard) {
            LiveLogWizardView(initialSite: site)
        }
        .alert("Wishlist Error", isPresented: Binding(
            get: { wishlistError != nil },
            set: { if !$0 { wishlistError = nil } }
        )) {
            Button("OK", role: .cancel) { wishlistError = nil }
        } message: {
            Text(wishlistError ?? "")
        }
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }
    
    private func toggleWishlist() {
        guard !isUpdatingWishlist else { return }
        isUpdatingWishlist = true
        let targetId = site.id
        let currentWishlist = isWishlist
        
        Task.detached {
            do {
                let repository = SiteRepository(database: AppDatabase.shared)
                try repository.toggleWishlist(siteId: targetId)
                let newValue = !currentWishlist
                await MainActor.run {
                    self.isWishlist = newValue
                    self.isUpdatingWishlist = false
                    Haptics.soft()
                    NotificationCenter.default.post(
                        name: .wishlistUpdated,
                        object: targetId,
                        userInfo: ["wishlist": newValue]
                    )
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingWishlist = false
                    self.wishlistError = "Couldn't update wishlist. Please try again."
                }
            }
        }
    }
}
