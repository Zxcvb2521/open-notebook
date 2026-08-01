use crate::db::models::*;
use crate::db::repository::Database;
use rusqlite::params;
use tauri::State;
use super::notebooks::AppState;

#[tauri::command]
pub async fn get_settings(
    state: State<'_, AppState>,
) -> Result<serde_json::Value, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;

        // Get all settings as key-value pairs
        let mut result = serde_json::json!({});

        let mut stmt = conn.prepare("SELECT key, value FROM settings")
            .map_err(|e| e.to_string())?;
        let rows = stmt.query_map([], |row| {
            let key: String = row.get(0)?;
            let value: String = row.get(1)?;
            Ok((key, value))
        }).map_err(|e| e.to_string())?;

        for row in rows {
            let (key, value) = row.map_err(|e| e.to_string())?;
            // Try to parse as JSON, fallback to string
            let parsed = serde_json::from_str::<serde_json::Value>(&value)
                .unwrap_or_else(|_| serde_json::json!(value));
            result[key] = parsed;
        }

        // Also get content settings
        // Convert docling_* TEXT columns ("true"/"false"/"auto"/NULL) into real
        // booleans so the frontend checkboxes render correctly.
        let parse_bool = |v: Option<String>| -> Option<bool> {
            match v.as_deref() {
                Some("true") | Some("1") => Some(true),
                Some("false") | Some("0") => Some(false),
                _ => None,
            }
        };
        let content = conn.query_row(
            "SELECT default_content_processing_engine_url, default_content_processing_engine_doc,
                    docling_ocr, docling_formulas, docling_vision
             FROM content_settings WHERE id = 'singleton'",
            [],
            |row| {
                Ok(serde_json::json!({
                    "default_content_processing_engine_url": row.get::<_, Option<String>>(0)?,
                    "default_content_processing_engine_doc": row.get::<_, Option<String>>(1)?,
                    "docling_ocr": parse_bool(row.get::<_, Option<String>>(2)?),
                    "docling_formulas": parse_bool(row.get::<_, Option<String>>(3)?),
                    "docling_vision": parse_bool(row.get::<_, Option<String>>(4)?),
                }))
            },
        ).unwrap_or_else(|_| serde_json::json!({}));

        // Merge content settings into result
        if let (Some(obj), Some(content_obj)) = (result.as_object_mut(), content.as_object()) {
            for (k, v) in content_obj {
                obj.insert(k.clone(), v.clone());
            }
        }

        Ok(result)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_settings(
    state: State<'_, AppState>,
    settings: serde_json::Value,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();

    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string();

        // Update content settings
        let engine_url = settings.get("default_content_processing_engine_url").and_then(|v| v.as_str());
        let engine_doc = settings.get("default_content_processing_engine_doc").and_then(|v| v.as_str());
        // Frontend sends booleans for the docling toggles; the DB stores TEXT.
        // Accept bool OR "true"/"false" strings so save actually persists.
        let bool_to_db = |v: Option<&serde_json::Value>| -> Option<String> {
            match v {
                Some(serde_json::Value::Bool(b)) => Some(b.to_string()),
                Some(serde_json::Value::String(s)) if s == "true" || s == "false" => Some(s.clone()),
                _ => None,
            }
        };
        let ocr = bool_to_db(settings.get("docling_ocr"));
        let formulas = bool_to_db(settings.get("docling_formulas"));
        let vision = bool_to_db(settings.get("docling_vision"));

        if engine_url.is_some() || engine_doc.is_some() || ocr.is_some() || formulas.is_some() || vision.is_some() {
            conn.execute(
                "UPDATE content_settings SET
                    default_content_processing_engine_url = COALESCE(?1, default_content_processing_engine_url),
                    default_content_processing_engine_doc = COALESCE(?2, default_content_processing_engine_doc),
                    docling_ocr = COALESCE(?3, docling_ocr),
                    docling_formulas = COALESCE(?4, docling_formulas),
                    docling_vision = COALESCE(?5, docling_vision),
                    updated = ?6
                 WHERE id = 'singleton'",
                params![engine_url, engine_doc, ocr, formulas, vision, now],
            ).map_err(|e| e.to_string())?;
        }

        // Update all other settings as key-value pairs
        let skip_keys = [
            "default_content_processing_engine_url",
            "default_content_processing_engine_doc",
            "docling_ocr", "docling_formulas", "docling_vision",
        ];

        if let Some(obj) = settings.as_object() {
            for (key, value) in obj {
                if skip_keys.contains(&key.as_str()) {
                    continue;
                }
                let val_str = match value {
                    serde_json::Value::String(s) => s.clone(),
                    other => other.to_string(),
                };
                conn.execute(
                    "INSERT INTO settings (key, value, updated) VALUES (?1, ?2, ?3)
                     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated = excluded.updated",
                    params![key, val_str, now],
                ).map_err(|e| e.to_string())?;
            }
        }

        Ok(SuccessResponse {
            success: true,
            message: "Settings updated".to_string(),
        })
    })
    .await
    .map_err(|e| e.to_string())?
}
