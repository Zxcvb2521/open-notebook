use tauri::State;
use super::notebooks::AppState;

/// Repository used to check for new releases.
/// The original upstream is lfnovo/open-notebook; our Tauri port is published
/// separately. Change the owner/repo here to point at your own release repo.
const UPDATE_REPO_OWNER: &str = "lfnovo";
const UPDATE_REPO_NAME: &str = "open-notebook";

#[tauri::command]
pub async fn get_commands(
    _state: State<'_, AppState>,
) -> Result<Vec<serde_json::Value>, String> {
    Ok(vec![])
}

/// Check the latest release version on GitHub.
/// Returns { latest_version, has_update, current_version, url }.
/// `has_update` is advisory only — the upstream repo uses its own versioning,
/// so the frontend shows the info but never forces anything.
#[tauri::command]
pub async fn check_updates() -> Result<serde_json::Value, String> {
    let url = format!(
        "https://api.github.com/repos/{}/{}/releases/latest",
        UPDATE_REPO_OWNER, UPDATE_REPO_NAME
    );

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .user_agent("Open-Notebook-Tauri/0.1.0")
        .build()
        .map_err(|e| format!("HTTP client: {}", e))?;

    let resp = client.get(&url).send().await.map_err(|e| e.to_string())?;

    if !resp.status().is_success() {
        // Rate limited / not found / offline — report "unknown", no panic
        return Ok(serde_json::json!({
            "latest_version": null,
            "has_update": false,
            "url": format!("https://github.com/{}/{}/releases", UPDATE_REPO_OWNER, UPDATE_REPO_NAME),
        }));
    }

    let body: serde_json::Value = resp.json().await.map_err(|e| e.to_string())?;
    let latest = body.get("tag_name").and_then(|v| v.as_str()).unwrap_or("").to_string();
    let default_url = format!("https://github.com/{}/{}/releases", UPDATE_REPO_OWNER, UPDATE_REPO_NAME);
    let html_url = body
        .get("html_url")
        .and_then(|v| v.as_str())
        .unwrap_or(&default_url)
        .to_string();

    // Semantic compare vs current app version (0.1.0-tauri)
    let current = "0.1.0";
    let has_update = compare_versions(&latest, current) > 0;

    Ok(serde_json::json!({
        "latest_version": latest,
        "has_update": has_update,
        "url": html_url,
    }))
}

/// Compare two dotted version strings (e.g. "1.2.3" vs "1.2.4").
/// Returns >0 if a > b, <0 if a < b, 0 if equal. Non-numeric segments are ignored.
fn compare_versions(a: &str, b: &str) -> i32 {
    let a_parts: Vec<&str> = a.trim_start_matches('v').split('.').collect();
    let b_parts: Vec<&str> = b.trim_start_matches('v').split('.').collect();
    let len = a_parts.len().max(b_parts.len());

    for i in 0..len {
        let av = a_parts.get(i).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
        let bv = b_parts.get(i).and_then(|s| s.parse::<i32>().ok()).unwrap_or(0);
        if av != bv {
            return av - bv;
        }
    }
    0
}
