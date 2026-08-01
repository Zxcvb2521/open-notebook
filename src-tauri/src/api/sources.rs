use crate::db::repository::Database;
use crate::db::models::*;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;

use super::notebooks::AppState;

fn source_from_row(row: &rusqlite::Row) -> rusqlite::Result<SourceResponse> {
    let topics_json: Option<String> = row.get(2)?;
    let topics: Vec<String> = topics_json
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default();

    Ok(SourceResponse {
        id: row.get(0)?,
        title: row.get(1)?,
        topics,
        asset: Some(AssetModel {
            file_path: row.get(3)?,
            url: row.get(4)?,
        }),
        full_text: row.get(5)?,
        embedded: false,
        embedded_chunks: 0,
        created: row.get(6)?,
        updated: row.get(7)?,
        notebooks: None,
        status: None,
        processing_info: None,
    })
}

#[tauri::command]
pub async fn get_sources(
    state: State<'_, AppState>,
    notebook_id: Option<String>,
    limit: Option<i64>,
    offset: Option<i64>,
    sort_by: Option<String>,
    sort_order: Option<String>,
) -> Result<Vec<SourceResponse>, String> {
    let db = state.db.clone();
    let nb_id = notebook_id;
    let lim = limit.unwrap_or(50);
    let off = offset.unwrap_or(0);
    let sort_field = match sort_by.as_deref() {
        Some("created") => "s.created",
        Some("title") => "LOWER(s.title)",
        _ => "s.updated",
    };
    let sort_dir = if sort_order.as_deref() == Some("asc") { "ASC" } else { "DESC" };

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;

        let query = if let Some(ref _nb) = nb_id {
            format!(
                "SELECT s.id, s.title, s.topics, s.asset_file_path, s.asset_url, s.full_text, s.created, s.updated, 0
                 FROM sources s INNER JOIN source_notebooks sn ON s.id = sn.source_id
                 WHERE sn.notebook_id = ?1 ORDER BY {} {} LIMIT ?2 OFFSET ?3",
                sort_field, sort_dir
            )
        } else {
            format!(
                "SELECT s.id, s.title, s.topics, s.asset_file_path, s.asset_url, s.full_text, s.created, s.updated, 0
                 FROM sources s ORDER BY {} {} LIMIT ?1 OFFSET ?2",
                sort_field, sort_dir
            )
        };

        let mut stmt = conn.prepare(&query).map_err(|e| e.to_string())?;
        let rows = if let Some(ref nb) = nb_id {
            stmt.query_map(params![nb, lim, off], source_from_row).map_err(|e| e.to_string())?
        } else {
            stmt.query_map(params![lim, off], source_from_row).map_err(|e| e.to_string())?
        };

        let mut sources = Vec::new();
        for row in rows {
            sources.push(row.map_err(|e| e.to_string())?);
        }
        Ok(sources)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_source(
    state: State<'_, AppState>,
    source_id: String,
) -> Result<SourceResponse, String> {
    let db = state.db.clone();
    let sid = source_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        let _ = conn.execute("UPDATE sources SET last_viewed_at = ?1 WHERE id = ?2", params![now, sid]);

        let mut src = conn.query_row(
            "SELECT s.id, s.title, s.topics, s.asset_file_path, s.asset_url, s.full_text, s.created, s.updated, 0
             FROM sources s WHERE s.id = ?1",
            params![sid],
            source_from_row,
        ).map_err(|e| match e {
            rusqlite::Error::QueryReturnedNoRows => "Source not found".to_string(),
            other => other.to_string(),
        })?;

        // Notebook associations
        let notebook_ids: Vec<String> = {
            let mut stmt = conn.prepare("SELECT notebook_id FROM source_notebooks WHERE source_id = ?1").map_err(|e| e.to_string())?;
            let rows = stmt.query_map(params![sid], |row| row.get(0)).map_err(|e| e.to_string())?;
            rows.filter_map(|r| r.ok()).collect()
        };
        src.notebooks = Some(notebook_ids);

        // Embedded chunks
        let embedded_chunks: i64 = conn.query_row("SELECT COUNT(*) FROM source_embeddings WHERE source_id = ?1", params![sid], |row| row.get(0)).unwrap_or(0);
        src.embedded_chunks = embedded_chunks;
        src.embedded = embedded_chunks > 0;

        Ok(src)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn create_source(
    state: State<'_, AppState>,
    data: SourceCreate,
) -> Result<SourceResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let title = data.title.unwrap_or_else(|| "Processing...".to_string());
        let asset_file_path = data.file_path.clone();
        let asset_url = data.url.clone();
        let content = data.content.clone();
        let notebooks_clone = data.notebooks.clone();

        conn.execute(
            "INSERT INTO sources (id, title, full_text, asset_file_path, asset_url, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![id, title, content, asset_file_path, asset_url, now, now],
        ).map_err(|e| e.to_string())?;

        if let Some(notebooks) = &data.notebooks {
            for nb_id in notebooks {
                conn.execute("INSERT OR IGNORE INTO source_notebooks (source_id, notebook_id, created) VALUES (?1, ?2, ?3)", params![id, nb_id, now]).map_err(|e| e.to_string())?;
            }
        } else if let Some(ref nb_id) = data.notebook_id {
            conn.execute("INSERT OR IGNORE INTO source_notebooks (source_id, notebook_id, created) VALUES (?1, ?2, ?3)", params![id, nb_id, now]).map_err(|e| e.to_string())?;
        }

        Ok(SourceResponse {
            id,
            title,
            topics: Vec::new(),
            asset: Some(AssetModel { file_path: data.file_path, url: data.url }),
            full_text: data.content,
            embedded: false,
            embedded_chunks: 0,
            created: now.clone(),
            updated: now,
            notebooks: notebooks_clone,
            status: Some("new".to_string()),
            processing_info: None,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_source(
    state: State<'_, AppState>,
    source_id: String,
    title: Option<String>,
    topics: Option<Vec<String>>,
) -> Result<SourceResponse, String> {
    let db = state.db.clone();
    let sid = source_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        let mut updates = vec!["updated = ?1".to_string()];
        let mut param_index = 2;
        if let Some(ref _t) = title { updates.push(format!("title = ?{}", param_index)); param_index += 1; }
        if let Some(ref _tp) = topics { updates.push(format!("topics = ?{}", param_index)); param_index += 1; }

        let query = format!("UPDATE sources SET {} WHERE id = ?{}", updates.join(", "), param_index);
        let mut p: Vec<Box<dyn rusqlite::types::ToSql>> = vec![Box::new(now)];
        if let Some(ref t) = title { p.push(Box::new(t.clone())); }
        if let Some(ref tp) = topics { p.push(Box::new(serde_json::to_string(tp).unwrap_or_default())); }
        p.push(Box::new(sid.clone()));
        let params_refs: Vec<&dyn rusqlite::types::ToSql> = p.iter().map(|b| b.as_ref()).collect();
        conn.execute(&query, params_refs.as_slice()).map_err(|e| e.to_string())?;

        // Re-fetch
        conn.query_row(
            "SELECT s.id, s.title, s.topics, s.asset_file_path, s.asset_url, s.full_text, s.created, s.updated, 0 FROM sources s WHERE s.id = ?1",
            params![sid],
            source_from_row,
        ).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_source(
    state: State<'_, AppState>,
    source_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let sid = source_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM source_embeddings WHERE source_id = ?1", params![sid]).map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM source_insights WHERE source_id = ?1", params![sid]).map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM source_commands WHERE source_id = ?1", params![sid]).map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM source_notebooks WHERE source_id = ?1", params![sid]).map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM sources WHERE id = ?1", params![sid]).map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Source deleted successfully".to_string() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_source_insights(
    state: State<'_, AppState>,
    source_id: String,
) -> Result<Vec<SourceInsight>, String> {
    let db = state.db.clone();
    let sid = source_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("SELECT id, source_id, insight_type, content, created, updated FROM source_insights WHERE source_id = ?1 ORDER BY created DESC").map_err(|e| e.to_string())?;
        let rows = stmt.query_map(params![sid], |row| {
            Ok(SourceInsight { id: row.get(0)?, source_id: row.get(1)?, insight_type: row.get(2)?, content: row.get(3)?, created: row.get(4)?, updated: row.get(5)? })
        }).map_err(|e| e.to_string())?;
        let mut insights = Vec::new();
        for row in rows { insights.push(row.map_err(|e| e.to_string())?); }
        Ok(insights)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn add_source_to_notebook(
    state: State<'_, AppState>,
    source_id: String,
    notebook_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let sid = source_id;
    let nb_id = notebook_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        conn.execute("INSERT OR IGNORE INTO source_notebooks (source_id, notebook_id, created) VALUES (?1, ?2, ?3)", params![sid, nb_id, now]).map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Source linked to notebook".to_string() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn process_source_content(
    state: State<'_, AppState>,
    source_id: String,
    embed: Option<bool>,
) -> Result<SourceResponse, String> {
    let db = state.db.clone();
    let ai = state.ai_manager.clone();
    let sid = source_id;
    let do_embed = embed.unwrap_or(true);

    // Get source info
    let (url, file_path, full_text): (Option<String>, Option<String>, Option<String>) = {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.query_row(
            "SELECT asset_url, asset_file_path, full_text FROM sources WHERE id = ?1",
            params![sid],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
        ).map_err(|e| e.to_string())?
    };

    // Extract text if we don't have it yet
    let extracted_title;
    let extracted_text;
    if full_text.as_ref().map_or(true, |t| t.is_empty()) {
        if let Some(ref u) = url {
            let (title, text) = ai.extract_url(u).await
                .map_err(|e| format!("Failed to extract URL: {}", e))?;
            extracted_title = title;
            extracted_text = text;
        } else if let Some(ref fp) = file_path {
            let text = ai.extract_file(fp).await
                .map_err(|e| format!("Failed to extract file: {}", e))?;
            extracted_title = None;
            extracted_text = text;
        } else {
            extracted_title = None;
            extracted_text = None;
        }
    } else {
        extracted_title = None;
        extracted_text = full_text.clone();
    }

    // Update source with extracted text and title
    {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        if let Some(ref text) = extracted_text {
            let title = extracted_title.as_deref().unwrap_or("Processing...");
            let _ = conn.execute(
                "UPDATE sources SET full_text = ?1, title = CASE WHEN title = 'Processing...' THEN ?2 ELSE title END, updated = ?3 WHERE id = ?4",
                params![text, title, now, sid],
            );
        }
    }

    // Embed if requested
    if do_embed {
        if let Some(ref text) = extracted_text {
            if !text.is_empty() {
                // Get embedding config
                let (emb_model, ollama_url) = {
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

                // Chunk and embed
                if let Ok(chunks) = ai.chunk_text(text, 1000, 200).await {
                    if let Ok(embeddings) = ai.embed_batch(&chunks, &emb_model, &ollama_url).await {
                        let conn = db.conn.lock().map_err(|e| e.to_string())?;
                        let _ = conn.execute("DELETE FROM source_embeddings WHERE source_id = ?1", params![sid]);
                        for (i, (chunk, embedding)) in chunks.iter().zip(embeddings.iter()).enumerate() {
                            let emb_json = serde_json::to_string(embedding).unwrap_or_default();
                            let _ = conn.execute(
                                "INSERT INTO source_embeddings (id, source_id, chunk_index, chunk_text, embedding, created) VALUES (?1, ?2, ?3, ?4, ?5, datetime('now'))",
                                params![uuid::Uuid::new_v4().to_string(), sid, i as i64, chunk, emb_json],
                            );
                        }
                    }
                }
            }
        }
    }

    // Re-fetch and return updated source
    let db2 = db.clone();
    let sid2 = sid.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db2.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let _ = conn.execute("UPDATE sources SET last_viewed_at = ?1 WHERE id = ?2", params![now, sid2]);
        let mut src = conn.query_row(
            "SELECT s.id, s.title, s.topics, s.asset_file_path, s.asset_url, s.full_text, s.created, s.updated, 0
             FROM sources s WHERE s.id = ?1",
            params![sid2],
            source_from_row,
        ).map_err(|e| e.to_string())?;
        let notebook_ids: Vec<String> = {
            let mut stmt = conn.prepare("SELECT notebook_id FROM source_notebooks WHERE source_id = ?1").map_err(|e| e.to_string())?;
            let rows = stmt.query_map(params![sid2], |row| row.get(0)).map_err(|e| e.to_string())?;
            rows.filter_map(|r| r.ok()).collect()
        };
        src.notebooks = Some(notebook_ids);
        let embedded_chunks: i64 = conn.query_row("SELECT COUNT(*) FROM source_embeddings WHERE source_id = ?1", params![sid2], |row| row.get(0)).unwrap_or(0);
        src.embedded_chunks = embedded_chunks;
        src.embedded = embedded_chunks > 0;
        Ok(src)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn remove_source_from_notebook(
    state: State<'_, AppState>,
    source_id: String,
    notebook_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let sid = source_id;
    let nb_id = notebook_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM source_notebooks WHERE source_id = ?1 AND notebook_id = ?2", params![sid, nb_id]).map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Source removed from notebook".to_string() })
    })
    .await
    .map_err(|e| e.to_string())?
}
