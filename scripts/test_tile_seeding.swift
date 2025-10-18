#!/usr/bin/env swift

import Foundation

// Test script to verify tile-based seeding works correctly.
// Run with: swift scripts/test_tile_seeding.swift

// Decodable models matching DatabaseSeeder
struct TileManifest: Decodable {
    let version: String
    let generated_at: String
    let tiles: [TileMetadata]
    let summary: TileSummary
}

struct TileMetadata: Decodable {
    let name: String
    let region: String
    let count: Int
    let size_uncompressed_kb: Double
    let size_compressed_kb: Double
}

struct TileSummary: Decodable {
    let total_sites: Int
    let total_regions: Int
    let total_size_uncompressed_mb: Double
    let total_size_compressed_mb: Double
}

struct RegionalTile: Decodable {
    let region: String
    let sites: [OptimizedSite]
}

struct OptimizedSite: Decodable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let region: String
    let maxDepth: Int
}

// Test manifest
func testManifestLoading() throws {
    print("🧪 Testing tile manifest loading...")
    
    let manifestPath = "Resources/SeedData/optimized/tiles/manifest.json"
    guard FileManager.default.fileExists(atPath: manifestPath) else {
        throw NSError(domain: "FileNotFound", code: 1, userInfo: [NSLocalizedDescriptionKey: "Manifest not found at \(manifestPath)"])
    }
    
    let data = try Data(contentsOf: URL(fileURLWithPath: manifestPath))
    let manifest = try JSONDecoder().decode(TileManifest.self, from: data)
    
    print("✅ Manifest loaded successfully")
    print("  Version: \(manifest.version)")
    print("  Generated: \(manifest.generated_at)")
    print("  Total sites: \(manifest.summary.total_sites)")
    print("  Regions: \(manifest.summary.total_regions)")
    print("  Uncompressed: \(String(format: "%.1f", manifest.summary.total_size_uncompressed_mb))MB")
    print("  Compressed: \(String(format: "%.1f", manifest.summary.total_size_compressed_mb))MB")
}

// Test individual tile loading
func testTileLoading() throws {
    print("\n🧪 Testing regional tile loading...")
    
    let tiles = ["australia-pacific-islands", "caribbean-atlantic", "mediterranean", "north-atlantic-arctic", "red-sea-indian-ocean"]
    var totalSites = 0
    
    for tileName in tiles {
        let tilePath = "Resources/SeedData/optimized/tiles/\(tileName).json"
        
        guard FileManager.default.fileExists(atPath: tilePath) else {
            print("⚠️  Tile not found: \(tilePath)")
            continue
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: tilePath))
        let tile = try JSONDecoder().decode(RegionalTile.self, from: data)
        
        totalSites += tile.sites.count
        print("✅ \(tile.region): \(tile.sites.count) sites")
        
        // Sample first site
        if let firstSite = tile.sites.first {
            print("   Sample: \(firstSite.name) (\(firstSite.latitude), \(firstSite.longitude))")
        }
    }
    
    print("\n✅ Total sites loaded: \(totalSites)")
}

// Coordinate validation
func testCoordinateValidation() throws {
    print("\n🧪 Testing coordinate validation...")
    
    let tiles = ["australia-pacific-islands", "caribbean-atlantic", "mediterranean", "north-atlantic-arctic", "red-sea-indian-ocean"]
    var invalidCoords = 0
    var totalCoords = 0
    
    for tileName in tiles {
        let tilePath = "Resources/SeedData/optimized/tiles/\(tileName).json"
        let data = try Data(contentsOf: URL(fileURLWithPath: tilePath))
        let tile = try JSONDecoder().decode(RegionalTile.self, from: data)
        
        for site in tile.sites {
            totalCoords += 1
            
            // Validate bounds
            if site.latitude < -90 || site.latitude > 90 || site.longitude < -180 || site.longitude > 180 {
                invalidCoords += 1
                print("❌ Invalid coordinates for \(site.name): \(site.latitude), \(site.longitude)")
            }
        }
    }
    
    print("✅ Coordinate validation: \(totalCoords) sites, \(invalidCoords) invalid")
    if invalidCoords == 0 {
        print("✅ All coordinates valid!")
    }
}

// Run tests
do {
    try testManifestLoading()
    try testTileLoading()
    try testCoordinateValidation()
    print("\n🎉 All tests passed!")
} catch {
    print("❌ Test failed: \(error.localizedDescription)")
    exit(1)
}
