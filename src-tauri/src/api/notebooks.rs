use crate::db::repository::Database;
use crate::db::models::*;
use crate::ai::process::AIManager;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;

pub struct AppState {
    pub db: Arc<Database>,
    pub ai_manager: Arc<AIManager>,
}

// ============================================
// NOTEBOOK COMMANDS
// ============================================

#[tauri::command]
pub async fn list_notebooks(
    state: State<'_, AppState>,
    include_archived: Option<bool>,
) -> Result<Vec<NotebookResponse>, String> {
    let db = state.db.clone();
    let include_archived = include_archived.unwrap_or(false);

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;

        let query = if include_archived {
            "SELECT n.id, n.name, n.description, n.archived, n.created, n.updated,
                    (SELECT COUNT(*) FROM source_notebooks sn WHERE sn.notebook_id = n.id) as source_count,
                    (SELECT COUNT(*) FROM notes note WHERE note.notebook_id = n.id) as note_count
             FROM notebooks n ORDER BY n.updated DESC"
        } else {
            "SELECT n.id, n.name, n.description, n.archived, n.created, n.updated,
                    (SELECT COUNT(*) FROM source_notebooks sn WHERE sn.notebook_id = n.id) as source_count,
                    (SELECT COUNT(*) FROM notes note WHERE note.notebook_id = n.id) as note_count
             FROM notebooks n WHERE n.archived = 0 ORDER BY n.updated DESC"
        };

        let mut stmt = conn.prepare(query).map_err(|e| e.to_string())?;
        let rows = stmt.query_map([], |row| {
            Ok(NotebookResponse {
                id: row.get(0)?,
                name: row.get(1)?,
                description: row.get(2)?,
                archived: row.get::<_, i32>(3)? == 1,
                created: row.get(4)?,
                updated: row.get(5)?,
                source_count: row.get(6)?,
                note_count: row.get(7)?,
            })
        }).map_err(|e| e.to_string())?;

        let mut notebooks = Vec::new();
        for row in rows {
            notebooks.push(row.map_err(|e| e.to_string())?);
        }
        Ok(notebooks)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[derive(serde::Deserialize)]
pub struct CreateNotebookRequest {
    pub name: String,
    pub description: Option<String>,
    pub emoji: Option<String>,
}

#[tauri::command]
pub async fn create_notebook(
    state: State<'_, AppState>,
    request: CreateNotebookRequest,
) -> Result<NotebookResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let description = request.description.unwrap_or_default();

        // Create the notebooks table column for emoji if it doesn't exist
        let _ = conn.execute("ALTER TABLE notebooks ADD COLUMN emoji TEXT DEFAULT '📓'", []);
        let _ = conn.execute("ALTER TABLE notebooks ADD COLUMN \"default\" INTEGER DEFAULT 0", []);

        let emoji = request.emoji.unwrap_or_else(|| "📚".to_string());

        conn.execute(
            "INSERT INTO notebooks (id, name, description, emoji, \"default\", archived, created, updated) VALUES (?1, ?2, ?3, ?4, 0, 0, ?5, ?6)",
            params![id, request.name.clone(), description, emoji, now.clone(), now.clone()],
        )
        .map_err(|e| e.to_string())?;

        Ok(NotebookResponse {
            id,
            name: request.name,
            description,
            archived: false,
            created: now.clone(),
            updated: now,
            source_count: 0,
            note_count: 0,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[derive(serde::Deserialize)]
pub struct UpdateNotebookRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub archived: Option<bool>,
    pub emoji: Option<String>,
    #[serde(rename = "default")]
    pub default: Option<bool>,
}

#[tauri::command]
pub async fn get_notebook(
    state: State<'_, AppState>,
    id: String,
) -> Result<NotebookResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.query_row(
            "SELECT n.id, n.name, n.description, n.archived, n.created, n.updated,
                    (SELECT COUNT(*) FROM source_notebooks sn WHERE sn.notebook_id = n.id) as source_count,
                    (SELECT COUNT(*) FROM notes note WHERE note.notebook_id = n.id) as note_count
             FROM notebooks n WHERE n.id = ?1",
            params![id],
            |row| {
                Ok(NotebookResponse {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    archived: row.get::<_, i32>(3)? == 1,
                    created: row.get(4)?,
                    updated: row.get(5)?,
                    source_count: row.get(6)?,
                    note_count: row.get(7)?,
                })
            },
        ).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_notebook_delete_preview(
    state: State<'_, AppState>,
    id: String,
) -> Result<NotebookDeletePreview, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let notebook_name: String = conn.query_row(
            "SELECT name FROM notebooks WHERE id = ?1",
            params![id],
            |row| row.get(0),
        ).map_err(|e| format!("Notebook not found: {}", e))?;

        let note_count: i64 = conn.query_row(
            "SELECT COUNT(*) FROM notes WHERE notebook_id = ?1",
            params![id],
            |row| row.get(0),
        ).unwrap_or(0);

        let total_sources: i64 = conn.query_row(
            "SELECT COUNT(*) FROM source_notebooks WHERE notebook_id = ?1",
            params![id],
            |row| row.get(0),
        ).unwrap_or(0);

        let shared_source_count: i64 = conn.query_row(
            "SELECT COUNT(DISTINCT sn.source_id) FROM source_notebooks sn
             WHERE sn.notebook_id = ?1
               AND (SELECT COUNT(*) FROM source_notebooks sn2 WHERE sn2.source_id = sn.source_id) > 1",
            params![id],
            |row| row.get(0),
        ).unwrap_or(0);

        Ok(NotebookDeletePreview {
            notebook_id: id,
            notebook_name,
            note_count,
            exclusive_source_count: total_sources - shared_source_count,
            shared_source_count,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_notebook(
    state: State<'_, AppState>,
    id: String,
    updates: UpdateNotebookRequest,
) -> Result<NotebookResponse, String> {
    let db = state.db.clone();
    let nb_id = id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        // Build dynamic update
        let mut set_clauses = vec!["updated = ?1".to_string()];
        let mut bound: Vec<Box<dyn rusqlite::types::ToSql>> = vec![Box::new(now)];
        let mut param_idx = 2u32;

        if let Some(ref name) = updates.name {
            set_clauses.push(format!("name = ?{}", param_idx));
            bound.push(Box::new(name.clone()));
            param_idx += 1;
        }
        if let Some(ref desc) = updates.description {
            set_clauses.push(format!("description = ?{}", param_idx));
            bound.push(Box::new(desc.clone()));
            param_idx += 1;
        }
        if let Some(archived) = updates.archived {
            set_clauses.push(format!("archived = ?{}", param_idx));
            bound.push(Box::new(if archived { 1i32 } else { 0i32 }));
            param_idx += 1;
        }
        if let Some(ref emoji) = updates.emoji {
            set_clauses.push(format!("emoji = ?{}", param_idx));
            bound.push(Box::new(emoji.clone()));
            param_idx += 1;
        }
        if let Some(is_default) = updates.default {
            set_clauses.push(format!("\"default\" = ?{}", param_idx));
            bound.push(Box::new(if is_default { 1i32 } else { 0i32 }));
            param_idx += 1;
        }

        let query = format!(
            "UPDATE notebooks SET {} WHERE id = ?{}",
            set_clauses.join(", "),
            param_idx
        );
        bound.push(Box::new(nb_id.clone()));

        let refs: Vec<&dyn rusqlite::types::ToSql> = bound.iter().map(|b| b.as_ref()).collect();
        conn.execute(&query, refs.as_slice()).map_err(|e| e.to_string())?;

        // Re-fetch
        conn.query_row(
            "SELECT n.id, n.name, n.description, n.archived, n.created, n.updated,
                    (SELECT COUNT(*) FROM source_notebooks sn WHERE sn.notebook_id = n.id) as source_count,
                    (SELECT COUNT(*) FROM notes note WHERE note.notebook_id = n.id) as note_count
             FROM notebooks n WHERE n.id = ?1",
            params![nb_id],
            |row| {
                Ok(NotebookResponse {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    archived: row.get::<_, i32>(3)? == 1,
                    created: row.get(4)?,
                    updated: row.get(5)?,
                    source_count: row.get(6)?,
                    note_count: row.get(7)?,
                })
            },
        )
        .map_err(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => "Notebook not found".to_string(),
            other => other.to_string(),
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_notebook(
    state: State<'_, AppState>,
    id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let nb_id = id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;

        conn.execute("DELETE FROM chat_messages WHERE session_id IN (SELECT id FROM chat_sessions WHERE notebook_id = ?1)", params![nb_id])
            .map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM chat_sessions WHERE notebook_id = ?1", params![nb_id])
            .map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM notes WHERE notebook_id = ?1", params![nb_id])
            .map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM source_notebooks WHERE notebook_id = ?1", params![nb_id])
            .map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM notebooks WHERE id = ?1", params![nb_id])
            .map_err(|e| e.to_string())?;

        Ok(SuccessResponse {
            success: true,
            message: "Notebook deleted".to_string(),
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_recently_viewed(
    state: State<'_, AppState>,
    limit: Option<i64>,
) -> Result<Vec<RecentlyViewedResponse>, String> {
    let db = state.db.clone();
    let lim = limit.unwrap_or(12);

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut results = Vec::new();

        let mut stmt = conn.prepare(
            "SELECT id, name, last_viewed_at FROM notebooks WHERE last_viewed_at IS NOT NULL ORDER BY last_viewed_at DESC LIMIT ?1"
        ).map_err(|e| e.to_string())?;
        let rows = stmt.query_map(params![lim], |row| {
            Ok(RecentlyViewedResponse {
                item_type: "notebook".to_string(),
                id: row.get(0)?,
                title: row.get(1)?,
                last_viewed_at: row.get(2)?,
            })
        }).map_err(|e| e.to_string())?;
        for row in rows {
            results.push(row.map_err(|e| e.to_string())?);
        }

        Ok(results)
    })
    .await
    .map_err(|e| e.to_string())?
}
