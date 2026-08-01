use crate::db::models::*;
use crate::db::repository::Database;
use crate::ai::process::AIManager;
use rusqlite::params;
use base64::Engine;
use tauri::State;
use super::notebooks::AppState;

#[tauri::command]
pub async fn get_transformations(
    state: State<'_, AppState>,
) -> Result<Vec<Transformation>, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn.prepare(
            "SELECT id, name, description, prompt_template, model_id, created, updated
             FROM transformations ORDER BY name ASC"
        ).map_err(|e| e.to_string())?;

        let rows = stmt.query_map([], |row| {
            Ok(Transformation {
                id: row.get(0)?,
                name: row.get(1)?,
                description: row.get(2)?,
                prompt_template: row.get(3)?,
                model_id: row.get(4)?,
                created: row.get(5)?,
                updated: row.get(6)?,
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
pub async fn create_transformation(
    state: State<'_, AppState>,
    data: TransformationCreate,
) -> Result<Transformation, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        conn.execute(
            "INSERT INTO transformations (id, name, description, prompt_template, model_id, created, updated)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![
                id,
                data.name,
                data.description.clone().unwrap_or_default(),
                data.prompt_template.clone(),
                data.model_id.clone(),
                now.clone(),
                now.clone()
            ],
        ).map_err(|e| e.to_string())?;

        Ok(Transformation {
            id,
            name: data.name,
            description: data.description.unwrap_or_default(),
            prompt_template: data.prompt_template,
            model_id: data.model_id,
            created: now.clone(),
            updated: now,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_transformation(
    state: State<'_, AppState>,
    id: String,
) -> Result<Transformation, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.query_row(
            "SELECT id, name, description, prompt_template, model_id, created, updated
             FROM transformations WHERE id = ?1",
            params![id],
            |row| {
                Ok(Transformation {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    prompt_template: row.get(3)?,
                    model_id: row.get(4)?,
                    created: row.get(5)?,
                    updated: row.get(6)?,
                })
            },
        ).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_transformation(
    state: State<'_, AppState>,
    id: String,
    data: TransformationUpdate,
) -> Result<Transformation, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        let mut set_clauses = vec!["updated = ?1".to_string()];
        let mut bound: Vec<Box<dyn rusqlite::types::ToSql>> = vec![Box::new(now.clone())];
        let mut param_idx = 2u32;

        if let Some(ref name) = data.name {
            set_clauses.push(format!("name = ?{}", param_idx));
            bound.push(Box::new(name.clone()));
            param_idx += 1;
        }
        if let Some(ref desc) = data.description {
            set_clauses.push(format!("description = ?{}", param_idx));
            bound.push(Box::new(desc.clone()));
            param_idx += 1;
        }
        if let Some(ref prompt) = data.prompt_template {
            set_clauses.push(format!("prompt_template = ?{}", param_idx));
            bound.push(Box::new(prompt.clone()));
            param_idx += 1;
        }
        if let Some(ref model_id) = data.model_id {
            set_clauses.push(format!("model_id = ?{}", param_idx));
            bound.push(Box::new(model_id.clone()));
            param_idx += 1;
        }

        let sql = format!(
            "UPDATE transformations SET {} WHERE id = ?{}",
            set_clauses.join(", "),
            param_idx
        );
        bound.push(Box::new(id.clone()));

        let mut stmt = conn.prepare(&sql).map_err(|e| e.to_string())?;
        let bound_refs: Vec<&dyn rusqlite::types::ToSql> =
            bound.iter().map(|b| b.as_ref()).collect();
        stmt.execute(rusqlite::params_from_iter(bound_refs.iter()))
            .map_err(|e| e.to_string())?;

        conn.query_row(
            "SELECT id, name, description, prompt_template, model_id, created, updated
             FROM transformations WHERE id = ?1",
            params![id],
            |row| {
                Ok(Transformation {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    prompt_template: row.get(3)?,
                    model_id: row.get(4)?,
                    created: row.get(5)?,
                    updated: row.get(6)?,
                })
            },
        ).map_err(|e| e.to_string())
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn get_default_prompt(
    state: State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let value: String = conn.query_row(
            "SELECT value FROM settings WHERE key = 'transformation_instructions'",
            [],
            |row| row.get(0),
        ).unwrap_or_default();

        Ok(serde_json::json!({
            "transformation_instructions": value,
        }))
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_default_prompt(
    state: State<'_, AppState>,
    prompt: serde_json::Value,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();
        let instructions = prompt.get("transformation_instructions")
            .and_then(|v| v.as_str())
            .unwrap_or_default();

        conn.execute(
            "INSERT INTO settings (key, value, updated) VALUES ('transformation_instructions', ?1, ?2)
             ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated = excluded.updated",
            params![instructions, now],
        ).map_err(|e| e.to_string())?;

        Ok(SuccessResponse {
            success: true,
            message: "Default prompt updated".to_string(),
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_transformation(
    state: State<'_, AppState>,
    id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM transformations WHERE id = ?1", params![id])
            .map_err(|e| e.to_string())?;
        Ok(SuccessResponse {
            success: true,
            message: "Transformation deleted".to_string(),
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn apply_transformation(
    state: State<'_, AppState>,
    transformation_id: String,
    input_text: String,
) -> Result<serde_json::Value, String> {
    let db = state.db.clone();
    let ai = state.ai_manager.clone();

    // Get transformation prompt and model
    let (prompt_template, model_id) = {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.query_row(
            "SELECT prompt_template, model_id FROM transformations WHERE id = ?1",
            params![transformation_id],
            |row| Ok((row.get::<_, String>(0)?, row.get::<_, Option<String>>(1)?)),
        ).map_err(|e| format!("Transformation not found: {}", e))?
    };

    // Resolve model credentials
    let (api_key, base_url, model_name) = if let Some(ref mid) = model_id {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let (provider, name): (String, String) = conn.query_row(
            "SELECT provider, name FROM models WHERE id = ?1",
            params![mid],
            |row| Ok((row.get(0)?, row.get(1)?)),
        ).map_err(|e| e.to_string())?;

        let cred_id: Option<String> = conn.query_row(
            "SELECT credential_id FROM models WHERE id = ?1",
            params![mid],
            |row| row.get(0),
        ).unwrap_or(None);

        if let Some(cid) = cred_id {
            let encrypted: String = conn.query_row(
                "SELECT encrypted_data FROM credentials WHERE id = ?1",
                params![cid],
                |row| row.get(0),
            ).unwrap_or_default();

            let data: serde_json::Value = serde_json::from_str(
                &String::from_utf8(
                    base64::Engine::decode(&base64::engine::general_purpose::STANDARD, &encrypted).unwrap_or_default()
                ).unwrap_or_default()
            ).unwrap_or_default();

            let api_key = data.get("api_key").and_then(|v| v.as_str()).unwrap_or("").to_string();
            let base_url = data.get("base_url").and_then(|v| v.as_str()).unwrap_or("").to_string();

            let effective_base_url = if base_url.is_empty() {
                match provider.as_str() {
                    "openai" => "https://api.openai.com/v1".to_string(),
                    "anthropic" => "https://api.anthropic.com/v1".to_string(),
                    "mistral" => "https://api.mistral.ai/v1".to_string(),
                    "groq" => "https://api.groq.com/openai/v1".to_string(),
                    "deepseek" => "https://api.deepseek.com/v1".to_string(),
                    "ollama" => "http://localhost:11434/v1".to_string(),
                    _ => "http://localhost:11434/v1".to_string(),
                }
            } else {
                base_url
            };

            (api_key, effective_base_url, name)
        } else {
            (String::new(), "http://localhost:11434/v1".to_string(), name)
        }
    } else {
        // No model specified — use default
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let default_model_id: Option<String> = conn.query_row(
            "SELECT default_transformation_model FROM default_models WHERE id = 'singleton'",
            [],
            |row| row.get(0),
        ).unwrap_or(None);

        if let Some(dmid) = default_model_id {
            let (provider, name): (String, String) = conn.query_row(
                "SELECT provider, name FROM models WHERE id = ?1",
                params![dmid],
                |row| Ok((row.get(0)?, row.get(1)?)),
            ).unwrap_or(("ollama".into(), "gemma3:4b".into()));

            let base_url = match provider.as_str() {
                "ollama" => "http://localhost:11434/v1".to_string(),
                "openai" => "https://api.openai.com/v1".to_string(),
                _ => "http://localhost:11434/v1".to_string(),
            };

            (String::new(), base_url, name)
        } else {
            (String::new(), "http://localhost:11434/v1".to_string(), "gemma3:4b".to_string())
        }
    };

    let output = ai.transform(&input_text, &prompt_template, &api_key, &base_url, &model_name).await?;

    Ok(serde_json::json!({
        "output": output,
        "model": model_name,
    }))
}
