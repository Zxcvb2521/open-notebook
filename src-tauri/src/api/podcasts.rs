use rusqlite::OptionalExtension;
use serde_json::json;
use tauri::State;

use crate::db::models::*;

use super::notebooks::AppState;

fn now_utc() -> String {
    chrono::Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string()
}

fn parse_speakers(raw: Option<String>) -> Vec<SpeakerVoiceConfig> {
    match raw {
        Some(s) if !s.trim().is_empty() => {
            serde_json::from_str(&s).unwrap_or_default()
        }
        _ => Vec::new(),
    }
}

// ============================================
// SPEAKER PROFILES
// ============================================

#[tauri::command]
pub async fn get_speaker_profiles(
    state: State<'_, AppState>,
) -> Result<Vec<SpeakerProfile>, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut stmt = conn
            .prepare("SELECT id, name, description, voice_model, speakers, created, updated FROM speaker_profiles ORDER BY name")
            .map_err(|e| e.to_string())?;
        let rows = stmt
            .query_map([], |row| {
                Ok(SpeakerProfile {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    voice_model: row.get(3)?,
                    speakers: parse_speakers(row.get(4)?),
                    created: row.get(5)?,
                    updated: row.get(6)?,
                })
            })
            .map_err(|e| e.to_string())?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| e.to_string())?;
        Ok(rows)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn create_speaker_profile(
    state: State<'_, AppState>,
    data: SpeakerProfileInput,
) -> Result<SpeakerProfile, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = now_utc();
        let speakers_json = serde_json::to_string(&data.speakers).unwrap_or_else(|_| "[]".into());
        let description = data.description.unwrap_or_default();
        conn.execute(
            "INSERT INTO speaker_profiles (id, name, description, voice_model, speakers, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            rusqlite::params![id, data.name, description, data.voice_model, speakers_json, now.clone(), now.clone()],
        )
        .map_err(|e| e.to_string())?;
        Ok(SpeakerProfile {
            id,
            name: data.name,
            description,
            voice_model: data.voice_model,
            speakers: data.speakers,
            created: now.clone(),
            updated: now,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_speaker_profile(
    state: State<'_, AppState>,
    profile_id: String,
    data: SpeakerProfileInput,
) -> Result<SpeakerProfile, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = now_utc();
        let speakers_json = serde_json::to_string(&data.speakers).unwrap_or_else(|_| "[]".into());
        let description = data.description.unwrap_or_default();
        let affected = conn
            .execute(
                "UPDATE speaker_profiles SET name = ?1, description = ?2, voice_model = ?3, speakers = ?4, updated = ?5 WHERE id = ?6",
                rusqlite::params![data.name, description, data.voice_model, speakers_json, now.clone(), profile_id],
            )
            .map_err(|e| e.to_string())?;
        if affected == 0 {
            return Err("Speaker profile not found".to_string());
        }
        Ok(SpeakerProfile {
            id: profile_id,
            name: data.name,
            description,
            voice_model: data.voice_model,
            speakers: data.speakers,
            created: now.clone(),
            updated: now,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_speaker_profile(
    state: State<'_, AppState>,
    profile_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM speaker_profiles WHERE id = ?1", rusqlite::params![profile_id])
            .map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Speaker profile deleted".into() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn duplicate_speaker_profile(
    state: State<'_, AppState>,
    profile_id: String,
) -> Result<SpeakerProfile, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let existing: Option<(String, String, Option<String>, Option<String>, String, String)> = conn
            .query_row(
                "SELECT name, description, voice_model, speakers, created, updated FROM speaker_profiles WHERE id = ?1",
                rusqlite::params![profile_id],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?, row.get(4)?, row.get(5)?)),
            )
            .optional()
            .map_err(|e| e.to_string())?;
        let (name, description, voice_model, speakers, _created, _updated) =
            existing.ok_or_else(|| "Speaker profile not found".to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = now_utc();
        let dup_name = format!("{} (copy)", name);
        conn.execute(
            "INSERT INTO speaker_profiles (id, name, description, voice_model, speakers, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            rusqlite::params![id, dup_name, description, voice_model, speakers, now.clone(), now.clone()],
        )
        .map_err(|e| e.to_string())?;
        Ok(SpeakerProfile {
            id,
            name: dup_name,
            description,
            voice_model,
            speakers: parse_speakers(speakers),
            created: now.clone(),
            updated: now,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

// ============================================
// EPISODE PROFILES
// ============================================

fn row_episode(row: &rusqlite::Row) -> rusqlite::Result<EpisodeProfile> {
    Ok(EpisodeProfile {
        id: row.get(0)?,
        name: row.get(1)?,
        description: row.get(2)?,
        speaker_config: row.get(3)?,
        speaker_config_name: None,
        outline_llm: row.get(4)?,
        transcript_llm: row.get(5)?,
        language: row.get(6)?,
        default_briefing: row.get(7)?,
        num_segments: row.get(8)?,
        max_tokens: row.get(9)?,
    })
}

#[tauri::command]
pub async fn get_episode_profiles(
    state: State<'_, AppState>,
) -> Result<Vec<EpisodeProfile>, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let mut profiles: Vec<EpisodeProfile> = conn
            .prepare(
                "SELECT id, name, description, speaker_config, outline_llm, transcript_llm, language, default_briefing, num_segments, max_tokens FROM episode_profiles ORDER BY name",
            )
            .map_err(|e| e.to_string())?
            .query_map([], row_episode)
            .map_err(|e| e.to_string())?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| e.to_string())?;

        // Resolve speaker_config -> name for display
        let mut name_by_id: std::collections::HashMap<String, String> = std::collections::HashMap::new();
        if let Ok(mut stmt) = conn.prepare("SELECT id, name FROM speaker_profiles") {
            if let Ok(rows) = stmt.query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, String>(1)?))) {
                for row in rows.flatten() {
                    name_by_id.insert(row.0, row.1);
                }
            }
        }
        for p in profiles.iter_mut() {
            if let Some(ref sid) = p.speaker_config {
                p.speaker_config_name = name_by_id.get(sid).cloned();
            }
        }
        Ok(profiles)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn create_episode_profile(
    state: State<'_, AppState>,
    data: EpisodeProfileInput,
) -> Result<EpisodeProfile, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = now_utc();
        let description = data.description.unwrap_or_default();
        let default_briefing = data.default_briefing.unwrap_or_default();
        let num_segments = data.num_segments.unwrap_or(5);
        conn.execute(
            "INSERT INTO episode_profiles (id, name, description, speaker_config, outline_llm, transcript_llm, language, default_briefing, num_segments, max_tokens, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
            rusqlite::params![
                id,
                data.name,
                description,
                data.speaker_config,
                data.outline_llm,
                data.transcript_llm,
                data.language,
                default_briefing,
                num_segments,
                data.max_tokens,
                now.clone(),
                now.clone(),
            ],
        )
        .map_err(|e| e.to_string())?;
        Ok(EpisodeProfile {
            id,
            name: data.name,
            description,
            speaker_config: data.speaker_config,
            speaker_config_name: None,
            outline_llm: data.outline_llm,
            transcript_llm: data.transcript_llm,
            language: data.language,
            default_briefing,
            num_segments,
            max_tokens: data.max_tokens,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn update_episode_profile(
    state: State<'_, AppState>,
    profile_id: String,
    data: EpisodeProfileInput,
) -> Result<EpisodeProfile, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let now = now_utc();
        let description = data.description.unwrap_or_default();
        let default_briefing = data.default_briefing.unwrap_or_default();
        let num_segments = data.num_segments.unwrap_or(5);
        let affected = conn
            .execute(
                "UPDATE episode_profiles SET name = ?1, description = ?2, speaker_config = ?3, outline_llm = ?4, transcript_llm = ?5, language = ?6, default_briefing = ?7, num_segments = ?8, max_tokens = ?9, updated = ?10 WHERE id = ?11",
                rusqlite::params![
                    data.name,
                    description,
                    data.speaker_config,
                    data.outline_llm,
                    data.transcript_llm,
                    data.language,
                    default_briefing,
                    num_segments,
                    data.max_tokens,
                    now.clone(),
                    profile_id,
                ],
            )
            .map_err(|e| e.to_string())?;
        if affected == 0 {
            return Err("Episode profile not found".to_string());
        }
        Ok(EpisodeProfile {
            id: profile_id,
            name: data.name,
            description,
            speaker_config: data.speaker_config,
            speaker_config_name: None,
            outline_llm: data.outline_llm,
            transcript_llm: data.transcript_llm,
            language: data.language,
            default_briefing,
            num_segments,
            max_tokens: data.max_tokens,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_episode_profile(
    state: State<'_, AppState>,
    profile_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM episode_profiles WHERE id = ?1", rusqlite::params![profile_id])
            .map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Episode profile deleted".into() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn duplicate_episode_profile(
    state: State<'_, AppState>,
    profile_id: String,
) -> Result<EpisodeProfile, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let existing: Option<EpisodeProfile> = conn
            .query_row(
                "SELECT id, name, description, speaker_config, outline_llm, transcript_llm, language, default_briefing, num_segments, max_tokens FROM episode_profiles WHERE id = ?1",
                rusqlite::params![profile_id],
                row_episode,
            )
            .optional()
            .map_err(|e| e.to_string())?;
        let src = existing.ok_or_else(|| "Episode profile not found".to_string())?;
        let id = uuid::Uuid::new_v4().to_string();
        let now = now_utc();
        let dup_name = format!("{} (copy)", src.name);
        conn.execute(
            "INSERT INTO episode_profiles (id, name, description, speaker_config, outline_llm, transcript_llm, language, default_briefing, num_segments, max_tokens, created, updated) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
            rusqlite::params![
                id,
                dup_name,
                src.description,
                src.speaker_config,
                src.outline_llm,
                src.transcript_llm,
                src.language,
                src.default_briefing,
                src.num_segments,
                src.max_tokens,
                now.clone(),
                now.clone(),
            ],
        )
        .map_err(|e| e.to_string())?;
        Ok(EpisodeProfile {
            id,
            name: dup_name,
            description: src.description,
            speaker_config: src.speaker_config,
            speaker_config_name: None,
            outline_llm: src.outline_llm,
            transcript_llm: src.transcript_llm,
            language: src.language,
            default_briefing: src.default_briefing,
            num_segments: src.num_segments,
            max_tokens: src.max_tokens,
        })
    })
    .await
    .map_err(|e| e.to_string())?
}

// ============================================
// EPISODES
// ============================================

#[tauri::command]
pub async fn get_episodes(
    state: State<'_, AppState>,
) -> Result<Vec<PodcastEpisode>, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        let episodes: Vec<PodcastEpisode> = conn
            .prepare(
                "SELECT id, name, briefing, audio_path, transcript, outline, created, job_status, error_message FROM podcast_episodes ORDER BY created DESC",
            )
            .map_err(|e| e.to_string())?
            .query_map([], |row| {
                Ok(PodcastEpisode {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    episode_profile: None,
                    speaker_profile: None,
                    briefing: row.get(2)?,
                    audio_file: row.get(3)?,
                    audio_url: None,
                    transcript: None,
                    outline: None,
                    created: row.get(6)?,
                    job_status: row.get(7)?,
                    error_message: row.get(8)?,
                })
            })
            .map_err(|e| e.to_string())?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|e| e.to_string())?;
        Ok(episodes)
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn delete_episode(
    state: State<'_, AppState>,
    episode_id: String,
) -> Result<SuccessResponse, String> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db.conn.lock().map_err(|e| e.to_string())?;
        conn.execute("DELETE FROM podcast_episodes WHERE id = ?1", rusqlite::params![episode_id])
            .map_err(|e| e.to_string())?;
        Ok(SuccessResponse { success: true, message: "Episode deleted".into() })
    })
    .await
    .map_err(|e| e.to_string())?
}

