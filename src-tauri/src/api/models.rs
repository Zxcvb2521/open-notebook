use crate::db::repository::Database;
use crate::db::models::*;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;

use super::notebooks::AppState;

#[tauri::command]
pub async fn get_models(
    state: State<'_, AppState>,
    model_type: Option<String>,
) -> Result<Vec<Model>, String> {
    let db = state.db.clone();
    let mt = model_type;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;

        let mut stmt = if let Some(ref t) = mt {
            conn.prepare("SELECT id, name, provider, type, credential_id, created, updated FROM models WHERE type = ?1 ORDER BY name").map_err(|e| e.to_string())?
        } else {
            conn.prepare("SELECT id, name, provider, type, credential_id, created, updated FROM models ORDER BY provider, name").map_err(|e| e.to_string())?
        };

        let rows: Vec<Model> = if let Some(ref t) = mt {
            stmt.query_map(params![t], |row| {
                Ok(Model { id: row.get(0)?, name: row.get(1)?, provider: row.get(2)?, model_type: row.get(3)?, credential_id: row.get(4)?, created: row.get(5)?, updated: row.get(6)? })
            }).map_err(|e| e.to_string())?
            .collect::<Result<Vec<_>, _>>().map_err(|e| e.to_string())?
        } else {
            stmt.query_map([], |row| {
                Ok(Model { id: row.get(0)?, name: row.get(1)?, provider: row.get(2)?, model_type: row.get(3)?, credential_id: row.get(4)?, created: row.get(5)?, updated: row.get(6)? })
            }).map_err(|e| e.to_string())?
            .collect::<Result<Vec<_>, _>>().map_err(|e| e.to_string())?
        };

        Ok(rows)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn create_model(
    state: State<'_, AppState>,
    data: ModelCreate,
) -> Result<Model, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        conn.execute("INSERT INTO models (id, name, provider, type, credential_id, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![id, data.name, data.provider, data.model_type, data.credential_id, now.clone(), now],
        ).map_err(|e| e.to_string())?;
        Ok(Model { id, name: data.name, provider: data.provider, model_type: data.model_type, credential_id: data.credential_id, created: now.clone(), updated: now })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_model(
    state: State<'_, AppState>,
    model_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let mid = model_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM models WHERE id = ?1", params![mid]).map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Model deleted".to_string() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_default_models(
    state: State<'_, AppState>,
) -> Result<DefaultModelsResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.query_row(
            "SELECT default_chat_model, default_transformation_model, large_context_model,
                    default_text_to_speech_model, default_speech_to_text_model,
                    default_embedding_model, default_tools_model
             FROM default_models WHERE id = 'singleton'",
            [],
            |row| {
                Ok(DefaultModelsResponse {
                    default_chat_model: row.get(0)?,
                    default_transformation_model: row.get(1)?,
                    large_context_model: row.get(2)?,
                    default_text_to_speech_model: row.get(3)?,
                    default_speech_to_text_model: row.get(4)?,
                    default_embedding_model: row.get(5)?,
                    default_tools_model: row.get(6)?,
                })
            },
        ).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_default_models(
    state: State<'_, AppState>,
    data: DefaultModelsResponse,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        conn.execute(
            "UPDATE default_models SET default_chat_model = ?1, default_transformation_model = ?2,
             large_context_model = ?3, default_text_to_speech_model = ?4,
             default_speech_to_text_model = ?5, default_embedding_model = ?6,
             default_tools_model = ?7, updated = ?8 WHERE id = 'singleton'",
            params![data.default_chat_model, data.default_transformation_model, data.large_context_model,
                    data.default_text_to_speech_model, data.default_speech_to_text_model,
                    data.default_embedding_model, data.default_tools_model, now],
        ).map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Default models updated".to_string() })
    })
    .await
    .map_err(|e| e.to_string())?
}
