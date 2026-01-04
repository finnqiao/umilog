import Foundation
import UmiDB

/// Helper for creating in-memory test databases
enum TestDatabase {
    /// Create a fresh in-memory database for testing
    static func makeInMemory() throws -> AppDatabase {
        try AppDatabase(inMemory: true)
    }

    /// Create a test dive site
    static func makeSite(
        id: String = UUID().uuidString,
        name: String = "Test Dive Site",
        latitude: Double = 27.5,
        longitude: Double = 33.8,
        region: String = "Red Sea",
        maxDepth: Double = 30.0,
        difficulty: DiveSite.Difficulty = .intermediate
    ) -> DiveSite {
        DiveSite(
            id: id,
            name: name,
            location: "Test Location",
            latitude: latitude,
            longitude: longitude,
            region: region,
            averageDepth: maxDepth * 0.7,
            maxDepth: maxDepth,
            averageTemp: 26.0,
            averageVisibility: 20.0,
            difficulty: difficulty,
            type: .reef,
            description: "A test dive site",
            wishlist: false,
            visitedCount: 0,
            createdAt: Date()
        )
    }

    /// Create a test dive log
    static func makeDive(
        id: String = UUID().uuidString,
        siteId: String,
        date: Date = Date(),
        maxDepth: Double = 25.0,
        bottomTime: Int = 45
    ) -> DiveLog {
        DiveLog(
            id: id,
            siteId: siteId,
            date: date,
            startTime: date,
            endTime: date.addingTimeInterval(TimeInterval(bottomTime * 60)),
            maxDepth: maxDepth,
            averageDepth: maxDepth * 0.7,
            bottomTime: bottomTime,
            startPressure: 200,
            endPressure: 50,
            temperature: 26.0,
            visibility: 20.0,
            current: .light,
            conditions: .good,
            notes: "Test dive",
            instructorName: nil,
            instructorNumber: nil,
            signed: false,
            createdAt: date,
            updatedAt: date
        )
    }
}
