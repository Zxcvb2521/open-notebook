use crate::db::repository::Database;
use crate::db::models::*;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;
use super::notebooks::AppState;

#[tauri::command]
pub async fn check_auth(
    state: State<'_, AppState>,
) -> Result<bool, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let result: Result<i32, _> = conn.query_row(
            "SELECT COUNT(*) FROM settings WHERE key = 'auth_password'",
            [],
            |row| row.get(0),
        );
        match result {
            Ok(count) => Ok(count > 0),
            Err(_) => Ok(false),
        }
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn login(
    state: State<'_, AppState>,
    password: String,
) -> Result<bool, String> {
    let db = state.db.clone();
    let pw = password;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let stored_hash: Result<String, _> = conn.query_row(
            "SELECT value FROM settings WHERE key = 'auth_password'",
            [],
            |row| row.get(0),
        );
        match stored_hash {
            Ok(hash) => Ok(hash == pw),
            Err(_) => Ok(false),
        }
    })
    .await
    .map_err(|e| e.to_string())?
}
