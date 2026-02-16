import Foundation
import SwiftUI
import UmiDB
import UmiCoreKit
import os

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
            
            let totalDives = stats.totalDives
            Log.app.debug("Loaded stats: \(totalDives) dives")
        } catch {
            self.error = "Failed to load data: \(error.localizedDescription)"
            Log.app.error("Error loading data: \(error.localizedDescription)")
        }
    }
    
    public func refresh() async {
        await loadData()
    }
    
    public func seedSampleData() async {
        do {
            try DatabaseSeeder.seedOrRefreshIfNeeded()
            await loadData()
        } catch {
            self.error = "Failed to seed data: \(error.localizedDescription)"
        }
    }
}
