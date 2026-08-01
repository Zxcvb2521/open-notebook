-- Open Notebook - Initial Schema (SQLite)
-- Ported from SurrealDB schema

-- ============================================
-- NOTEBOOKS
-- ============================================
CREATE TABLE IF NOT EXISTS notebooks (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    archived INTEGER NOT NULL DEFAULT 0,
    last_viewed_at TEXT,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notebooks_archived ON notebooks(archived);
CREATE INDEX IF NOT EXISTS idx_notebooks_updated ON notebooks(updated DESC);

-- ============================================
-- SOURCES
-- ============================================
CREATE TABLE IF NOT EXISTS sources (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL DEFAULT 'Processing...',
    full_text TEXT,
    topics TEXT, -- JSON array
    asset_file_path TEXT,
    asset_url TEXT,
    last_viewed_at TEXT,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sources_updated ON sources(updated DESC);
CREATE INDEX IF NOT EXISTS idx_sources_title ON sources(title);

-- ============================================
-- SOURCE <-> NOTEBOOK (many-to-many)
-- ============================================
CREATE TABLE IF NOT EXISTS source_notebooks (
    source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    notebook_id TEXT NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (source_id, notebook_id)
);

CREATE INDEX IF NOT EXISTS idx_sn_source ON source_notebooks(source_id);
CREATE INDEX IF NOT EXISTS idx_sn_notebook ON source_notebooks(notebook_id);

-- ============================================
-- NOTES (Artifacts)
-- ============================================
CREATE TABLE IF NOT EXISTS notes (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    content TEXT NOT NULL DEFAULT '',
    embedding TEXT, -- JSON vector
    notebook_id TEXT NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_notes_notebook ON notes(notebook_id);
CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated DESC);

-- ============================================
-- SOURCE INSIGHTS
-- ============================================
CREATE TABLE IF NOT EXISTS source_insights (
    id TEXT PRIMARY KEY NOT NULL,
    source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    insight_type TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_si_source ON source_insights(source_id);

-- ============================================
-- MODELS (AI providers)
-- ============================================
CREATE TABLE IF NOT EXISTS models (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    provider TEXT NOT NULL,
    type TEXT NOT NULL, -- language, embedding, speech_to_text, text_to_speech
    credential_id TEXT REFERENCES credentials(id) ON DELETE SET NULL,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_models_type ON models(type);
CREATE INDEX IF NOT EXISTS idx_models_provider ON models(provider);

-- ============================================
-- CREDENTIALS (encrypted API keys)
-- ============================================
CREATE TABLE IF NOT EXISTS credentials (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    provider TEXT NOT NULL,
    encrypted_data TEXT NOT NULL, -- AES-256-GCM encrypted JSON
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================
-- DEFAULT MODELS (singleton)
-- ============================================
CREATE TABLE IF NOT EXISTS default_models (
    id TEXT PRIMARY KEY NOT NULL DEFAULT 'singleton',
    default_chat_model TEXT,
    default_transformation_model TEXT,
    large_context_model TEXT,
    default_text_to_speech_model TEXT,
    default_speech_to_text_model TEXT,
    default_embedding_model TEXT,
    default_tools_model TEXT,
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO default_models (id) VALUES ('singleton');

-- ============================================
-- TRANSFORMATIONS
-- ============================================
CREATE TABLE IF NOT EXISTS transformations (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    prompt_template TEXT NOT NULL DEFAULT '',
    model_id TEXT REFERENCES models(id) ON DELETE SET NULL,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================
-- CHAT SESSIONS
-- ============================================
CREATE TABLE IF NOT EXISTS chat_sessions (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL DEFAULT 'Untitled Session',
    notebook_id TEXT REFERENCES notebooks(id) ON DELETE CASCADE,
    model_override TEXT,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_cs_notebook ON chat_sessions(notebook_id);

-- ============================================
-- CHAT MESSAGES
-- ============================================
CREATE TABLE IF NOT EXISTS chat_messages (
    id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
    role TEXT NOT NULL, -- user, assistant, system
    content TEXT NOT NULL,
    created TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_cm_session ON chat_messages(session_id);

-- ============================================
-- SETTINGS (key-value)
-- ============================================
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================
-- ENCRYPTION KEYS
-- ============================================
CREATE TABLE IF NOT EXISTS encryption_keys (
    id TEXT PRIMARY KEY NOT NULL DEFAULT 'master',
    key_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    created TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================
-- SOURCE COMMANDS (processing status)
-- ============================================
CREATE TABLE IF NOT EXISTS source_commands (
    id TEXT PRIMARY KEY NOT NULL,
    source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'new', -- new, queued, running, completed, failed
    command_type TEXT NOT NULL,
    result TEXT,
    error_message TEXT,
    started_at TEXT,
    completed_at TEXT,
    created TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_scmd_source ON source_commands(source_id);

-- ============================================
-- CONTENT SETTINGS (singleton)
-- ============================================
CREATE TABLE IF NOT EXISTS content_settings (
    id TEXT PRIMARY KEY NOT NULL DEFAULT 'singleton',
    default_content_processing_engine_url TEXT DEFAULT 'auto',
    default_content_processing_engine_doc TEXT DEFAULT 'auto',
    docling_ocr TEXT DEFAULT 'auto',
    docling_formulas TEXT DEFAULT 'auto',
    docling_vision TEXT DEFAULT 'auto',
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO content_settings (id) VALUES ('singleton');

-- ============================================
-- EMBEDDING CHUNKS (vector search)
-- ============================================
CREATE TABLE IF NOT EXISTS source_embeddings (
    id TEXT PRIMARY KEY NOT NULL,
    source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    embedding TEXT, -- JSON array of floats
    created TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_se_source ON source_embeddings(source_id);

-- ============================================
-- PODCAST EPISODES
-- ============================================
CREATE TABLE IF NOT EXISTS podcast_episodes (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    notebook_id TEXT REFERENCES notebooks(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'new',
    audio_path TEXT,
    transcript TEXT,
    outline TEXT,
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_pe_notebook ON podcast_episodes(notebook_id);

-- ============================================
-- SPEAKER PROFILES
-- ============================================
CREATE TABLE IF NOT EXISTS speaker_profiles (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    voice_model TEXT,
    voice_settings TEXT, -- JSON
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================
-- EPISODE PROFILES
-- ============================================
CREATE TABLE IF NOT EXISTS episode_profiles (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    template TEXT NOT NULL DEFAULT '',
    created TEXT NOT NULL DEFAULT (datetime('now')),
    updated TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================
-- TEXT SEARCH (FTS5)
-- ============================================
CREATE VIRTUAL TABLE IF NOT EXISTS sources_fts USING fts5(
    title, full_text, content='sources', content_rowid='rowid'
);

-- Triggers to keep FTS in sync
CREATE TRIGGER IF NOT EXISTS sources_ai AFTER INSERT ON sources BEGIN
    INSERT INTO sources_fts(rowid, title, full_text) VALUES (new.rowid, new.title, new.full_text);
END;

CREATE TRIGGER IF NOT EXISTS sources_ad AFTER DELETE ON sources BEGIN
    INSERT INTO sources_fts(sources_fts, rowid, title, full_text) VALUES ('delete', old.rowid, old.title, old.full_text);
END;

CREATE TRIGGER IF NOT EXISTS sources_au AFTER UPDATE ON sources BEGIN
    INSERT INTO sources_fts(sources_fts, rowid, title, full_text) VALUES ('delete', old.rowid, old.title, old.full_text);
    INSERT INTO sources_fts(rowid, title, full_text) VALUES (new.rowid, new.title, new.full_text);
END;

CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
    title, content, content='notes', content_rowid='rowid'
);

CREATE TRIGGER IF NOT EXISTS notes_ai AFTER INSERT ON notes BEGIN
    INSERT INTO notes_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
END;

CREATE TRIGGER IF NOT EXISTS notes_ad AFTER DELETE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, title, content) VALUES ('delete', old.rowid, old.title, old.content);
END;

CREATE TRIGGER IF NOT EXISTS notes_au AFTER UPDATE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, title, content) VALUES ('delete', old.rowid, old.title, old.content);
    INSERT INTO notes_fts(rowid, title, content) VALUES (new.rowid, new.title, new.content);
END;
