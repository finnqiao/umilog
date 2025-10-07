import Foundation

public enum DatabaseSeeder {
    public static func seedSampleData() throws {
        let db = AppDatabase.shared
        
        // Add sample dive sites
        let sites = sampleSites()
        for site in sites {
            try? db.siteRepository.create(site)
        }
        
        // Add sample dives
        let dives = sampleDives(sites: sites)
        for dive in dives {
            try? db.diveRepository.create(dive)
        }
        
        print("✅ Seeded \(sites.count) sites and \(dives.count) dives")
    }
    
    private static func sampleSites() -> [DiveSite] {
        [
            DiveSite(
                name: "Blue Corner",
                location: "Palau",
                latitude: 7.3152,
                longitude: 134.5052,
                region: "Pacific",
                averageDepth: 25,
                maxDepth: 40,
                averageTemp: 28,
                averageVisibility: 30,
                difficulty: .advanced,
                type: .wall,
                description: "Famous wall dive with strong currents and abundant marine life"
            ),
            DiveSite(
                name: "Great Blue Hole",
                location: "Belize",
                latitude: 17.3184,
                longitude: -87.5364,
                region: "Caribbean",
                averageDepth: 35,
                maxDepth: 124,
                averageTemp: 26,
                averageVisibility: 40,
                difficulty: .advanced,
                type: .cave,
                description: "Giant marine sinkhole with stunning underwater formations"
            ),
            DiveSite(
                name: "Barracuda Point",
                location: "Sipadan, Malaysia",
                latitude: 4.1153,
                longitude: 118.6281,
                region: "Indo-Pacific",
                averageDepth: 20,
                maxDepth: 30,
                averageTemp: 27,
                averageVisibility: 35,
                difficulty: .intermediate,
                type: .reef,
                description: "Schooling barracuda and diverse reef life"
            ),
            DiveSite(
                name: "Ras Mohammed",
                location: "Sharm El Sheikh, Egypt",
                latitude: 27.7333,
                longitude: 34.2333,
                region: "Red Sea",
                averageDepth: 18,
                maxDepth: 40,
                averageTemp: 24,
                averageVisibility: 30,
                difficulty: .beginner,
                type: .reef,
                description: "Beautiful coral gardens and colorful fish"
            ),
            DiveSite(
                name: "Koh Bon",
                location: "Similan Islands, Thailand",
                latitude: 9.1044,
                longitude: 97.7933,
                region: "Indo-Pacific",
                averageDepth: 22,
                maxDepth: 35,
                averageTemp: 28,
                averageVisibility: 25,
                difficulty: .intermediate,
                type: .drift,
                description: "Manta ray cleaning stations and drift diving"
            )
        ]
    }
    
    private static func sampleDives(sites: [DiveSite]) -> [DiveLog] {
        guard sites.count >= 2 else { return [] }
        
        let calendar = Calendar.current
        let now = Date()
        
        return [
            DiveLog(
                siteId: sites[0].id,
                date: calendar.date(byAdding: .day, value: -7, to: now)!,
                startTime: calendar.date(byAdding: .day, value: -7, to: now)!,
                maxDepth: 28.5,
                averageDepth: 22.3,
                bottomTime: 45,
                startPressure: 200,
                endPressure: 80,
                temperature: 27.5,
                visibility: 30,
                current: .moderate,
                conditions: .excellent,
                notes: "Amazing wall dive with gray reef sharks and schooling fish. Strong current but incredible visibility."
            ),
            DiveLog(
                siteId: sites[1].id,
                date: calendar.date(byAdding: .day, value: -14, to: now)!,
                startTime: calendar.date(byAdding: .day, value: -14, to: now)!,
                maxDepth: 35.2,
                averageDepth: 30.1,
                bottomTime: 38,
                startPressure: 200,
                endPressure: 90,
                temperature: 26.0,
                visibility: 40,
                current: .light,
                conditions: .excellent,
                notes: "Breathtaking dive into the Blue Hole. Saw stalactites and unique formations."
            ),
            DiveLog(
                siteId: sites[0].id,
                date: calendar.date(byAdding: .day, value: -21, to: now)!,
                startTime: calendar.date(byAdding: .day, value: -21, to: now)!,
                maxDepth: 25.8,
                averageDepth: 20.5,
                bottomTime: 52,
                startPressure: 200,
                endPressure: 70,
                temperature: 28.0,
                visibility: 28,
                current: .strong,
                conditions: .good,
                notes: "Second dive at Blue Corner. Even more marine life today!"
            )
        ]
    }
}