#[tauri::command]
pub async fn retry_episode(
    _state: State<'_, AppState>,
    episode_id: String,
) -> Result<serde_json::Value, String> {
    Err(format!("Повторная генерация эпизода {} пока недоступна в этой сборке.", episode_id))
}

// ============================================
// LANGUAGES
// ============================================
#[tauri::command]
pub async fn get_languages() -> Result<Vec<Language>, String> {
    let languages = vec![
        Language { code: "ru-RU".into(), name: "Русский".into() },
        Language { code: "en-US".into(), name: "English (US)".into() },
        Language { code: "en-GB".into(), name: "English (UK)".into() },
        Language { code: "de-DE".into(), name: "Deutsch".into() },
        Language { code: "fr-FR".into(), name: "Français".into() },
        Language { code: "es-ES".into(), name: "Español".into() },
        Language { code: "it-IT".into(), name: "Italiano".into() },
        Language { code: "pt-BR".into(), name: "Português (Brasil)".into() },
        Language { code: "zh-CN".into(), name: "中文 (简体)".into() },
        Language { code: "zh-TW".into(), name: "中文 (繁體)".into() },
        Language { code: "ja-JP".into(), name: "日本語".into() },
        Language { code: "ko-KR".into(), name: "한국어".into() },
        Language { code: "pl-PL".into(), name: "Polski".into() },
        Language { code: "uk-UA".into(), name: "Українська".into() },
        Language { code: "tr-TR".into(), name: "Türkçe".into() },
        Language { code: "nl-NL".into(), name: "Nederlands".into() },
        Language { code: "sv-SE".into(), name: "Svenska".into() },
        Language { code: "fi-FI".into(), name: "Suomi".into() },
        Language { code: "da-DK".into(), name: "Dansk".into() },
        Language { code: "no-NO".into(), name: "Norsk".into() },
    ];
    Ok(languages)
}

// ============================================
// GENERATE PODCAST (placeholder)
// ============================================

#[tauri::command]
pub async fn generate_podcast(
    _state: State<'_, AppState>,
    data: PodcastGenerationRequest,
) -> Result<PodcastGenerationResponse, String> {
    Err(format!(
        "Генерация подкастов пока недоступна в этой сборке. Выбрано: профиль эпизода '{}', спикер '{}'.",
        data.episode_profile, data.speaker_profile
    ))
}
