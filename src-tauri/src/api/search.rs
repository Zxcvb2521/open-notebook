use crate::db::models::*;
use crate::db::repository::Database;
use rusqlite::params;
use tauri::State;
use super::notebooks::AppState;

#[tauri::command]
pub async fn search(
    state: State<'_, AppState>,
    query: String,
    search_type: Option<String>,
    limit: Option<i64>,
    search_sources: Option<bool>,
    search_notes: Option<bool>,
    minimum_score: Option<f64>,
) -> Result<SearchResponse, String> {
    let db = state.db.clone();
    let q = query.clone();
    let st = search_type.unwrap_or_else(|| "text".to_string());
    let lim = limit.unwrap_or(100);
    let search_src = search_sources.unwrap_or(true);
    let search_nts = search_notes.unwrap_or(true);

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut results: Vec<serde_json::Value> = Vec::new();

        if st == "text" {
            // FTS5 text search
            if search_src {
                let fts_query = format!("\"{}\"", q.replace('"', ""));
                let mut stmt = conn.prepare(
                    "SELECT s.id, s.title, snippet(sources_fts, 0, '<mark>', '</mark>', '...', 32) as snippet,
                            rank
                     FROM sources_fts
                     JOIN sources s ON s.id = sources_fts.rowid
                     WHERE sources_fts MATCH ?1
                     ORDER BY rank
                     LIMIT ?2"
                ).map_err(|e| e.to_string())?;

                let rows = stmt.query_map(params![fts_query, lim], |row| {
                    Ok(serde_json::json!({
                        "id": row.get::<_, String>(0)?,
                        "title": row.get::<_, Option<String>>(1)?,
                        "snippet": row.get::<_, String>(2)?,
                        "score": row.get::<_, f64>(3)?.abs(),
                        "type": "source"
                    }))
                }).map_err(|e| e.to_string())?;

                for row in rows {
                    results.push(row.map_err(|e| e.to_string())?);
                }
            }

            if search_nts {
                let fts_query = format!("\"{}\"", q.replace('"', ""));
                let mut stmt = conn.prepare(
                    "SELECT n.id, n.title, snippet(notes_fts, 0, '<mark>', '</mark>', '...', 32) as snippet,
                            rank
                     FROM notes_fts
                     JOIN notes n ON n.id = notes_fts.rowid
                     WHERE notes_fts MATCH ?1
                     ORDER BY rank
                     LIMIT ?2"
                ).map_err(|e| e.to_string())?;

                let rows = stmt.query_map(params![fts_query, lim], |row| {
                    Ok(serde_json::json!({
                        "id": row.get::<_, String>(0)?,
                        "title": row.get::<_, Option<String>>(1)?,
                        "snippet": row.get::<_, String>(2)?,
                        "score": row.get::<_, f64>(3)?.abs(),
                        "type": "note"
                    }))
                }).map_err(|e| e.to_string())?;

                for row in rows {
                    results.push(row.map_err(|e| e.to_string())?);
                }
            }
        } else {
            // LIKE-based fuzzy search as fallback when no vector search
            if search_src {
                let pattern = format!("%{}%", q);
                let mut stmt = conn.prepare(
                    "SELECT id, title, substr(full_text, 1, 200) as snippet
                     FROM sources
                     WHERE title LIKE ?1 OR full_text LIKE ?1
                     LIMIT ?2"
                ).map_err(|e| e.to_string())?;

                let rows = stmt.query_map(params![pattern, lim], |row| {
                    Ok(serde_json::json!({
                        "id": row.get::<_, String>(0)?,
                        "title": row.get::<_, Option<String>>(1)?,
                        "snippet": row.get::<_, Option<String>>(2)?,
                        "score": 0.5,
                        "type": "source"
                    }))
                }).map_err(|e| e.to_string())?;

                for row in rows {
                    results.push(row.map_err(|e| e.to_string())?);
                }
            }

            if search_nts {
                let pattern = format!("%{}%", q);
                let mut stmt = conn.prepare(
                    "SELECT id, title, substr(content, 1, 200) as snippet
                     FROM notes
                     WHERE title LIKE ?1 OR content LIKE ?1
                     LIMIT ?2"
                ).map_err(|e| e.to_string())?;

                let rows = stmt.query_map(params![pattern, lim], |row| {
                    Ok(serde_json::json!({
                        "id": row.get::<_, String>(0)?,
                        "title": row.get::<_, Option<String>>(1)?,
                        "snippet": row.get::<_, Option<String>>(2)?,
                        "score": 0.5,
                        "type": "note"
                    }))
                }).map_err(|e| e.to_string())?;

                for row in rows {
                    results.push(row.map_err(|e| e.to_string())?);
                }
            }
        }

        let total = results.len() as i64;
        Ok(SearchResponse {
            results,
            total_count: total,
            search_type: st,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn semantic_search(
    state: State<'_, AppState>,
    query: String,
    limit: Option<i64>,
    notebook_id: Option<String>,
) -> Result<SearchResponse, String> {
    let db = state.db.clone();
    let ai = state.ai_manager.clone();
    let q = query;
    let lim = limit.unwrap_or(20);

    // Get embedding config
    let (emb_model, ollama_url): (String, String) = {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let model_id: Option<String> = conn.query_row(
            "SELECT default_embedding_model FROM default_models WHERE id = 'singleton'",
            [],
            |row| row.get(0),
        ).unwrap_or(None);

        if let Some(mid) = model_id {
            let name: String = conn.query_row(
                "SELECT name FROM models WHERE id = ?1",
                params![mid],
                |row| row.get(0),
            ).unwrap_or_else(|_| "nomic-embed-text".to_string());
            ("http://localhost:11434".to_string(), name)
        } else {
            ("http://localhost:11434".to_string(), "nomic-embed-text".to_string())
        }
    };

    // Embed the query
    let query_embedding = ai.embed(&q, &emb_model, &ollama_url).await
        .map_err(|e| format!("Failed to embed query: {}", e))?;

    // Get all source embeddings
    let source_embeddings = {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let query_str = if let Some(ref nb) = notebook_id {
            format!(
                "SELECT se.id, se.source_id, se.chunk_text, se.embedding
                 FROM source_embeddings se
                 INNER JOIN source_notebooks sn ON se.source_id = sn.source_id
                 WHERE sn.notebook_id = '{}'
                 ORDER BY se.source_id, se.chunk_index",
                nb.replace('\'', "''")
            )
        } else {
            "SELECT id, source_id, chunk_text, embedding FROM source_embeddings ORDER BY source_id, chunk_index".to_string()
        };

        let mut stmt = conn.prepare(&query_str).map_err(|e| e.to_string())?;
        let rows = stmt.query_map([], |row| {
            let id: String = row.get(0)?;
            let source_id: String = row.get(1)?;
            let chunk_text: String = row.get(2)?;
            let embedding_json: String = row.get(3)?;
            Ok(serde_json::json!({
                "id": source_id,
                "text": chunk_text,
                "embedding": serde_json::from_str::<serde_json::Value>(&embedding_json).unwrap_or(serde_json::json!([])),
            }))
        }).map_err(|e| e.to_string())?;

        let mut items = Vec::new();
        for row in rows {
            if let Ok(r) = row {
                items.push(r);
            }
        }
        items
    };

    if source_embeddings.is_empty() {
        return Ok(SearchResponse {
            results: vec![],
            total_count: 0,
            search_type: "semantic".to_string(),
        });
    }

    let search_result = ai.search_embeddings(
        &query_embedding,
        &serde_json::json!(source_embeddings),
        lim as usize,
    ).await
        .map_err(|e| format!("Semantic search failed: {}", e))?;

    let results: Vec<serde_json::Value> = search_result.get("results")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter().filter_map(|item| {
                Some(serde_json::json!({
                    "id": item.get("id")?,
                    "title": None::<String>,
                    "snippet": item.get("text")?,
                    "score": item.get("score")?,
                    "type": "source",
                }))
            }).collect()
        })
        .unwrap_or_default();

    let total = results.len() as i64;
    Ok(SearchResponse {
        results,
        total_count: total,
        search_type: "semantic".to_string(),
    })
}
