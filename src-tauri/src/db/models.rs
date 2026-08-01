use serde::{Deserialize, Serialize};

// ============================================
// NOTEBOOK
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Notebook {
    pub id: String,
    pub name: String,
    pub description: String,
    pub archived: bool,
    pub last_viewed_at: Option<String>,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct NotebookCreate {
    pub name: String,
    pub description: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct NotebookUpdate {
    pub name: Option<String>,
    pub description: Option<String>,
    pub archived: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NotebookResponse {
    pub id: String,
    pub name: String,
    pub description: String,
    pub archived: bool,
    pub created: String,
    pub updated: String,
    pub source_count: i64,
    pub note_count: i64,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NotebookDeletePreview {
    pub notebook_id: String,
    pub notebook_name: String,
    pub note_count: i64,
    pub exclusive_source_count: i64,
    pub shared_source_count: i64,
}

// ============================================
// SOURCE
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Source {
    pub id: String,
    pub title: String,
    pub full_text: Option<String>,
    pub topics: Option<String>, // JSON array
    pub asset_file_path: Option<String>,
    pub asset_url: Option<String>,
    pub last_viewed_at: Option<String>,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct SourceCreate {
    #[serde(rename = "type")]
    pub source_type: String, // link, upload, text
    pub notebook_id: Option<String>,
    pub notebooks: Option<Vec<String>>,
    pub url: Option<String>,
    pub content: Option<String>,
    pub title: Option<String>,
    pub file_path: Option<String>,
    pub transformations: Option<Vec<String>>,
    pub embed: Option<bool>,
    pub async_processing: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SourceResponse {
    pub id: String,
    pub title: String,
    pub topics: Vec<String>,
    pub asset: Option<AssetModel>,
    pub full_text: Option<String>,
    pub embedded: bool,
    pub embedded_chunks: i64,
    pub created: String,
    pub updated: String,
    pub notebooks: Option<Vec<String>>,
    pub status: Option<String>,
    pub processing_info: Option<serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AssetModel {
    pub file_path: Option<String>,
    pub url: Option<String>,
}

// ============================================
// NOTE
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Note {
    pub id: String,
    pub title: String,
    pub content: String,
    pub notebook_id: String,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct NoteCreate {
    pub title: Option<String>,
    pub content: String,
    pub notebook_id: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct NoteResponse {
    pub id: String,
    pub title: String,
    pub content: String,
    pub notebook_id: String,
    pub created: String,
    pub updated: String,
}

// ============================================
// SOURCE INSIGHT
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceInsight {
    pub id: String,
    pub source_id: String,
    pub insight_type: String,
    pub content: String,
    pub created: String,
    pub updated: String,
}

// ============================================
// MODEL
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Model {
    pub id: String,
    pub name: String,
    pub provider: String,
    #[serde(rename = "type")]
    pub model_type: String,
    pub credential_id: Option<String>,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct ModelCreate {
    pub name: String,
    pub provider: String,
    #[serde(rename = "type")]
    pub model_type: String,
    pub credential_id: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DefaultModelsResponse {
    pub default_chat_model: Option<String>,
    pub default_transformation_model: Option<String>,
    pub large_context_model: Option<String>,
    pub default_text_to_speech_model: Option<String>,
    pub default_speech_to_text_model: Option<String>,
    pub default_embedding_model: Option<String>,
    pub default_tools_model: Option<String>,
}

// ============================================
// CREDENTIAL
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Credential {
    pub id: String,
    pub name: String,
    pub provider: String,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct CredentialCreate {
    pub name: String,
    pub provider: String,
    pub api_key: Option<String>,
    pub base_url: Option<String>,
    pub extra: Option<serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CredentialResponse {
    pub id: String,
    pub name: String,
    pub provider: String,
    pub created: String,
    pub updated: String,
    pub has_api_key: bool,
}

// ============================================
// TRANSFORMATION
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transformation {
    pub id: String,
    pub name: String,
    pub description: String,
    pub prompt_template: String,
    pub model_id: Option<String>,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct TransformationCreate {
    pub name: String,
    pub description: Option<String>,
    pub prompt_template: String,
    pub model_id: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct TransformationUpdate {
    pub name: Option<String>,
    pub description: Option<String>,
    pub prompt_template: Option<String>,
    pub model_id: Option<String>,
}

// ============================================
// CHAT SESSION
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatSession {
    pub id: String,
    pub title: String,
    pub notebook_id: Option<String>,
    pub model_override: Option<String>,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct ChatSessionCreate {
    pub notebook_id: Option<String>,
    pub title: Option<String>,
    pub model_override: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ChatSessionResponse {
    pub id: String,
    pub title: String,
    pub notebook_id: Option<String>,
    pub created: String,
    pub updated: String,
    pub message_count: i64,
    pub model_override: Option<String>,
}

// ============================================
// CHAT MESSAGE
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatMessage {
    pub id: String,
    pub session_id: String,
    pub role: String,
    pub content: String,
    pub created: String,
}

#[derive(Debug, Deserialize)]
pub struct ExecuteChatRequest {
    pub session_id: String,
    pub message: String,
    pub context: Option<serde_json::Value>,
    pub model_override: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ExecuteChatResponse {
    pub session_id: String,
    pub messages: Vec<ChatMessage>,
}

// ============================================
// SEARCH
// ============================================
#[derive(Debug, Deserialize)]
pub struct SearchRequest {
    pub query: String,
    #[serde(default = "default_search_type")]
    pub search_type: String,
    #[serde(default = "default_limit")]
    pub limit: i64,
    #[serde(default = "default_true")]
    pub search_sources: bool,
    #[serde(default = "default_true")]
    pub search_notes: bool,
}

fn default_search_type() -> String { "text".to_string() }
fn default_limit() -> i64 { 100 }
fn default_true() -> bool { true }

#[derive(Debug, Serialize, Deserialize)]
pub struct SearchResponse {
    pub results: Vec<serde_json::Value>,
    pub total_count: i64,
    pub search_type: String,
}

// ============================================
// SETTINGS
// ============================================
#[derive(Debug, Serialize, Deserialize)]
pub struct AppSettings {
    pub data_folder: Option<String>,
    pub uploads_folder: Option<String>,
    pub podcasts_folder: Option<String>,
}

// ============================================
// PAGINATION
// ============================================
#[derive(Debug, Deserialize)]
pub struct PaginationParams {
    pub limit: Option<i64>,
    pub offset: Option<i64>,
    pub sort_by: Option<String>,
    pub sort_order: Option<String>,
}

// ============================================
// GENERIC RESPONSES
// ============================================
#[derive(Debug, Serialize, Deserialize)]
pub struct SuccessResponse {
    pub success: bool,
    pub message: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct DeleteResponse {
    pub message: String,
    pub deleted_notes: i64,
    pub deleted_sources: i64,
    pub unlinked_sources: i64,
}

// ============================================
// RECENTLY VIEWED
// ============================================
#[derive(Debug, Serialize, Deserialize)]
pub struct RecentlyViewedResponse {
    #[serde(rename = "type")]
    pub item_type: String,
    pub id: String,
    pub title: String,
    pub last_viewed_at: String,
}

// ============================================
// PROVIDERS
// ============================================
#[derive(Debug, Serialize, Deserialize)]
pub struct ProviderInfo {
    pub name: String,
    pub display_name: String,
    pub requires_api_key: bool,
    pub requires_base_url: bool,
    pub modalities: Vec<String>,
    pub docs_url: Option<String>,
    pub env_configured: bool,
}

// ============================================
// PODCASTS
// ============================================
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpeakerVoiceConfig {
    pub name: String,
    pub voice_id: String,
    pub backstory: String,
    pub personality: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub voice_model: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpeakerProfile {
    pub id: String,
    pub name: String,
    pub description: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub voice_model: Option<String>,
    pub speakers: Vec<SpeakerVoiceConfig>,
    pub created: String,
    pub updated: String,
}

#[derive(Debug, Deserialize)]
pub struct SpeakerProfileInput {
    pub name: String,
    pub description: Option<String>,
    pub voice_model: Option<String>,
    #[serde(default)]
    pub speakers: Vec<SpeakerVoiceConfig>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EpisodeProfile {
    pub id: String,
    pub name: String,
    pub description: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub speaker_config: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub speaker_config_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub outline_llm: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub transcript_llm: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub language: Option<String>,
    pub default_briefing: String,
    pub num_segments: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub max_tokens: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub struct EpisodeProfileInput {
    pub name: String,
    pub description: Option<String>,
    pub speaker_config: Option<String>,
    pub outline_llm: Option<String>,
    pub transcript_llm: Option<String>,
    pub language: Option<String>,
    pub default_briefing: Option<String>,
    pub num_segments: Option<i64>,
    pub max_tokens: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PodcastEpisode {
    pub id: String,
    pub name: String,
    pub episode_profile: Option<serde_json::Value>,
    pub speaker_profile: Option<serde_json::Value>,
    pub briefing: Option<String>,
    pub audio_file: Option<String>,
    pub audio_url: Option<String>,
    pub transcript: Option<serde_json::Value>,
    pub outline: Option<serde_json::Value>,
    pub created: Option<String>,
    pub job_status: Option<String>,
    pub error_message: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Language {
    pub code: String,
    pub name: String,
}

#[derive(Debug, Deserialize)]
pub struct PodcastGenerationRequest {
    pub episode_profile: String,
    pub speaker_profile: String,
    pub episode_name: String,
    pub content: Option<String>,
    pub notebook_id: Option<String>,
    pub briefing_suffix: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PodcastGenerationResponse {
    pub job_id: String,
    pub status: String,
    pub message: String,
    pub episode_profile: String,
    pub episode_name: String,
}

// ============================================
// SYSTEM INFO
// ============================================
#[derive(Debug, Serialize, Deserialize)]
pub struct SystemInfo {
    pub version: String,
    pub python_available: bool,
    pub python_path: Option<String>,
    pub data_dir: String,
    pub os: String,
}
