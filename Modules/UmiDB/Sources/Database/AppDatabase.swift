import Foundation
import GRDB
import os

private let logger = Logger(subsystem: "com.umilog", category: "Database")

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

    /// Create an in-memory database for testing
    /// - Parameter inMemory: If true, creates an in-memory database
    public init(inMemory: Bool) throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        if inMemory {
            dbPool = try DatabasePool(path: ":memory:", configuration: config)
        } else {
            let fileManager = FileManager.default
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

        // Configure database
        var config = Configuration()
        config.prepareDatabase { db in
            // Enable foreign keys
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            // WAL mode for better concurrency
            try db.execute(sql: "PRAGMA journal_mode = WAL")

            // NOTE: SQLCipher encryption requires switching to GRDBCipher package.
            // When ready to enable encryption:
            // 1. Replace GRDB with GRDBCipher in project.yml
            // 2. Uncomment the following:
            // let key = try KeychainService.getDatabaseKey()
            // try db.usePassphrase(key)
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
