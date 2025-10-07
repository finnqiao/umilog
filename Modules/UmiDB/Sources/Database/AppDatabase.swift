import Foundation
import GRDB

/// Main database manager for UmiLog
public final class AppDatabase {
    private let dbPool: DatabasePool
    
    public static let shared: AppDatabase = {
        do {
            return try AppDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }()
    
    private init() throws {
        let fileManager = FileManager.default
        let documentsPath = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbPath = documentsPath.appendingPathComponent("umilog.db").path
        
        print("📊 Database path: \(dbPath)")
        
        // Configure database
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            
            // WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")
            
            // TODO: Add SQLCipher encryption
            // let key = try KeychainService.getDatabaseKey()
            // try db.usePassphrase(key)
        }
        
        // Create database pool
        dbPool = try DatabasePool(path: dbPath, configuration: config)
        
        // Run migrations
        try dbPool.write { db in
            try DatabaseMigrator.migrate(db)
        }
        
        print("✅ Database initialized successfully")
    }
    
    // MARK: - Database Access
    
    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try dbPool.read(block)
    }
    
    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        try dbPool.write(block)
    }
    
    public func asyncWrite(_ block: @escaping (Database) throws -> Void) {
        dbPool.asyncWrite(block, completion: { _, result in
            if case .failure(let error) = result {
                print("❌ Database write error: \(error)")
            }
        })
    }
}

// MARK: - Repository Access
extension AppDatabase {
    public var diveRepository: DiveRepository {
        DiveRepository(database: self)
    }
    
    public var siteRepository: SiteRepository {
        SiteRepository(database: self)
    }
}
