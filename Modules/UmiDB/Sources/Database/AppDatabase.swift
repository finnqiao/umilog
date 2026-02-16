import Foundation
import GRDB
import os

private let logger = Logger(subsystem: "com.umilog", category: "Database")

/// Main database manager for UmiLog
public final class AppDatabase {
    private let dbPool: DatabasePool

    /// Backing store for the shared instance
    private static var _shared: AppDatabase?

    /// Returns the shared database instance.
    /// - Important: Call `initialize()` during app startup before accessing this property.
    public static var shared: AppDatabase {
        guard let instance = _shared else {
            // This is a programming error - initialize() was not called
            fatalError("AppDatabase.shared accessed before initialize() was called")
        }
        return instance
    }

    /// Initializes the shared database instance.
    /// Call this during app startup and handle errors appropriately.
    /// - Throws: Database initialization errors
    public static func initialize() throws {
        guard _shared == nil else { return }
        _shared = try AppDatabase()
    }

    /// Returns true if the database has been initialized
    public static var isInitialized: Bool {
        _shared != nil
    }

    /// Create an in-memory database for testing
    /// - Parameter inMemory: If true, creates an in-memory database
    public init(inMemory: Bool) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let fileManager = FileManager.default
        if inMemory {
            // DatabasePool requires WAL mode, which is unsupported on :memory: databases.
            // Use an isolated temp file for tests to preserve DatabasePool behavior.
            let temporaryPath = fileManager.temporaryDirectory
                .appendingPathComponent("umilog-tests-\(UUID().uuidString).sqlite")
                .path
            dbPool = try DatabasePool(path: temporaryPath, configuration: config)
        } else {
            let documentsPath = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dbPath = documentsPath.appendingPathComponent("umilog.db").path
            dbPool = try DatabasePool(path: dbPath, configuration: config)
        }

        try DatabaseMigrator.migrate(dbPool)
    }

    private init() throws {
        let fileManager = FileManager.default
        let documentsPath = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbPath = documentsPath.appendingPathComponent("umilog.db").path

        logger.info("Database path: \(dbPath, privacy: .private)")

        // Copy pre-bundled seed database if app database doesn't exist
        if !fileManager.fileExists(atPath: dbPath) {
            if let bundledPath = Bundle.main.path(forResource: "umilog_seed", ofType: "db") {
                do {
                    try fileManager.copyItem(atPath: bundledPath, toPath: dbPath)
                    logger.info("Copied pre-bundled seed database to Documents")
                } catch {
                    logger.error("Failed to copy pre-bundled database: \(error.localizedDescription)")
                    // Fall through to normal initialization - seeder will populate from JSON
                }
            } else {
                logger.info("No pre-bundled database found, will seed from JSON")
            }
        }

        // Configure database
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            // WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")

            // NOTE: SQLCipher encryption is deferred due to SPM/XCFramework compatibility
            // issues. iOS File Protection (.complete) provides security when device is locked.
            // Consider CocoaPods for GRDBCipher in a future release.
        }

        // Create database pool
        dbPool = try DatabasePool(path: dbPath, configuration: config)

        // Set file protection - database is only accessible when device is unlocked
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: dbPath
        )

        // Also protect WAL and SHM files if they exist
        let walPath = dbPath + "-wal"
        let shmPath = dbPath + "-shm"
        if fileManager.fileExists(atPath: walPath) {
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: walPath
            )
        }
        if fileManager.fileExists(atPath: shmPath) {
            try? fileManager.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: shmPath
            )
        }

        // Run migrations
        try DatabaseMigrator.migrate(dbPool)

        logger.info("Database initialized successfully")
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
                logger.error("Database write error: \(error.localizedDescription)")
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

// MARK: - User Data Management
extension AppDatabase {
    /// Deletes all user-generated content while preserving seed data.
    /// Use this for "Delete All Data" functionality.
    public func deleteAllUserData() throws {
        try dbPool.write { db in
            // Delete user content tables (order matters due to foreign keys)
            try db.execute(sql: "DELETE FROM sightings")
            try db.execute(sql: "DELETE FROM dives")

            // Note: We keep sites, species, geographic data as they are seed data
            // site_media is also preserved as it's curated content

            logger.info("All user data deleted successfully")
        }
    }
}
