/**
 * API client — Tauri edition.
 *
 * The original frontend used axios against an HTTP API at /api/*. Our Rust
 * backend exposes the same resources as Tauri commands. This module keeps the
 * axios-shaped interface (apiClient.get/post/put/patch/delete → { data }) and
 * routes requests to Tauri commands via window.__TAURI__.core.invoke.
 *
 * When running in a plain browser (vite dev, no Tauri runtime) it falls back
 * to deterministic mock data so the full UI can be previewed.
 */

// Timeout budget for AI operations (ms). Aligned with the original frontend:
// 600 seconds = 10 minutes (models like Ollama can be slow).
export const API_TIMEOUT_MS = 600000

type HttpMethod = 'get' | 'post' | 'put' | 'patch' | 'delete'

interface AxiosLikeConfig {
  params?: Record<string, unknown>
  [key: string]: unknown
}

interface AxiosLikeResponse<T = unknown> {
  data: T
  status: number
  statusText: string
}

function snakeToCamel(s: string): string {
  return s.replace(/_([a-z])/g, (_, c) => c.toUpperCase())
}

function toCamelArgs(obj: Record<string, unknown> | undefined): Record<string, unknown> {
  if (!obj) return {}
  const out: Record<string, unknown> = {}
  for (const [k, v] of Object.entries(obj)) {
    out[snakeToCamel(k)] = v
  }
  return out
}

type TauriWindow = Window & {
  __TAURI__?: {
    core?: {
      invoke: (cmd: string, args?: Record<string, unknown>) => Promise<unknown>
    }
  }
}

declare global {
  interface Window {
    __TAURI__?: {
      core?: {
        invoke: (cmd: string, args?: Record<string, unknown>) => Promise<unknown>
      }
    }
  }
}

const isTauri = (): boolean => typeof window !== 'undefined' && !!window.__TAURI__?.core?.invoke

let mockModeLogged = false
function logMock(cmd: string): void {
  if (!mockModeLogged) {
    console.warn('[api] Running in MOCK mode (no Tauri runtime).', cmd)
    mockModeLogged = true
  }
}

/**
 * Resolve (method, path, params, body) → Tauri command + args.
 * Returns null when no mapping exists (caller falls back to mock).
 */
