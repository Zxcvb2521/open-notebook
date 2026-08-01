use crate::db::repository::Database;
use crate::db::models::*;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;

use super::notebooks::AppState;

#[tauri::command]
pub async fn get_notes(
    state: State<'_, AppState>,
    notebook_id: String,
    include_content: Option<bool>,
) -> Result<Vec<NoteResponse>, String> {
    let db = state.db.clone();
    let nb_id = notebook_id;
    let include = include_content.unwrap_or(false);

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let content_col = if include { "content" } else { "''" };
        let query = format!("SELECT id, title, {}, notebook_id, created, updated FROM notes WHERE notebook_id = ?1 ORDER BY updated DESC", content_col);
        let mut stmt = conn.prepare(&query).map_err(|e| e.to_string())?;
        let rows = stmt.query_map(params![nb_id], |row| {
            Ok(NoteResponse { id: row.get(0)?, title: row.get(1)?, content: row.get(2)?, notebook_id: row.get(3)?, created: row.get(4)?, updated: row.get(5)? })
        }).map_err(|e| e.to_string())?;
        let mut notes = Vec::new();
        for row in rows { notes.push(row.map_err(|e| e.to_string())?); }
        Ok(notes)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn create_note(
    state: State<'_, AppState>,
    data: NoteCreate,
) -> Result<NoteResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let title = data.title.unwrap_or_default();

        conn.execute("INSERT INTO notes (id, title, content, notebook_id, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![id, title.clone(), data.content, data.notebook_id, now, now],
        ).map_err(|e| e.to_string())?;

        Ok(NoteResponse { id, title, content: data.content, notebook_id: data.notebook_id, created: now.clone(), updated: now })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_note(
    state: State<'_, AppState>,
    note_id: String,
    title: Option<String>,
    content: Option<String>,
) -> Result<NoteResponse, String> {
    let db = state.db.clone();
    let nid = note_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        let mut updates = vec!["updated = ?1".to_string()];
        let mut param_index = 2;
        if let Some(ref _t) = title { updates.push(format!("title = ?{}", param_index)); param_index += 1; }
        if let Some(ref _c) = content { updates.push(format!("content = ?{}", param_index)); param_index += 1; }

        let query = format!("UPDATE notes SET {} WHERE id = ?{}", updates.join(", "), param_index);
        let mut p: Vec<Box<dyn rusqlite::types::ToSql>> = vec![Box::new(now)];
        if let Some(ref t) = title { p.push(Box::new(t.clone())); }
        if let Some(ref c) = content { p.push(Box::new(c.clone())); }
        p.push(Box::new(nid.clone()));
        let params_refs: Vec<&dyn rusqlite::types::ToSql> = p.iter().map(|b| b.as_ref()).collect();
        conn.execute(&query, params_refs.as_slice()).map_err(|e| e.to_string())?;

        conn.query_row("SELECT id, title, content, notebook_id, created, updated FROM notes WHERE id = ?1", params![nid], |row| {
            Ok(NoteResponse { id: row.get(0)?, title: row.get(1)?, content: row.get(2)?, notebook_id: row.get(3)?, created: row.get(4)?, updated: row.get(5)? })
        }).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_note(
    state: State<'_, AppState>,
    note_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let nid = note_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM notes WHERE id = ?1", params![nid]).map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Note deleted successfully".to_string() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_note(
    state: State<'_, AppState>,
    note_id: String,
) -> Result<NoteResponse, String> {
    let db = state.db.clone();
    let nid = note_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.query_row("SELECT id, title, content, notebook_id, created, updated FROM notes WHERE id = ?1", params![nid], |row| {
            Ok(NoteResponse { id: row.get(0)?, title: row.get(1)?, content: row.get(2)?, notebook_id: row.get(3)?, created: row.get(4)?, updated: row.get(5)? })
        }).map_err(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => "Note not found".to_string(),
            other => other.to_string(),
        })
    })
    .await
    .map_err(|e| e.to_string())?
}
