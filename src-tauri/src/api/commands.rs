use tauri::State;
use super::notebooks::AppState;

/// Repository used to check for new releases.
/// This is the Tauri port repo. The original upstream (lfnovo/open-notebook)
/// is a different app (Next.js) whose releases do NOT apply to this build.
/// Change owner/repo here to point at your own release repo.
const UPDATE_REPO_OWNER: &str = "Zxcvb2521";
const UPDATE_REPO_NAME: &str = "open-notebook";

#[tauri::command]
pub async fn get_commands(
    _state: State<'_, AppState>,
) -> Result<Vec<serde_json::Value>, String> {
    Ok(vec![])
}

/// Check the latest release version on GitHub.
/// Returns { latest_version, has_update, current_version, url }.
/// Only `win-*` releases (the Tauri/Windows build) are considered: this repo
/// also hosts releases for the original web app, which do NOT apply to this
/// app. `has_update` is advisory only — the frontend shows the info but never
/// forces anything.
#[tauri::command]
pub async fn check_updates() -> Result<serde_json::Value, String> {
    let url = format!(
        "https://api.github.com/repos/{}/{}/releases?per_page=20",
        UPDATE_REPO_OWNER, UPDATE_REPO_NAME
    );

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .user_agent("Open-Notebook-Tauri/1.14.0")
        .build()
        .map_err(|e| format!("HTTP client: {}", e))?;

    let resp = client.get(&url).send().await.map_err(|e| e.to_string())?;

    let default_url = format!(
        "https://github.com/{}/{}/releases",
        UPDATE_REPO_OWNER, UPDATE_REPO_NAME
    );

    if !resp.status().is_success() {
        // Rate limited / not found / offline — report "unknown", no panic
        return Ok(serde_json::json!({
            "latest_version": null,
            "has_update": false,
            "url": default_url,
        }));
    }

    // Pick the newest release whose tag starts with "win-" (the Tauri build).
    let releases: Vec<serde_json::Value> = resp.json().await.map_err(|e| e.to_string())?;
    let win_release = releases.iter().find(|r| {
        r.get("tag_name")
            .and_then(|v| v.as_str())
            .map(|t| t.starts_with("win-"))
            .unwrap_or(false)
    });

    let Some(rel) = win_release else {
        // No Windows/Tauri releases published yet
        return Ok(serde_json::json!({
            "latest_version": null,
            "has_update": false,
            "url": default_url,
        }));
    };

    let latest = rel
        .get("tag_name")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let html_url = rel
        .get("html_url")
        .and_then(|v| v.as_str())
        .unwrap_or(&default_url)
        .to_string();

    // Semantic compare vs current app version (1.14.0)
    let current = "1.14.0";
    let has_update = compare_versions(&latest, current) > 0;

    Ok(serde_json::json!({
        "latest_version": latest,
        "has_update": has_update,
        "url": html_url,
    }))
}

/// Compare two dotted version strings (e.g. "1.2.3" vs "1.2.4").
/// Returns >0 if a > b, <0 if a < b, 0 if equal.
/// Handles tags with a non-numeric prefix such as "win-v1.13.0" (the prefix
/// is skipped, so it compares as 1.13.0).
fn compare_versions(a: &str, b: &str) -> i32 {
    fn parse_parts(s: &str) -> Vec<i32> {
        // Skip any non-digit prefix (e.g. "win-v1.13.0" -> "1.13.0")
        let digits_start = s.find(|c: char| c.is_ascii_digit()).unwrap_or(0);
        s[digits_start..]
            .split(|c: char| !c.is_ascii_digit())
            .filter_map(|seg| seg.parse::<i32>().ok())
            .collect()
    }

    let a_parts = parse_parts(a);
    let b_parts = parse_parts(b);
    let len = a_parts.len().max(b_parts.len());

    for i in 0..len {
        let av = a_parts.get(i).copied().unwrap_or(0);
        let bv = b_parts.get(i).copied().unwrap_or(0);
        if av != bv {
            return av - bv;
        }
    }
    0
}
