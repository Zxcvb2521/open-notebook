use crate::db::models::*;
use crate::db::repository::Database;
use crate::ai::process::AIManager;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;

use super::notebooks::AppState;

#[tauri::command]
pub async fn check_ai_health(
    state: State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let healthy = state.ai_manager.service.is_healthy().await;
    Ok(serde_json::json!({
        "status": if healthy { "ok" } else { "unavailable" },
        "service_url": state.ai_manager.service.base_url(),
    }))
}

#[tauri::command]
pub async fn rebuild_embeddings(
    state: State<'_, AppState>,
    source_id: Option<String>,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let ai = state.ai_manager.clone();

    // Get embedding model config
    let (embedding_model, ollama_url) = {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let model_id: Option<String> = conn.query_row(
            "SELECT default_embedding_model FROM default_models WHERE id = 'singleton'",
            [],
            |row| row.get(0),
        ).unwrap_or(None);

        if let Some(mid) = model_id {
            let (provider, name): (String, String) = conn.query_row(
                "SELECT provider, name FROM models WHERE id = ?1",
                params![mid],
                |row| Ok((row.get(0)?, row.get(1)?)),
            ).unwrap_or(("ollama".into(), "nomic-embed-text".into()));

            let base_url = if provider == "ollama" {
                // Try to get base_url from credential
                let cred_id: Option<String> = conn.query_row(
                    "SELECT credential_id FROM models WHERE id = ?1",
                    params![mid],
                    |row| row.get(0),
                ).unwrap_or(None);
                if let Some(cid) = cred_id {
                    conn.query_row(
                        "SELECT base_url FROM credentials WHERE id = ?1",
                        params![cid],
                        |row| row.get::<_, Option<String>>(0),
                    ).unwrap_or(None).unwrap_or_else(|| "http://localhost:11434".into())
                } else {
                    "http://localhost:11434".into()
                }
            } else {
                "http://localhost:11434".into()
            };

            (name, base_url)
        } else {
            ("nomic-embed-text".into(), "http://localhost:11434".into())
        }
    };

    // Get sources to embed
    let sources = {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut query = String::from("SELECT id, full_text, asset_url, asset_file_path FROM sources");
        if let Some(ref sid) = source_id {
            query.push_str(&format!(" WHERE id = '{}'", sid.replace('\'', "''")));
        }
        query.push_str(" AND full_text IS NOT NULL AND full_text != ''");
        if source_id.is_none() {
            query = format!(
                "SELECT id, full_text, asset_url, asset_file_path FROM sources WHERE full_text IS NOT NULL AND full_text != ''"
            );
        }

        let mut stmt = conn.prepare(&query).map_err(|e| e.to_string())?;
        let rows = stmt.query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, Option<String>>(1)?,
                row.get::<_, Option<String>>(2)?,
                row.get::<_, Option<String>>(3)?,
            ))
        }).map_err(|e| e.to_string())?;

        let mut result = Vec::new();
        for row in rows {
            if let Ok(r) = row {
                result.push(r);
            }
        }
        result
    };

    let mut processed = 0;
    let mut errors = 0;

    for (sid, full_text, _asset_url, _asset_path) in &sources {
        let text = match full_text {
            Some(t) if !t.is_empty() => t,
            _ => continue,
        };

        // Chunk the text
        let chunks = ai.chunk_text(text, 1000, 200).await.unwrap_or_default();
        if chunks.is_empty() {
            continue;
        }

        // Embed chunks
        match ai.embed_batch(&chunks, &embedding_model, &ollama_url).await {
            Ok(embeddings) => {
                // Store in database
                let conn = db.conn.lock().map_err(|e| e.to_string())?;
                // Clear existing embeddings
                let _ = conn.execute("DELETE FROM source_embeddings WHERE source_id = ?1", params![sid]);

                for (i, (chunk, embedding)) in chunks.iter().zip(embeddings.iter()).enumerate() {
                    let emb_json = serde_json::to_string(embedding).unwrap_or_default();
                    let _ = conn.execute(
                        "INSERT INTO source_embeddings (id, source_id, chunk_index, chunk_text, embedding, created) VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'))",
                        params![uuid::Uuid::new_v4().to_string(), sid, i as i64, chunk, emb_json],
                    );
                }
                processed += 1;
            }
            Err(e) => {
                log::error!("Failed to embed source {}: {}", sid, e);
                errors += 1;
            }
        }
    }

    Ok(SuccessResponse {
        success: true,
        message: format!("Rebuilt embeddings for {} sources ({} errors)", processed, errors),
    })
}