function resolveRoute(
  method: HttpMethod,
  path: string,
  params?: Record<string, unknown>,
  body?: unknown
): { cmd: string; args: Record<string, unknown> } | null {
  const p = toCamelArgs(params)
  const segments = path.split('/').filter(Boolean) // e.g. ['notebooks', 'abc', 'notes']

  // ---- Auth ----
  if (path === '/auth/check' && method === 'get') return { cmd: 'check_auth', args: {} }
  if (path === '/auth/login' && method === 'post') return { cmd: 'login', args: { password: (body as any)?.password } }

  // ---- Notebooks ----
  if (path === '/notebooks' && method === 'get') {
    return { cmd: 'list_notebooks', args: { includeArchived: p.includeArchived ?? false } }
  }
  if (path === '/notebooks' && method === 'post') {
    return { cmd: 'create_notebook', args: { request: body } }
  }
  if (segments.length === 2 && segments[0] === 'notebooks' && method === 'put') {
    return { cmd: 'update_notebook', args: { id: segments[1], updates: body } }
  }
  if (segments.length === 2 && segments[0] === 'notebooks' && method === 'delete') {
    return { cmd: 'delete_notebook', args: { id: segments[1] } }
  }
  if (path === '/notebooks/recently-viewed' && method === 'get') {
    return { cmd: 'get_recently_viewed', args: { limit: p.limit ?? 10 } }
  }
  if (path === '/recently-viewed' && method === 'get') {
    return { cmd: 'get_recently_viewed', args: { limit: p.limit ?? 12 } }
  }
  if (segments.length === 3 && segments[0] === 'notebooks' && segments[2] === 'delete-preview' && method === 'get') {
    return { cmd: 'get_notebook_delete_preview', args: { id: segments[1] } }
  }
  if (segments.length === 2 && segments[0] === 'notebooks' && method === 'get') {
    return { cmd: 'get_notebook', args: { id: segments[1] } }
  }
  if (segments.length === 4 && segments[0] === 'notebooks' && segments[2] === 'sources' && method === 'post') {
    return { cmd: 'add_source_to_notebook', args: { sourceId: segments[3], notebookId: segments[1] } }
  }
  if (segments.length === 4 && segments[0] === 'notebooks' && segments[2] === 'sources' && method === 'delete') {
    return { cmd: 'remove_source_from_notebook', args: { sourceId: segments[3], notebookId: segments[1] } }
  }

  // ---- Sources ----
  // Source IDs may carry a "source:" prefix (added by SourceDialog for routing).
  // The backend stores raw UUIDs, so strip the prefix before calling commands.
  const stripSourcePrefix = (id: string): string => (id.startsWith('source:') ? id.slice('source:'.length) : id)

  if (path === '/sources' && method === 'get') {
    return {
      cmd: 'get_sources',
      args: { notebookId: p.notebookId ?? null, limit: p.limit ?? 50, offset: p.offset ?? 0, sortBy: p.sortBy ?? null, sortOrder: p.sortOrder ?? null },
    }
  }
  if (path === '/sources' && method === 'post') {
    return { cmd: 'create_source', args: { data: body } }
  }
  if (segments.length === 2 && segments[0] === 'sources' && method === 'get') {
    return { cmd: 'get_source', args: { sourceId: stripSourcePrefix(segments[1]) } }
  }
  if (segments.length === 2 && segments[0] === 'sources' && method === 'put') {
    return { cmd: 'update_source', args: { sourceId: stripSourcePrefix(segments[1]), title: (body as any)?.title ?? null, topics: (body as any)?.topics ?? null } }
  }
  if (segments.length === 2 && segments[0] === 'sources' && method === 'delete') {
    return { cmd: 'delete_source', args: { sourceId: stripSourcePrefix(segments[1]) } }
  }
  if (segments.length === 3 && segments[0] === 'sources' && segments[2] === 'insights' && method === 'get') {
    return { cmd: 'get_source_insights', args: { sourceId: stripSourcePrefix(segments[1]) } }
  }
  if (segments.length === 3 && segments[0] === 'sources' && segments[2] === 'process' && method === 'post') {
    return { cmd: 'process_source_content', args: { sourceId: stripSourcePrefix(segments[1]), embed: (body as any)?.embed ?? null } }
  }
  if (segments.length === 4 && segments[0] === 'sources' && segments[2] === 'notebooks' && method === 'post') {
    return { cmd: 'add_source_to_notebook', args: { sourceId: stripSourcePrefix(segments[1]), notebookId: segments[3] } }
  }
  if (segments.length === 4 && segments[0] === 'sources' && segments[2] === 'notebooks' && method === 'delete') {
    return { cmd: 'remove_source_from_notebook', args: { sourceId: stripSourcePrefix(segments[1]), notebookId: segments[3] } }
  }

  // ---- Notes ----
  if (segments.length === 3 && segments[0] === 'notebooks' && segments[2] === 'notes' && method === 'get') {
    return { cmd: 'get_notes', args: { notebookId: segments[1], includeContent: p.includeContent ?? false } }
  }
  if (path === '/notes' && method === 'post') return { cmd: 'create_note', args: { data: body } }
  if (segments.length === 2 && segments[0] === 'notes' && method === 'get') {
    return { cmd: 'get_note', args: { noteId: segments[1] } }
  }
  if (segments.length === 2 && segments[0] === 'notes' && method === 'put') {
    return { cmd: 'update_note', args: { noteId: segments[1], title: (body as any)?.title ?? null, content: (body as any)?.content ?? null } }
  }
  if (segments.length === 2 && segments[0] === 'notes' && method === 'delete') {
    return { cmd: 'delete_note', args: { noteId: segments[1] } }
  }

  // ---- Transformations ----
  if (path === '/transformations' && method === 'get') return { cmd: 'get_transformations', args: {} }
  if (path === '/transformations' && method === 'post') return { cmd: 'create_transformation', args: { data: body } }
  if (path === '/transformations/default-prompt' && method === 'get') return { cmd: 'get_default_prompt', args: {} }
  if (path === '/transformations/default-prompt' && method === 'put') return { cmd: 'update_default_prompt', args: { prompt: body } }
  if (path === '/transformations/execute' && method === 'post') {
    return { cmd: 'apply_transformation', args: { transformationId: (body as any)?.transformationId ?? null, inputText: (body as any)?.inputText ?? null } }
  }
  if (segments.length === 2 && segments[0] === 'transformations' && method === 'get') {
    return { cmd: 'get_transformation', args: { id: segments[1] } }
  }
  if (segments.length === 2 && segments[0] === 'transformations' && method === 'put') {
    return { cmd: 'update_transformation', args: { id: segments[1], data: body } }
  }
  if (segments.length === 2 && segments[0] === 'transformations' && method === 'delete') {
    return { cmd: 'delete_transformation', args: { id: segments[1] } }
  }
  if (path === '/transformations/apply' && method === 'post') {
    return { cmd: 'apply_transformation', args: { transformationId: (body as any)?.transformationId ?? null, inputText: (body as any)?.inputText ?? null } }
  }

  // ---- Credentials ----
  if (path === '/credentials' && method === 'get') return { cmd: 'get_credentials', args: {} }
  if (path === '/credentials' && method === 'post') return { cmd: 'create_credential', args: { data: body } }
  if (segments.length === 3 && segments[0] === 'credentials' && segments[2] === 'data' && method === 'get') {
    return { cmd: 'get_credential_data', args: { credentialId: segments[1] } }
  }
  if (segments.length === 2 && segments[0] === 'credentials' && method === 'delete') {
    return { cmd: 'delete_credential', args: { id: segments[1] } }
  }

  // ---- Settings ----
  if (path === '/settings' && method === 'get') return { cmd: 'get_settings', args: {} }
  if (path === '/settings' && method === 'put') return { cmd: 'update_settings', args: { settings: body } }

  // ---- Models ----
  if (path === '/models' && method === 'get') return { cmd: 'get_models', args: { modelType: p.modelType ?? null } }
  if (path === '/models' && method === 'post') return { cmd: 'create_model', args: { data: body } }
  if (segments.length === 2 && segments[0] === 'models' && method === 'delete') {
    return { cmd: 'delete_model', args: { id: segments[1] } }
  }
  if (path === '/models/defaults' && method === 'get') return { cmd: 'get_default_models', args: {} }
  if (path === '/models/defaults' && method === 'put') return { cmd: 'update_default_models', args: { defaults: body } }

  // ---- Providers ----
  if (path === '/providers' && method === 'get') return { cmd: 'get_providers', args: {} }

  // ---- Chat ----
  if (path === '/chat/sessions' && method === 'get') {
    return { cmd: 'get_chat_sessions', args: { notebookId: p.notebookId ?? null } }
  }
  if (path === '/chat/sessions' && method === 'post') return { cmd: 'create_chat_session', args: { data: body } }
  if (segments.length === 4 && segments[0] === 'chat' && segments[2] === 'sessions' && method === 'delete') {
    return { cmd: 'delete_chat_session', args: { sessionId: segments[3] } }
  }
  if (segments.length === 4 && segments[0] === 'chat' && segments[2] === 'sessions' && method === 'put') {
    return { cmd: 'update_chat_session', args: { sessionId: segments[3], title: (body as any)?.title ?? null, modelOverride: (body as any)?.modelOverride ?? null } }
  }
  if (segments.length === 5 && segments[0] === 'chat' && segments[2] === 'sessions' && segments[4] === 'messages' && method === 'get') {
    return { cmd: 'get_chat_messages', args: { sessionId: segments[3] } }
  }
  if (path === '/chat/execute' && method === 'post') return { cmd: 'execute_chat', args: { request: body } }

  // ---- Podcasts ----
  if (path === '/podcasts/episodes' && method === 'get') return { cmd: 'get_episodes', args: {} }
  if (segments.length === 3 && segments[0] === 'podcasts' && segments[1] === 'episodes' && method === 'delete') {
    return { cmd: 'delete_episode', args: { episodeId: segments[2] } }
  }
  if (segments.length === 4 && segments[0] === 'podcasts' && segments[1] === 'episodes' && segments[3] === 'retry' && method === 'post') {
    return { cmd: 'retry_episode', args: { episodeId: segments[2] } }
  }
  if (path === '/podcasts/generate' && method === 'post') return { cmd: 'generate_podcast', args: { data: body } }
  if (path === '/languages' && method === 'get') return { cmd: 'get_languages', args: {} }

  // ---- Episode profiles ----
  if (path === '/episode-profiles' && method === 'get') return { cmd: 'get_episode_profiles', args: {} }
  if (path === '/episode-profiles' && method === 'post') return { cmd: 'create_episode_profile', args: { data: body } }
  if (segments.length === 3 && segments[0] === 'episode-profiles' && segments[2] === 'duplicate' && method === 'post') {
    return { cmd: 'duplicate_episode_profile', args: { profileId: segments[1] } }
  }
  if (segments.length === 2 && segments[0] === 'episode-profiles' && method === 'put') {
    return { cmd: 'update_episode_profile', args: { profileId: segments[1], data: body } }
  }
  if (segments.length === 2 && segments[0] === 'episode-profiles' && method === 'delete') {
    return { cmd: 'delete_episode_profile', args: { profileId: segments[1] } }
  }

  // ---- Speaker profiles ----
  if (path === '/speaker-profiles' && method === 'get') return { cmd: 'get_speaker_profiles', args: {} }
  if (path === '/speaker-profiles' && method === 'post') return { cmd: 'create_speaker_profile', args: { data: body } }
  if (segments.length === 3 && segments[0] === 'speaker-profiles' && segments[2] === 'duplicate' && method === 'post') {
    return { cmd: 'duplicate_speaker_profile', args: { profileId: segments[1] } }
  }
  if (segments.length === 2 && segments[0] === 'speaker-profiles' && method === 'put') {
    return { cmd: 'update_speaker_profile', args: { profileId: segments[1], data: body } }
  }
  if (segments.length === 2 && segments[0] === 'speaker-profiles' && method === 'delete') {
    return { cmd: 'delete_speaker_profile', args: { profileId: segments[1] } }
  }

  // ---- Search ----
  if (path === '/search' && method === 'post') return { cmd: 'search', args: { request: body } }
  if (path === '/search/semantic' && method === 'post') return { cmd: 'semantic_search', args: { request: body } }

  // ---- AI / Embedding ----
  if (path === '/ai/health' && method === 'get') return { cmd: 'check_ai_health', args: {} }
  if (path === '/embedding/rebuild' && method === 'post') {
    return { cmd: 'rebuild_embeddings', args: { sourceId: (body as any)?.sourceId ?? null } }
  }

  return null
}

