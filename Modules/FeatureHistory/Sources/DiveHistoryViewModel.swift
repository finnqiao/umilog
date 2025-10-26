import Foundation
import SwiftUI
import UmiDB
import UmiCoreKit

@MainActor
public class DiveHistoryViewModel: ObservableObject {
    @Published public var dives: [DiveLog] = []
    @Published public var sites: [String: DiveSite] = [:]
    @Published public var searchText = ""
    @Published public var isLoading = false
    
    private let database = AppDatabase.shared
    private var diveUpdateObserver: NSObjectProtocol?
    
    public init() {
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
            
            print("📊 Loaded \(dives.count) dives")
        } catch {
            print("❌ Error loading dives: \(error)")
        }
    }
    
    public var filteredDives: [DiveLog] {
        if searchText.isEmpty {
            return dives
        }
        
        return dives.filter { dive in
            // Search in notes
            if dive.notes.localizedCaseInsensitiveContains(searchText) {
                return true
            }
            
            // Search in site name/location
            if let site = sites[dive.siteId] {
                return site.name.localizedCaseInsensitiveContains(searchText) ||
                       site.location.localizedCaseInsensitiveContains(searchText)
            }
            
            return false
        }
    }
    
    public func getSite(for dive: DiveLog) -> DiveSite? {
        sites[dive.siteId]
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
                print("❌ Error deleting dive: \(error)")
            }
        }
    }
}
