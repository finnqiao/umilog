import Foundation
import GRDB

public final class CertificationsRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchAll() throws -> [Certification] {
        try database.read { db in
            try Certification
                .order(Certification.Columns.isPrimary.desc)
                .order(Certification.Columns.certDate.desc)
                .order(Certification.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    public func fetchPrimary() throws -> Certification? {
        try database.read { db in
            try Certification
                .filter(Certification.Columns.isPrimary == true)
                .order(Certification.Columns.updatedAt.desc)
                .fetchOne(db)
        }
    }

    public func fetch(id: String) throws -> Certification? {
        try database.read { db in
            try Certification.fetchOne(db, key: id)
        }
    }

    public func upsert(_ certification: Certification) throws {
        try database.write { db in
            let now = Date()
            let normalized = Certification(
                id: certification.id,
                agency: certification.agency,
                agencyOther: certification.agencyOther,
                level: certification.level,
                certNumber: certification.certNumber,
                certDate: certification.certDate,
                expiryDate: certification.expiryDate,
                instructorName: certification.instructorName,
                instructorNumber: certification.instructorNumber,
                divesAtCert: certification.divesAtCert,
                cardImageFront: certification.cardImageFront,
                cardImageBack: certification.cardImageBack,
                notes: certification.notes,
                isPrimary: certification.isPrimary,
                createdAt: certification.createdAt,
                updatedAt: now
            )

            if normalized.isPrimary {
                try db.execute(
                    sql: """
                    UPDATE certifications
                    SET isPrimary = 0, updatedAt = ?
                    WHERE id != ? AND isPrimary = 1
                    """,
                    arguments: [now, normalized.id]
                )
            }

            try normalized.save(db)

            if !normalized.isPrimary {
                let primaryCount = try Certification
                    .filter(Certification.Columns.isPrimary == true)
                    .fetchCount(db)
                if primaryCount == 0 {
                    try db.execute(
                        sql: """
                        UPDATE certifications
                        SET isPrimary = 1, updatedAt = ?
                        WHERE id = ?
                        """,
                        arguments: [now, normalized.id]
                    )
                }
            }
        }
    }

    @discardableResult
    public func delete(id: String) throws -> Certification? {
        try database.write { db in
            guard let existing = try Certification.fetchOne(db, key: id) else {
                return nil
            }
            _ = try Certification.deleteOne(db, key: id)

            if existing.isPrimary {
                if let newest = try Certification
                    .order(Certification.Columns.certDate.desc)
                    .order(Certification.Columns.createdAt.desc)
                    .fetchOne(db) {
                    try db.execute(
                        sql: """
                        UPDATE certifications
                        SET isPrimary = 1, updatedAt = ?
                        WHERE id = ?
                        """,
                        arguments: [Date(), newest.id]
                    )
                }
            }

            return existing
        }
    }
}
