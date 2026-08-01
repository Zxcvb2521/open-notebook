mod db;
mod api;
mod ai;

use std::sync::Arc;
use api::notebooks::AppState;
use ai::process::AIManager;
use db::repository::Database;
use tauri::Manager;
use tauri_plugin_opener::OpenerExt;

/// Opens an external URL in the system default browser.
/// Uses the opener plugin so links work inside the Tauri WebView.
#[tauri::command]
fn open_external(app: tauri::AppHandle, url: String) -> Result<(), String> {
    // Only allow http/https links for safety
    if !url.starts_with("http://") && !url.starts_with("https://") {
        return Err("Only http/https URLs are allowed".into());
    }
    app.opener().open_url(url, None::<&str>).map_err(|e| e.to_string())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_log::Builder::new().build())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_opener::init())
        .setup(|app| {
            let app_dir = app.path().app_data_dir().expect("Failed to get app data dir");
            std::fs::create_dir_all(&app_dir).expect("Failed to create app data dir");
            
            let data_dir = app_dir.join("data");
            std::fs::create_dir_all(&data_dir).expect("Failed to create data dir");

            // Ensure plugins dir exists (for Python AI service)
            let _ = std::fs::create_dir_all(app_dir.join("plugins"));
            
            // Initialize database
            let db = Database::new(data_dir.clone()).expect("Failed to initialize database");
            let db = Arc::new(db);

            // Initialize AI manager (starts Python service)
            let ai_manager = Arc::new(AIManager::new(app_dir.clone()));
            // Health check will happen async on first actual use; startup is fire-and-forget
            log::info!("AI manager initialized");
            
            // Store state
            app.manage(AppState { db, ai_manager });
            
            log::info!("Open Notebook initialized. Data dir: {:?}", data_dir);
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            // Notebooks
            api::notebooks::list_notebooks,
            api::notebooks::get_notebook,
            api::notebooks::create_notebook,
            api::notebooks::update_notebook,
            api::notebooks::delete_notebook,
            api::notebooks::get_notebook_delete_preview,
            api::notebooks::get_recently_viewed,
            // Sources
            api::sources::get_sources,
            api::sources::get_source,
            api::sources::create_source,
            api::sources::update_source,
            api::sources::delete_source,
            api::sources::get_source_insights,
            api::sources::add_source_to_notebook,
            api::sources::remove_source_from_notebook,
            api::sources::process_source_content,
            // Notes
            api::notes::get_notes,
            api::notes::create_note,
            api::notes::update_note,
            api::notes::delete_note,
            api::notes::get_note,
            // Models
            api::models::get_models,
            api::models::create_model,
            api::models::delete_model,
            api::models::get_default_models,
            api::models::update_default_models,
            // Chat
            api::chat::get_chat_sessions,
            api::chat::create_chat_session,
            api::chat::get_chat_messages,
            api::chat::execute_chat,
            api::chat::delete_chat_session,
            api::chat::update_chat_session,
            // Transformations
            api::transformations::get_transformations,
            api::transformations::get_transformation,
            api::transformations::create_transformation,
            api::transformations::update_transformation,
            api::transformations::delete_transformation,
            api::transformations::apply_transformation,
            api::transformations::get_default_prompt,
            api::transformations::update_default_prompt,
            // Settings
            api::settings::get_settings,
            api::settings::update_settings,
            // Credentials
            api::credentials::get_credentials,
            api::credentials::create_credential,
            api::credentials::get_credential_data,
            api::credentials::delete_credential,
            // Search
            api::search::search,
            api::search::semantic_search,
            // AI Service
            api::embedding::rebuild_embeddings,
            api::embedding::check_ai_health,
            // Other
            api::commands::get_commands,
            api::commands::check_updates,
            api::podcasts::get_episodes,
            api::podcasts::delete_episode,
            api::podcasts::retry_episode,
            api::podcasts::get_speaker_profiles,
            api::podcasts::create_speaker_profile,
            api::podcasts::update_speaker_profile,
            api::podcasts::delete_speaker_profile,
            api::podcasts::duplicate_speaker_profile,
            api::podcasts::get_episode_profiles,
            api::podcasts::create_episode_profile,
            api::podcasts::update_episode_profile,
            api::podcasts::delete_episode_profile,
            api::podcasts::duplicate_episode_profile,
            api::podcasts::get_languages,
            api::podcasts::generate_podcast,
            api::auth::check_auth,
            api::auth::login,
            api::providers::get_providers,
            // System
            open_external,
        ])
        .build(tauri::generate_context!())
        .expect("error while building tauri application")
        .run(|app_handle, event| {
            // Stop the Python AI service when the app exits so it doesn't
            // linger as a zombie python.exe in the system tray/processes.
            if let tauri::RunEvent::ExitRequested { .. } = event {
                if let Some(state) = app_handle.try_state::<AppState>() {
                    log::info!("Stopping AI service on app exit...");
                    state.ai_manager.stop();
                }
            }
        });
}