async function invoke<T>(cmd: string, args: Record<string, unknown>): Promise<T> {
  return window.__TAURI__!.core!.invoke(cmd, args) as Promise<T>
}

/**
 * Mock data for previewing the UI in a plain browser (no Tauri runtime).
 *
 * Uses an in-memory store so mutations (create/update) actually change what
 * subsequent reads return — matching the real backend's behaviour closely
 * enough for a full UI walkthrough.
 */
const mockStore = {
  notebooks: [
    { id: 'nb-1', name: 'Research Notes', description: 'Daily research and reading notes', archived: false, created: nowIso(), updated: nowIso(), source_count: 5, note_count: 12 },
    { id: 'nb-2', name: 'Ideas & Drafts', description: 'Brainstorming and writing drafts', archived: false, created: nowIso(), updated: nowIso(), source_count: 2, note_count: 7 },
    { id: 'nb-3', name: 'Projects', description: 'Active project documentation', archived: false, created: nowIso(), updated: nowIso(), source_count: 8, note_count: 21 },
  ],
  transformations: [
    { id: 't-1', name: 'Summarize', description: 'Summarize the source into key points', prompt_template: 'Summarize the following text:\n\n{{text}}', model_id: 'm-1', created: nowIso(), updated: nowIso() },
    { id: 't-2', name: 'Extract Insights', description: 'Extract actionable insights', prompt_template: 'Extract 3 insights from this text:\n\n{{text}}', model_id: 'm-1', created: nowIso(), updated: nowIso() },
  ],
  sources: [
    { id: 'src-1', title: 'The Bitter Lesson — Rich Sutton', source_type: 'link', url: 'http://incompleteideas.net/IncIdeas/BitterLesson.html', embedded: true, embedded_chunks: 4, insights_count: 3, created: nowIso(), updated: nowIso(), asset: { url: 'http://incompleteideas.net/IncIdeas/BitterLesson.html' } },
    { id: 'src-2', title: 'Attention Is All You Need', source_type: 'link', url: 'https://arxiv.org/abs/1706.03762', embedded: true, embedded_chunks: 9, insights_count: 5, created: nowIso(), updated: nowIso(), asset: { url: 'https://arxiv.org/abs/1706.03762' } },
    { id: 'src-3', title: 'Local LLM Notes', source_type: 'text', content: 'Ollama works well with 16GB VRAM.', embedded: false, embedded_chunks: 0, insights_count: 0, created: nowIso(), updated: nowIso(), asset: null },
  ],
  defaultPrompt: 'Follow the transformation instructions below:\n\n{{text}}',
}

