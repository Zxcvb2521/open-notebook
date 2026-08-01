use rusqlite::{Connection, Result};
use std::path::PathBuf;
use std::sync::Mutex;

pub struct Database {
    pub conn: Mutex<Connection>,
    pub data_dir: PathBuf,
}

impl Database {
    pub fn new(data_dir: PathBuf) -> Result<Self> {
        let db_path = data_dir.join("open_notebook.db");
        let conn = Connection::open(&db_path)?;

        // Enable WAL mode for better concurrent access
        conn.execute_batch("PRAGMA journal_mode=WAL;")?;
        conn.execute_batch("PRAGMA foreign_keys=ON;")?;

        let db = Self {
            conn: Mutex::new(conn),
            data_dir,
        };

        db.run_migrations()?;
        Ok(db)
    }

    pub fn run_migrations(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();

        // Create migrations table
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS _migrations (
                version INTEGER PRIMARY KEY,
                applied_at TEXT NOT NULL DEFAULT (datetime('now'))
            );"
        )?;

        let current_version: i32 = conn
            .query_row(
                "SELECT COALESCE(MAX(version), 0) FROM _migrations",
                [],
                |row| row.get(0),
            )
            .unwrap_or(0);

        log::info!("Current database version: {}", current_version);

        if current_version < 1 {
            conn.execute_batch(include_str!("migrations/001_initial.sql"))?;
            conn.execute("INSERT INTO _migrations (version) VALUES (1)", [])?;
            log::info!("Migration 1 applied");
        }

        if current_version < 2 {
            // Apply migration 002, but ignore errors if columns already exist
            let sql = include_str!("migrations/002_add_notebook_fields.sql");
            for line in sql.lines() {
                let line = line.trim();
                if line.is_empty() || line.starts_with("--") {
                    continue;
                }
                let _ = conn.execute_batch(line);
            }
            conn.execute("INSERT INTO _migrations (version) VALUES (2)", [])?;
            log::info!("Migration 2 applied");
        }

        if current_version < 3 {
            // Migration 003: podcast profiles seed + default Mistral models.
            // Run statement-by-statement so an ALTER on an already-extended
            // table is skipped instead of failing the whole migration.
            let sql = include_str!("migrations/003_podcast_profiles.sql");
            let mut statement = String::new();
            for line in sql.lines() {
                let trimmed = line.trim();
                if trimmed.is_empty() || trimmed.starts_with("--") {
                    continue;
                }
                statement.push_str(line);
                statement.push('\n');
                if trimmed.ends_with(';') {
                    if let Err(e) = conn.execute_batch(&statement) {
                        log::warn!("Migration 3 statement skipped: {}", e);
                    }
                    statement.clear();
                }
            }
            if !statement.trim().is_empty() {
                let _ = conn.execute_batch(&statement);
            }
            conn.execute("INSERT INTO _migrations (version) VALUES (3)", [])?;
            log::info!("Migration 3 applied");
        }

        Ok(())
    }
}
