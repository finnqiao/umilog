import Foundation
import SwiftUI
import UmiDB
import UmiCoreKit
import os

@MainActor
public class DiveHistoryViewModel: ObservableObject {
    @Published public var dives: [DiveLog] = []
    @Published public var sites: [String: DiveSite] = [:]
    @Published public var searchText = ""
    @Published public var isLoading = false

    // Filter state
    @Published public var filters: UnifiedFilters {
        didSet {
            FilterPersistence.shared.saveHistoryFilters(filters)
        }
    }

    private let database = AppDatabase.shared
    private var diveUpdateObserver: NSObjectProtocol?

    public init() {
        // Load persisted filters
        self.filters = FilterPersistence.shared.loadHistoryFilters()

        Task { [weak self] in
            guard let self else { return }
            await self.loadData()
        }

        diveUpdateObserver = NotificationCenter.default.addObserver(
            forName: .diveLogUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                await self.loadData()
            }
        }
    }
    
    deinit {
        if let diveUpdateObserver {
            NotificationCenter.default.removeObserver(diveUpdateObserver)
        }
    }
    
    public func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load all dives
            dives = try database.diveRepository.fetchAll()
            
            // Load sites for lookup
            let allSites = try database.siteRepository.fetchAll()
            sites = Dictionary(uniqueKeysWithValues: allSites.map { ($0.id, $0) })
            
            let count = dives.count
            Log.diveLog.debug("Loaded \(count) dives")
        } catch {
            Log.diveLog.error("Error loading dives: \(error.localizedDescription)")
        }
    }
    
    public var filteredDives: [DiveLog] {
        var result = dives

        // Apply text search
        if !searchText.isEmpty {
            result = result.filter { dive in
                // Search in notes
                if dive.notes.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                // Search in site name/location
                if let siteId = dive.siteId, let site = sites[siteId] {
                    return site.name.localizedCaseInsensitiveContains(searchText) ||
                           site.location.localizedCaseInsensitiveContains(searchText)
                }
                return false
            }
        }

        // Apply filter lens (My Sites)
        if let lens = filters.lens {
            result = result.filter { dive in
                guard let siteId = dive.siteId, let site = sites[siteId] else { return false }
                switch lens {
                case .saved:
                    return site.wishlist
                case .logged:
                    return site.visitedCount > 0
                case .planned:
                    return site.isPlanned
                }
            }
        }

        // Apply difficulty filter
        if !filters.difficulty.isEmpty {
            result = result.filter { dive in
                guard let siteId = dive.siteId, let site = sites[siteId] else { return false }
                return filters.difficulty.contains(site.difficulty.rawValue)
            }
        }

        // Apply site type filter
        if !filters.siteType.isEmpty {
            result = result.filter { dive in
                guard let siteId = dive.siteId, let site = sites[siteId] else { return false }
                return filters.siteType.contains(site.type.rawValue)
            }
        }

        // Apply depth range filter
        if let depthRange = filters.maxDepthRange {
            result = result.filter { dive in
                depthRange.contains(dive.maxDepth)
            }
        }

        return result
    }

    // MARK: - Filter Helpers

    public func toggleDifficulty(_ difficulty: String) {
        if filters.difficulty.contains(difficulty) {
            filters.difficulty.remove(difficulty)
        } else {
            filters.difficulty.insert(difficulty)
        }
    }

    public func toggleSiteType(_ siteType: String) {
        if filters.siteType.contains(siteType) {
            filters.siteType.remove(siteType)
        } else {
            filters.siteType.insert(siteType)
        }
    }

    public func setLens(_ lens: FilterLensType?) {
        filters.lens = lens
    }

    public func resetFilters() {
        filters.reset()
    }

    public func getSite(for dive: DiveLog) -> DiveSite? {
        guard let siteId = dive.siteId else { return nil }
        return sites[siteId]
    }
    
    public func refresh() async {
        await loadData()
    }
    
    public func deleteDive(_ dive: DiveLog) {
        Task {
            do {
                try database.diveRepository.delete(id: dive.id)
                await loadData()
            } catch {
                Log.diveLog.error("Error deleting dive: \(error.localizedDescription)")
            }
        }
    }
}