function nowIso(): string {
  return new Date().toISOString()
}

function mockData<T>(method: HttpMethod, path: string, body?: unknown): T {
  logMock(path)
  const segments = path.split('/').filter(Boolean)
  const now = new Date().toISOString()

  // Notebooks
  if (path === '/notebooks' && method === 'get') {
    return mockStore.notebooks.filter(n => !n.archived) as unknown as T
  }
  if (path === '/notebooks' && method === 'post') {
    const b = (body ?? {}) as Record<string, unknown>
    const nb = {
      id: `nb-${Date.now()}`,
      name: (b.name as string) || 'New Notebook',
      description: (b.description as string) || '',
      archived: false,
      created: nowIso(),
      updated: nowIso(),
      source_count: 0,
      note_count: 0,
    }
    mockStore.notebooks.unshift(nb)
    return nb as unknown as T
  }
  if (segments[0] === 'notebooks' && segments.length === 2 && method === 'get') {
    const found = mockStore.notebooks.find(n => n.id === segments[1])
    return (found ?? null) as unknown as T
  }
  if (segments[0] === 'notebooks' && segments.length === 3 && segments[2] === 'delete-preview' && method === 'get') {
    const found = mockStore.notebooks.find(n => n.id === segments[1])
    return {
      notebook_id: segments[1],
      notebook_name: found?.name ?? 'Notebook',
      note_count: found?.note_count ?? 0,
      exclusive_source_count: found?.source_count ?? 0,
      shared_source_count: 0,
    } as unknown as T
  }
  if (segments[0] === 'notebooks' && segments.length === 2 && method === 'put') {
    const idx = mockStore.notebooks.findIndex(n => n.id === segments[1])
    const b = (body ?? {}) as Record<string, unknown>
    if (idx >= 0) {
      mockStore.notebooks[idx] = {
        ...mockStore.notebooks[idx],
        name: (b.name as string) ?? mockStore.notebooks[idx].name,
        description: (b.description as string) ?? mockStore.notebooks[idx].description,
        archived: (b.archived as boolean) ?? mockStore.notebooks[idx].archived,
        updated: nowIso(),
      }
      return mockStore.notebooks[idx] as unknown as T
    }
    return null as unknown as T
  }
  if (segments[0] === 'notebooks' && segments.length === 2 && method === 'delete') {
    mockStore.notebooks = mockStore.notebooks.filter(n => n.id !== segments[1])
    return { success: true, message: 'Notebook deleted' } as unknown as T
  }
  if (segments[0] === 'notebooks' && segments.length === 4 && segments[2] === 'sources' && method === 'post') {
    return { success: true, message: 'Source added to notebook' } as unknown as T
  }
  if (segments[0] === 'notebooks' && segments.length === 4 && segments[2] === 'sources' && method === 'delete') {
    return { success: true, message: 'Source removed from notebook' } as unknown as T
  }
  if (path === '/recently-viewed' && method === 'get') {
    return mockStore.notebooks.slice(0, 5).map(n => ({
      type: 'notebook',
      id: n.id,
      title: n.name,
      last_viewed_at: n.updated,
    })) as unknown as T
  }

  // Sources
  if (path === '/sources' && method === 'get') {
    return mockStore.sources as unknown as T
  }
  if (segments.length === 2 && segments[0] === 'sources' && method === 'get') {
    const rawId = segments[1]
    const normalizedId = rawId.startsWith('source:') ? rawId.slice('source:'.length) : rawId
    const found = mockStore.sources.find(s => s.id === normalizedId)
    return (found ?? null) as unknown as T
  }
  if (path === '/sources' && method === 'post') {
    return { id: `src-${Date.now()}`, title: 'New Source', source_type: 'text', content: '', embedded: false, embedded_chunks: 0, insights_count: 0, created: now, updated: now, asset: null } as unknown as T
  }

  // Settings
  if (path === '/settings' && method === 'get') {
    return {
      default_content_processing_engine_doc: 'markitdown',
      default_content_processing_engine_url: 'trafilatura',
      default_embedding_option: 'local',
      auto_delete_files: 'false',
      docling_ocr: false,
    } as unknown as T
  }

  // Models
  if (path === '/models' && method === 'get') {
    return [
      { id: 'm-1', name: 'gemma4:e2b', provider: 'ollama', model_type: 'chat', credential_id: null, created: now, updated: now },
      { id: 'm-2', name: 'nomic-embed-text', provider: 'ollama', model_type: 'embedding', credential_id: null, created: now, updated: now },
      { id: 'm-3', name: 'mistral-large-latest', provider: 'mistral', model_type: 'chat', credential_id: 'cred-1', created: now, updated: now },
    ] as unknown as T
  }
  if (path === '/models/defaults' && method === 'get') {
    return { default_chat_model: 'm-1', default_transformation_model: 'm-1', large_context_model: 'm-1', default_embedding_model: 'm-2' } as unknown as T
  }

  // Providers
  if (path === '/providers' && method === 'get') {
    return [
      { name: 'openai', display_name: 'OpenAI', modalities: ['language', 'embedding', 'text_to_speech', 'speech_to_text'], docs_url: 'https://platform.openai.com/docs', env_configured: false },
      { name: 'anthropic', display_name: 'Anthropic', modalities: ['language'], docs_url: 'https://docs.anthropic.com', env_configured: false },
      { name: 'google', display_name: 'Google AI', modalities: ['language', 'embedding', 'text_to_speech', 'speech_to_text'], docs_url: 'https://ai.google.dev', env_configured: false },
      { name: 'groq', display_name: 'Groq', modalities: ['language', 'speech_to_text'], docs_url: 'https://console.groq.com/docs', env_configured: false },
      { name: 'mistral', display_name: 'Mistral AI', modalities: ['language', 'embedding', 'speech_to_text', 'text_to_speech'], docs_url: 'https://docs.mistral.ai', env_configured: false },
      { name: 'deepseek', display_name: 'DeepSeek', modalities: ['language'], docs_url: 'https://platform.deepseek.com/docs', env_configured: false },
      { name: 'xai', display_name: 'xAI (Grok)', modalities: ['language', 'text_to_speech'], docs_url: 'https://docs.x.ai', env_configured: false },
      { name: 'openrouter', display_name: 'OpenRouter', modalities: ['language', 'embedding', 'text_to_speech', 'speech_to_text'], docs_url: 'https://openrouter.ai/docs', env_configured: false },
      { name: 'dashscope', display_name: 'DashScope (Qwen)', modalities: ['language'], docs_url: 'https://help.aliyun.com/zh/model-studio', env_configured: false },
      { name: 'minimax', display_name: 'MiniMax', modalities: ['language'], docs_url: 'https://platform.minimaxi.com/document', env_configured: false },
      { name: 'novita', display_name: 'Novita', modalities: ['language'], docs_url: 'https://novita.ai/docs', env_configured: false },
      { name: 'ppq', display_name: 'PayPerQ', modalities: ['language', 'embedding', 'text_to_speech', 'speech_to_text'], docs_url: 'https://ppq.ai', env_configured: false },
      { name: 'cohere', display_name: 'Cohere', modalities: ['language', 'embedding'], docs_url: 'https://docs.cohere.com', env_configured: false },
      { name: 'voyage', display_name: 'Voyage AI', modalities: ['embedding'], docs_url: 'https://docs.voyageai.com', env_configured: false },
      { name: 'elevenlabs', display_name: 'ElevenLabs', modalities: ['text_to_speech', 'speech_to_text'], docs_url: 'https://elevenlabs.io/docs', env_configured: false },
      { name: 'deepgram', display_name: 'Deepgram', modalities: ['text_to_speech', 'speech_to_text'], docs_url: 'https://developers.deepgram.com/docs', env_configured: false },
      { name: 'ollama', display_name: 'Ollama', modalities: ['language', 'embedding'], docs_url: 'https://ollama.com', env_configured: true },
      { name: 'omlx', display_name: 'oMLX', modalities: ['language', 'embedding'], docs_url: 'https://github.com/omlx/omlx', env_configured: true },
      { name: 'azure', display_name: 'Azure OpenAI', modalities: ['language', 'embedding', 'text_to_speech', 'speech_to_text'], docs_url: 'https://learn.microsoft.com/azure/ai-services/openai', env_configured: false },
      { name: 'vertex', display_name: 'Google Vertex AI', modalities: ['language', 'embedding', 'text_to_speech'], docs_url: 'https://cloud.google.com/vertex-ai/docs', env_configured: false },
      { name: 'openai_compatible', display_name: 'OpenAI Compatible', modalities: ['language', 'embedding', 'text_to_speech', 'speech_to_text'], docs_url: null, env_configured: false },
      { name: 'anthropic_compatible', display_name: 'Anthropic Compatible', modalities: ['language'], docs_url: null, env_configured: false },
    ] as unknown as T
  }

  // Credentials
  if (path === '/credentials' && method === 'get') {
    return [] as unknown as T
  }

  // Transformations
  if (path === '/transformations' && method === 'get') {
    return mockStore.transformations as unknown as T
  }
  if (path === '/transformations' && method === 'post') {
    const b = (body ?? {}) as Record<string, unknown>
    const tr = {
      id: `t-${Date.now()}`,
      name: (b.name as string) || 'New Transformation',
      description: (b.description as string) || '',
      prompt_template: (b.prompt_template as string) || '',
      model_id: (b.model_id as string) ?? null,
      created: nowIso(),
      updated: nowIso(),
    }
    mockStore.transformations.unshift(tr)
    return tr as unknown as T
  }
  if (path === '/transformations/default-prompt' && method === 'get') {
    return { transformation_instructions: mockStore.defaultPrompt } as unknown as T
  }
  if (path === '/transformations/default-prompt' && method === 'put') {
    const b = (body ?? {}) as Record<string, unknown>
    mockStore.defaultPrompt = (b.transformation_instructions as string) ?? mockStore.defaultPrompt
    return { success: true, message: 'Default prompt updated' } as unknown as T
  }
  if (path === '/transformations/execute' && method === 'post') {
    return { output: 'Transformation executed (mock output).', model: 'mock-model' } as unknown as T
  }
  if (segments[0] === 'transformations' && segments.length === 2 && method === 'get') {
    const found = mockStore.transformations.find(t => t.id === segments[1])
    return (found ?? null) as unknown as T
  }
  if (segments[0] === 'transformations' && segments.length === 2 && method === 'put') {
    const idx = mockStore.transformations.findIndex(t => t.id === segments[1])
    const b = (body ?? {}) as Record<string, unknown>
    if (idx >= 0) {
      mockStore.transformations[idx] = {
        ...mockStore.transformations[idx],
        name: (b.name as string) ?? mockStore.transformations[idx].name,
        description: (b.description as string) ?? mockStore.transformations[idx].description,
        prompt_template: (b.prompt_template as string) ?? mockStore.transformations[idx].prompt_template,
        model_id: (b.model_id as string) ?? mockStore.transformations[idx].model_id,
        updated: nowIso(),
      }
      return mockStore.transformations[idx] as unknown as T
    }
    return null as unknown as T
  }
  if (segments[0] === 'transformations' && segments.length === 2 && method === 'delete') {
    mockStore.transformations = mockStore.transformations.filter(t => t.id !== segments[1])
    return { success: true, message: 'Transformation deleted' } as unknown as T
  }

  // Chat sessions
  if (path === '/chat/sessions' && method === 'get') {
    return [] as unknown as T
  }

  // Episodes
  if (path === '/podcasts/episodes' && method === 'get') {
    return [] as unknown as T
  }

  // Podcast speaker profiles (preview seed)
  if (path === '/speaker-profiles' && method === 'get') {
    return [
      {
        id: 'sp-business-panel', name: 'business_panel',
        description: 'Панель бизнес-анализа с различными точками зрения',
        voice_model: 'model-mistral-voxtral-mini-tts-latest-text_to_speech',
        speakers: [
          { name: 'Маркус Томпсон', voice_id: 'echo', backstory: 'Бывший консультант McKinsey, теперь советник по стартапам.', personality: 'Стратегический мыслитель, ориентирующийся на данные.' },
          { name: 'Елена Васкес', voice_id: 'shimmer', backstory: 'Серийный предприниматель и инвестор.', personality: 'Ориентирован на действия, прагматичен.' },
          { name: 'Джонни Бинг', voice_id: 'ash', backstory: 'Ютуб-знаменитость и бизнес-магнат.', personality: 'Спорный, любит подвергать сомнению идеи.' },
        ],
        created: now, updated: now,
      },
      {
        id: 'sp-solo-expert', name: 'solo_expert',
        description: 'Единый эксперт по образовательному контенту',
        voice_model: 'model-mistral-voxtral-mini-tts-latest-text_to_speech',
        speakers: [
          { name: 'Профессор Сара Ким', voice_id: 'nova', backstory: 'Заслуженный профессор и исследователь.', personality: 'Терпеливый преподаватель, использует аналогии.' },
        ],
        created: now, updated: now,
      },
      {
        id: 'sp-tech-experts', name: 'tech_experts',
        description: 'Два технических эксперта для технических дискуссий',
        voice_model: 'model-mistral-voxtral-mini-tts-latest-text_to_speech',
        speakers: [
          { name: 'Доктор Алекс Чен', voice_id: 'nova', backstory: 'Старший исследователь искусственного интеллекта.', personality: 'Аналитический, задает уточняющие вопросы.' },
          { name: 'Джейми Родригес', voice_id: 'alloy', backstory: 'Full-stack инженер и технологический предприниматель.', personality: 'Энтузиаст, практичный.' },
        ],
        created: now, updated: now,
      },
    ] as unknown as T
  }
  if (path === '/episode-profiles' && method === 'get') {
    return [
      {
        id: 'ep-solo-expert', name: 'solo_expert',
        description: 'Один эксперт, объясняющий сложные темы',
        speaker_config: 'sp-solo-expert', speaker_config_name: 'solo_expert',
        outline_llm: 'model-mistral-mistral-large-latest-language',
        transcript_llm: 'model-mistral-mistral-large-latest-language',
        language: 'ru-RU', default_briefing: 'Создайте образовательное объяснение предоставленного контента.',
        num_segments: 4, max_tokens: null, created: now, updated: now,
      },
      {
        id: 'ep-business-analysis', name: 'business_analysis',
        description: 'Business-focused analysis and discussion',
        speaker_config: 'sp-business-panel', speaker_config_name: 'business_panel',
        outline_llm: 'model-mistral-mistral-large-latest-language',
        transcript_llm: 'model-mistral-mistral-large-latest-language',
        language: 'ru-RU', default_briefing: 'Проанализируйте предоставленный контент с точки зрения бизнеса.',
        num_segments: 6, max_tokens: null, created: now, updated: now,
      },
      {
        id: 'ep-tech-discussion', name: 'tech_discussion',
        description: 'Техническая дискуссия между двумя экспертами',
        speaker_config: 'sp-tech-experts', speaker_config_name: 'tech_experts',
        outline_llm: 'model-mistral-mistral-large-latest-language',
        transcript_llm: 'model-mistral-mistral-large-latest-language',
        language: 'ru-RU', default_briefing: 'Создайте увлекательное техническое обсуждение предоставленного контента.',
        num_segments: 5, max_tokens: null, created: now, updated: now,
      },
    ] as unknown as T
  }
  if (path === '/languages' && method === 'get') {
    return [
      { code: 'ru-RU', name: 'Русский' },
      { code: 'en-US', name: 'English (US)' },
      { code: 'de-DE', name: 'Deutsch' },
      { code: 'fr-FR', name: 'Français' },
      { code: 'es-ES', name: 'Español' },
    ] as unknown as T
  }

  // Search — empty result shape
  if (path === '/search' || path === '/search/semantic') {
    return { results: [], query: '' } as unknown as T
  }

  // Health
  if (path === '/ai/health' && method === 'get') {
    return { status: 'ok', engine: 'mock' } as unknown as T
  }

  // Auth
  if (path === '/auth/check' && method === 'get') return { auth_required: false } as unknown as T

  // Notes
  if (segments[0] === 'notebooks' && segments[2] === 'notes' && method === 'get') {
    return [] as unknown as T
  }

  // Generic empty
  if (method === 'get') return [] as unknown as T
  return { success: true } as unknown as T
}

