import Foundation
import SwiftUI
import UmiDB

@MainActor
public class DashboardViewModel: ObservableObject {
    @Published public var stats: DiveStats = .zero
    @Published public var recentDives: [DiveLog] = []
    @Published public var isLoading = false
    @Published public var error: String?
    
    private let database = AppDatabase.shared
    
    public init() {
        Task {
            await loadData()
        }
    }
    
    public func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load stats
            stats = try database.diveRepository.calculateStats()
            
            // Load recent dives
            recentDives = try database.diveRepository.fetchRecent(limit: 5)
            
            print("📊 Loaded stats: \(stats.totalDives) dives")
        } catch {
            self.error = "Failed to load data: \(error.localizedDescription)"
            print("❌ Error loading data: \(error)")
        }
    }
    
    public func refresh() async {
        await loadData()
    }
    
    public func seedSampleData() async {
        do {
            try DatabaseSeeder.seedIfNeeded()
            await loadData()
        } catch {
            self.error = "Failed to seed data: \(error.localizedDescription)"
        }
    }
}
