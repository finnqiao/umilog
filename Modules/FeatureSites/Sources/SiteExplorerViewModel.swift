import Foundation
import SwiftUI
import UmiDB

@MainActor
public class SiteExplorerViewModel: ObservableObject {
    @Published public var sites: [DiveSite] = []
    @Published public var searchText = ""
    @Published public var isLoading = false
    @Published public var filter: SiteFilter = .all
    
    private let database = AppDatabase.shared
    
    public enum SiteFilter: String, CaseIterable {
        case all = "All Sites"
        case visited = "Visited"
        case wishlist = "Wishlist"
    }
    
    public init() {
        Task {
            await loadSites()
        }
    }
    
    public func loadSites() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            sites = try database.siteRepository.fetchAll()
            print("📊 Loaded \(sites.count) sites")
        } catch {
            print("❌ Error loading sites: \(error)")
        }
    }
    
    public var filteredSites: [DiveSite] {
        var filtered = sites
        
        // Apply filter
        switch filter {
        case .all:
            break
        case .visited:
            filtered = filtered.filter { $0.visitedCount > 0 }
        case .wishlist:
            filtered = filtered.filter { $0.wishlist }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { site in
                site.name.localizedCaseInsensitiveContains(searchText) ||
                site.location.localizedCaseInsensitiveContains(searchText) ||
                site.region.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    public func toggleWishlist(site: DiveSite) async {
        do {
            try database.siteRepository.toggleWishlist(siteId: site.id)
            await loadSites()
        } catch {
            print("❌ Error toggling wishlist: \(error)")
        }
    }
    
    public func refresh() async {
        await loadSites()
    }
}
