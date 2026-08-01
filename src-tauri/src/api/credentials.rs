use crate::db::models::*;
use crate::db::repository::Database;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;

use super::notebooks::AppState;

#[tauri::command]
pub async fn get_credentials(
    state: State<'_, AppState>,
) -> Result<Vec<CredentialResponse>, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare(
            "SELECT id, name, provider, created, updated FROM credentials ORDER BY provider, name"
        ).map_err(|e| e.to_string())?;

        let rows = stmt.query_map([], |row| {
            Ok(CredentialResponse {
                id: row.get(0)?,
                name: row.get(1)?,
                provider: row.get(2)?,
                created: row.get(3)?,
                updated: row.get(4)?,
                has_api_key: true, // If row exists, it has encrypted data
            })
        }).map_err(|e| e.to_string())?;

        let mut result = Vec::new();
        for row in rows {
            result.push(row.map_err(|e| e.to_string())?);
        }
        Ok(result)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn create_credential(
    state: State<'_, AppState>,
    data: CredentialCreate,
) -> Result<CredentialResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        // Build the credential data as JSON, then "encrypt" (base64 for now, can add real AES later)
        let credential_data = serde_json::json!({
            "api_key": data.api_key.unwrap_or_default(),
            "base_url": data.base_url.unwrap_or_default(),
            "extra": data.extra,
        });
        let encrypted = base64_encode(&credential_data.to_string());

        conn.execute(
            "INSERT INTO credentials (id, name, provider, encrypted_data, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![id, data.name, data.provider, encrypted, now, now],
        ).map_err(|e| e.to_string())?;

        Ok(CredentialResponse {
            id,
            name: data.name,
            provider: data.provider,
            created: now.clone(),
            updated: now,
            has_api_key: true,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_credential_data(
    state: State<'_, AppState>,
    credential_id: String,
) -> Result<serde_json::Value, String> {
    let db = state.db.clone();
    let cid = credential_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let encrypted: String = conn.query_row(
            "SELECT encrypted_data FROM credentials WHERE id = ?1",
            params![cid],
            |row| row.get(0),
        ).map_err(|e| e.to_string())?;

        let decrypted = base64_decode(&encrypted);
        let data: serde_json::Value = serde_json::from_str(&decrypted)
            .map_err(|e| format!("Failed to parse credential data: {}", e))?;

        Ok(data)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_credential(
    state: State<'_, AppState>,
    id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM credentials WHERE id = ?1", params![id])
            .map_err(|e| e.to_string())?;
        Ok(SuccessResponse {
            success: true,
            message: "Credential deleted".to_string(),
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

// Simple base64 encoding/decoding (replace with proper AES-256-GCM later)
fn base64_encode(input: &str) -> String {
    use base64::{Engine as _, engine::general_purpose::STANDARD};
    STANDARD.encode(input.as_bytes())
}

fn base64_decode(input: &str) -> String {
    use base64::{Engine as _, engine::general_purpose::STANDARD};
    let decoded = STANDARD.decode(input).unwrap_or_default();
    String::from_utf8(decoded).unwrap_or_default()
}
