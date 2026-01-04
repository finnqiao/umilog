import Foundation
import UmiDB
import os

/// ViewModel for batch-logging past dives
@MainActor
public final class BackfillViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "app.umilog", category: "BackfillViewModel")

    // MARK: - Published Properties

    @Published public var diveEntries: [DiveEntry] = [DiveEntry()]
    @Published public var selectedSite: DiveSite?
    @Published public var useSameSiteForAll = true
    @Published public var isSaving = false
    @Published public var savedCount = 0
    @Published public var showSavedAlert = false
    @Published public var errorMessage: String?
    @Published public var showError = false

    // MARK: - Dependencies

    private let diveRepository: DiveRepository
    private let siteRepository: SiteRepository

    // MARK: - Init

    public init(
        diveRepository: DiveRepository = DiveRepository(database: AppDatabase.shared),
        siteRepository: SiteRepository = SiteRepository(database: AppDatabase.shared)
    ) {
        self.diveRepository = diveRepository
        self.siteRepository = siteRepository
    }

    // MARK: - Entry Management

    public func addEntry() {
        var newEntry = DiveEntry()

        // Auto-populate from last entry
        if let lastEntry = diveEntries.last {
            // Increment date by 1 day
            newEntry.date = Calendar.current.date(byAdding: .day, value: 1, to: lastEntry.date) ?? Date()

            // Copy site if "same for all" is enabled
            if useSameSiteForAll {
                newEntry.siteId = lastEntry.siteId
            }
        }

        diveEntries.append(newEntry)
    }

    public func removeEntry(at index: Int) {
        guard diveEntries.count > 1 else { return }
        diveEntries.remove(at: index)
    }

    public func updateEntrySite(_ siteId: String?, at index: Int) {
        guard index < diveEntries.count else { return }
        diveEntries[index].siteId = siteId

        // Apply to all entries if "same for all" is enabled
        if useSameSiteForAll {
            for i in 0..<diveEntries.count {
                diveEntries[i].siteId = siteId
            }
        }
    }

    // MARK: - Validation

    public var canSave: Bool {
        diveEntries.allSatisfy { entry in
            entry.maxDepth > 0 && entry.bottomTime > 0
        }
    }

    public var totalDives: Int {
        diveEntries.count
    }

    // MARK: - Save

    public func saveAll() async {
        isSaving = true
        savedCount = 0

        for entry in diveEntries {
            do {
                let dive = entry.toDiveLog()

                // Check for duplicates
                if try !diveRepository.hasDuplicate(date: dive.date, maxDepth: dive.maxDepth) {
                    try diveRepository.create(dive)
                    savedCount += 1
                } else {
                    Self.logger.info("Skipped duplicate dive at \(entry.date)")
                }
            } catch {
                Self.logger.error("Failed to save dive: \(error.localizedDescription)")
            }
        }

        isSaving = false

        if savedCount > 0 {
            NotificationCenter.default.post(name: .diveLogUpdated, object: nil)
            showSavedAlert = true
        } else {
            errorMessage = "No new dives were saved (all duplicates)"
            showError = true
        }
    }
}

// MARK: - Dive Entry Model

public struct DiveEntry: Identifiable {
    public let id = UUID()
    public var date: Date = Date()
    public var siteId: String?
    public var maxDepth: Double = 0
    public var bottomTime: Int = 0
    public var temperature: Double = 26.0
    public var visibility: Double = 15.0
    public var notes: String = ""

    public init() {}

    func toDiveLog() -> DiveLog {
        DiveLog(
            siteId: siteId,
            date: date,
            startTime: date,
            endTime: date.addingTimeInterval(TimeInterval(bottomTime * 60)),
            maxDepth: maxDepth,
            bottomTime: bottomTime,
            startPressure: 200,
            endPressure: 50,
            temperature: temperature,
            visibility: visibility,
            notes: notes
        )
    }
}