/**
 * The axios-shaped client. All API modules keep working unchanged.
 */
export const apiClient = {
  async get<T = unknown>(url: string, config?: AxiosLikeConfig): Promise<AxiosLikeResponse<T>> {
    const route = resolveRoute('get', url, config?.params)
    if (isTauri() && route) {
      const data = await invoke<T>(route.cmd, route.args)
      return { data, status: 200, statusText: 'OK' }
    }
    return { data: mockData<T>('get', url), status: 200, statusText: 'OK' }
  },

  async post<T = unknown>(url: string, data?: unknown, config?: AxiosLikeConfig): Promise<AxiosLikeResponse<T>> {
    const route = resolveRoute('post', url, config?.params, data)
    if (isTauri() && route) {
      const result = await invoke<T>(route.cmd, route.args)
      return { data: result, status: 200, statusText: 'OK' }
    }
    return { data: mockData<T>('post', url, data), status: 200, statusText: 'OK' }
  },

  async put<T = unknown>(url: string, data?: unknown, config?: AxiosLikeConfig): Promise<AxiosLikeResponse<T>> {
    const route = resolveRoute('put', url, config?.params, data)
    if (isTauri() && route) {
      const result = await invoke<T>(route.cmd, route.args)
      return { data: result, status: 200, statusText: 'OK' }
    }
    return { data: mockData<T>('put', url, data), status: 200, statusText: 'OK' }
  },

  async patch<T = unknown>(url: string, data?: unknown, config?: AxiosLikeConfig): Promise<AxiosLikeResponse<T>> {
    return this.put<T>(url, data, config)
  },

  async delete<T = unknown>(url: string, config?: AxiosLikeConfig): Promise<AxiosLikeResponse<T>> {
    const route = resolveRoute('delete', url, config?.params)
    if (isTauri() && route) {
      const result = await invoke<T>(route.cmd, route.args)
      return { data: result, status: 200, statusText: 'OK' }
    }
    return { data: mockData<T>('delete', url), status: 200, statusText: 'OK' }
  },
}

export default apiClient
