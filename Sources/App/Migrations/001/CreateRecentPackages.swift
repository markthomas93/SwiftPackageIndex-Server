import Fluent
import SQLKit


struct CreateRecentPackages: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw(
            """
            -- v0
            CREATE MATERIALIZED VIEW recent_packages AS
            SELECT
              p.id,
              v.package_name,
              MAX(p.created_at) AS created_at
            FROM packages p
            JOIN versions v ON v.package_id = p.id
            WHERE v.package_name IS NOT NULL
            GROUP BY p.id, v.package_name
            ORDER BY MAX(p.created_at) DESC
            LIMIT 100
            """
        ).run()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        guard let db = database as? SQLDatabase else {
            fatalError("Database must be an SQLDatabase ('as? SQLDatabase' must succeed)")
        }
        return db.raw("DROP MATERIALIZED VIEW recent_packages").run()
    }
}
