use crate::db::models::*;
use crate::db::repository::Database;
use rusqlite::params;
use std::sync::Arc;
use tauri::State;

use super::notebooks::AppState;

#[tauri::command]
pub async fn get_chat_sessions(
    state: State<'_, AppState>,
    notebook_id: Option<String>,
) -> Result<Vec<ChatSessionResponse>, String> {
    let db = state.db.clone();
    let nb_id = notebook_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut sessions = Vec::new();
        if let Some(ref nb) = nb_id {
            let mut stmt = conn.prepare(
                "SELECT cs.id, cs.title, cs.notebook_id, cs.model_override, cs.created, cs.updated,
                        (SELECT COUNT(*) FROM chat_messages cm WHERE cm.session_id = cs.id) as msg_count
                 FROM chat_sessions cs WHERE cs.notebook_id = ?1 ORDER BY cs.updated DESC"
            ).map_err(|e| e.to_string())?;
            let rows = stmt.query_map(params![nb], |row| {
                Ok(ChatSessionResponse { id: row.get(0)?, title: row.get(1)?, notebook_id: row.get(2)?, created: row.get(4)?, updated: row.get(5)?, message_count: row.get(6)?, model_override: row.get(3)? })
            }).map_err(|e| e.to_string())?;
            for row in rows { sessions.push(row.map_err(|e| e.to_string())?); }
        } else {
            let mut stmt = conn.prepare(
                "SELECT cs.id, cs.title, cs.notebook_id, cs.model_override, cs.created, cs.updated,
                        (SELECT COUNT(*) FROM chat_messages cm WHERE cm.session_id = cs.id) as msg_count
                 FROM chat_sessions cs ORDER BY cs.updated DESC"
            ).map_err(|e| e.to_string())?;
            let rows = stmt.query_map([], |row| {
                Ok(ChatSessionResponse { id: row.get(0)?, title: row.get(1)?, notebook_id: row.get(2)?, created: row.get(4)?, updated: row.get(5)?, message_count: row.get(6)?, model_override: row.get(3)? })
            }).map_err(|e| e.to_string())?;
            for row in rows { sessions.push(row.map_err(|e| e.to_string())?); }
        }
        Ok(sessions)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn create_chat_session(
    state: State<'_, AppState>,
    data: ChatSessionCreate,
) -> Result<ChatSessionResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let title = data.title.unwrap_or_else(|| format!("Сессия {}", &now[..10]));
        conn.execute("INSERT INTO chat_sessions (id, title, notebook_id, model_override, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![id, title.clone(), data.notebook_id.clone(), data.model_override.clone(), now, now],
        ).map_err(|e| e.to_string())?;
        Ok(ChatSessionResponse { id, title, notebook_id: data.notebook_id, created: now.clone(), updated: now, message_count: 0, model_override: data.model_override })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_chat_messages(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<Vec<ChatMessage>, String> {
    let db = state.db.clone();
    let sid = session_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("SELECT id, session_id, role, content, created FROM chat_messages WHERE session_id = ?1 ORDER BY created ASC").map_err(|e| e.to_string())?;
        let rows = stmt.query_map(params![sid], |row| {
            Ok(ChatMessage { id: row.get(0)?, session_id: row.get(1)?, role: row.get(2)?, content: row.get(3)?, created: row.get(4)? })
        }).map_err(|e| e.to_string())?;
        let mut messages = Vec::new();
        for row in rows { messages.push(row.map_err(|e| e.to_string())?); }
        Ok(messages)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn execute_chat(
    state: State<'_, AppState>,
    request: ExecuteChatRequest,
) -> Result<ExecuteChatResponse, String> {
    let db = state.db.clone();
    let req = request;

    // Save user message
    {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let user_msg_id = uuid::Uuid::new_v4().to_string();
        conn.execute("INSERT INTO chat_messages (id, session_id, role, content, created) VALUES (?1, ?2, 'user', ?3, ?4)",
            params![user_msg_id, req.session_id, req.message, now],
        ).map_err(|e| e.to_string())?;
        conn.execute("UPDATE chat_sessions SET updated = ?1 WHERE id = ?2", params![now, req.session_id]).map_err(|e| e.to_string())?;
    }

    // Get full message history for context
    let messages = {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare("SELECT id, session_id, role, content, created FROM chat_messages WHERE session_id = ?1 ORDER BY created ASC").map_err(|e| e.to_string())?;
        let rows = stmt.query_map(params![req.session_id], |row| {
            Ok(ChatMessage { id: row.get(0)?, session_id: row.get(1)?, role: row.get(2)?, content: row.get(3)?, created: row.get(4)? })
        }).map_err(|e| e.to_string())?;
        let mut msgs = Vec::new();
        for row in rows { msgs.push(row.map_err(|e| e.to_string())?); }
        msgs
    };

    // Get credential data for the model
    let (api_key, base_url, model_name) = get_model_credentials(&db, &req.model_override)?;

    // Call real AI via OpenAI-compatible API
    let ai_response = call_openai_api(&api_key, &base_url, &model_name, &messages, &req.context).await?;

    // Save assistant message and return all
    let session_id = req.session_id.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let assistant_msg_id = uuid::Uuid::new_v4().to_string();
        conn.execute("INSERT INTO chat_messages (id, session_id, role, content, created) VALUES (?1, ?2, 'assistant', ?3, ?4)",
            params![assistant_msg_id, session_id.clone(), ai_response, now],
        ).map_err(|e| e.to_string())?;

        let mut stmt = conn.prepare("SELECT id, session_id, role, content, created FROM chat_messages WHERE session_id = ?1 ORDER BY created ASC").map_err(|e| e.to_string())?;
        let rows = stmt.query_map(params![session_id], |row| {
            Ok(ChatMessage { id: row.get(0)?, session_id: row.get(1)?, role: row.get(2)?, content: row.get(3)?, created: row.get(4)? })
        }).map_err(|e| e.to_string())?;
        let mut msgs = Vec::new();
        for row in rows { msgs.push(row.map_err(|e| e.to_string())?); }
        Ok(ExecuteChatResponse { session_id, messages: msgs })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_chat_session(
    state: State<'_, AppState>,
    session_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    let sid = session_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM chat_messages WHERE session_id = ?1", params![sid]).map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM chat_sessions WHERE id = ?1", params![sid]).map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Session deleted".to_string() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_chat_session(
    state: State<'_, AppState>,
    session_id: String,
    title: Option<String>,
    model_override: Option<String>,
) -> Result<ChatSessionResponse, String> {
    let db = state.db.clone();
    let sid = session_id;

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        // Build dynamic update
        let mut sets = vec!["updated = ?1".to_string()];
        let mut param_idx = 2u32;

        let title_val;
        if let Some(ref t) = title {
            sets.push(format!("title = ?{}", param_idx));
            title_val = t.clone();
            param_idx += 1;
        } else {
            title_val = String::new();
        }

        let model_val;
        if let Some(ref m) = model_override {
            sets.push(format!("model_override = ?{}", param_idx));
            model_val = m.clone();
            param_idx += 1;
        } else {
            model_val = String::new();
        }

        let query = format!("UPDATE chat_sessions SET {} WHERE id = ?{}", sets.join(", "), param_idx);

        // Bind params
        let mut bound: Vec<Box<dyn rusqlite::types::ToSql>> = vec![Box::new(now)];
        if title.is_some() {
            bound.push(Box::new(title_val));
        }
        if model_override.is_some() {
            bound.push(Box::new(model_val));
        }
        bound.push(Box::new(sid.clone()));

        let refs: Vec<&dyn rusqlite::types::ToSql> = bound.iter().map(|b| b.as_ref()).collect();
        conn.execute(&query, refs.as_slice()).map_err(|e| e.to_string())?;

        conn.query_row(
            "SELECT cs.id, cs.title, cs.notebook_id, cs.model_override, cs.created, cs.updated,
                    (SELECT COUNT(*) FROM chat_messages cm WHERE cm.session_id = cs.id) as msg_count
             FROM chat_sessions cs WHERE cs.id = ?1",
            params![sid],
            |row| {
                Ok(ChatSessionResponse {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    notebook_id: row.get(2)?,
                    created: row.get(4)?,
                    updated: row.get(5)?,
                    message_count: row.get(6)?,
                    model_override: row.get(3)?,
                })
            },
        ).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

// ============================================
// AI Integration: OpenAI-compatible API
// ============================================

/// Resolve model name and credential from model_override or default chat model
fn get_model_credentials(
    db: &Database,
    model_override: &Option<String>,
) -> Result<(String, String, String), String> {
    let conn = db.conn.lock().map_err(|e| e.to_string())?;

    // Determine which model to use
    let model_id = if let Some(ref mid) = model_override {
        mid.clone()
    } else {
        // Get default chat model
        conn.query_row(
            "SELECT default_chat_model FROM default_models WHERE id = 'singleton'",
            [],
            |row| row.get::<_, Option<String>>(0),
        ).map_err(|e| e.to_string())?
            .ok_or_else(|| "No default chat model configured. Please set one in Settings.".to_string())?
    };

    // Get model info
    let (provider, name): (String, String) = conn.query_row(
        "SELECT provider, name FROM models WHERE id = ?1",
        params![model_id],
        |row| Ok((row.get(0)?, row.get(1)?)),
    ).map_err(|e| format!("Model '{}' not found", model_id))?;

    // Get credential for this model
    let cred_id: Option<String> = conn.query_row(
        "SELECT credential_id FROM models WHERE id = ?1",
        params![model_id],
        |row| row.get(0),
    ).map_err(|e| e.to_string())?;

    if let Some(cid) = cred_id {
        let encrypted: String = conn.query_row(
            "SELECT encrypted_data FROM credentials WHERE id = ?1",
            params![cid],
            |row| row.get(0),
        ).map_err(|e| e.to_string())?;

        let data: serde_json::Value = serde_json::from_str(
            &String::from_utf8(
                base64::Engine::decode(&base64::engine::general_purpose::STANDARD, &encrypted).unwrap_or_default()
            ).unwrap_or_default()
        ).map_err(|e| format!("Failed to decrypt credential: {}", e))?;

        let api_key = data.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string();
        let base_url = data.get("base_url").and_then(|v| v.as_str()).unwrap_or("").to_string();

        // Determine base_url based on provider
        let effective_base_url = if base_url.is_empty() {
            match provider.as_str() {
                "openai" => "https://api.openai.com/v1".to_string(),
                "anthropic" => "https://api.anthropic.com/v1".to_string(),
                "mistral" => "https://api.mistral.ai/v1".to_string(),
                "groq" => "https://api.groq.com/openai/v1".to_string(),
                "deepseek" => "https://api.deepseek.com/v1".to_string(),
                "ollama" => "http://localhost:11434/v1".to_string(),
                _ => "http://localhost:11434/v1".to_string(), // Default to Ollama
            }
        } else {
            base_url
        };

        Ok((api_key, effective_base_url, name))
    } else {
        // No credential — try Ollama local
        Ok((String::new(), "http://localhost:11434/v1".to_string(), name))
    }
}

/// Call OpenAI-compatible chat completions API
async fn call_openai_api(
    api_key: &str,
    base_url: &str,
    model_name: &str,
    messages: &[ChatMessage],
    context: &Option<serde_json::Value>,
) -> Result<String, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(120))
        .build()
        .map_err(|e| format!("Failed to create HTTP client: {}", e))?;

    // Build system prompt with context
    let mut system_content = "You are a helpful AI research assistant. Answer questions based on the provided context when available. Be concise and accurate.".to_string();

    if let Some(ctx) = context {
        if let Some(sources) = ctx.get("sources").and_then(|v| v.as_array()) {
            if !sources.is_empty() {
                system_content.push_str("\n\n## Sources Context:\n");
                for source in sources {
                    if let Some(text) = source.get("content").and_then(|v| v.as_str()) {
                        system_content.push_str(&format!("\n---\n{}\n", text));
                    }
                }
            }
        }
        if let Some(notes) = ctx.get("notes").and_then(|v| v.as_array()) {
            if !notes.is_empty() {
                system_content.push_str("\n\n## Notes Context:\n");
                for note in notes {
                    if let Some(text) = note.get("content").and_then(|v| v.as_str()) {
                        system_content.push_str(&format!("\n---\n{}\n", text));
                    }
                }
            }
        }
    }

    // Build messages array for API
    let mut api_messages: Vec<serde_json::Value> = vec![
        serde_json::json!({
            "role": "system",
            "content": system_content
        })
    ];

    for msg in messages {
        let role = match msg.role.as_str() {
            "user" => "user",
            "assistant" => "assistant",
            _ => "user",
        };
        api_messages.push(serde_json::json!({
            "role": role,
            "content": msg.content
        }));
    }

    let url = format!("{}/chat/completions", base_url.trim_end_matches('/'));

    log::info!("Calling AI: {} model={}", url, model_name);

    let mut request_builder = client.post(&url)
        .json(&serde_json::json!({
            "model": model_name,
            "messages": api_messages,
            "temperature": 0.7,
            "max_tokens": 4096,
        }));

    if !api_key.is_empty() {
        request_builder = request_builder.header("Authorization", format!("Bearer {}", api_key));
    }

    let response = request_builder.send().await
        .map_err(|e| format!("AI API request failed: {}", e))?;

    let status = response.status();
    let body = response.text().await
        .map_err(|e| format!("Failed to read AI response: {}", e))?;

    if !status.is_success() {
        log::error!("AI API error {}: {}", status, body);
        return Err(format!("AI API returned {}: {}", status, body.chars().take(500).collect::<String>()));
    }

    let json: serde_json::Value = serde_json::from_str(&body)
        .map_err(|e| format!("Failed to parse AI response JSON: {}", e))?;

    let content = json
        .pointer("/choices/0/message/content")
        .and_then(|v| v.as_str())
        .unwrap_or("No response from AI model");

    Ok(content.to_string())
}
