/**
 * Runtime configuration for the frontend — Tauri edition.
 * Open Notebook Tauri runs fully local: there is no external HTTP API.
 * Data access goes through Tauri commands (window.__TAURI__.core.invoke).
 * This module keeps the same interface as the original so the rest of the
 * frontend (ConnectionGuard etc.) works unchanged.
 */

import { AppConfig } from '@/lib/types/config'

const BUILD_TIME = new Date().toISOString()

let config: AppConfig | null = null

/**
 * API URL — empty string: requests are handled by the local invoke bridge.
 */
export async function getApiUrl(): Promise<string> {
  return ''
}

/**
 * Get the full configuration (local backend, always "ok").
 * When running inside Tauri it also checks GitHub for a newer release.
 */
export async function getConfig(): Promise<AppConfig> {
  if (config) return config

  const isTauri = typeof window !== 'undefined' && !!window.__TAURI__?.core?.invoke

  let latestVersion: string | null = null
  let hasUpdate = false
  let updateUrl: string | null = null

  if (isTauri) {
    try {
      const info = (await window.__TAURI__!.core!.invoke('check_updates')) as {
        latest_version?: string | null
        has_update?: boolean
        url?: string
      }
      latestVersion = info.latest_version || null
      hasUpdate = !!info.has_update
      updateUrl = info.url || null
    } catch (e) {
      console.warn('[config] update check failed:', e)
    }
  }

  config = {
    apiUrl: '',
    version: '0.1.0-tauri',
    buildTime: BUILD_TIME,
    latestVersion,
    hasUpdate,
    updateUrl,
    dbStatus: 'ok',
  }
  return config
}

/**
 * Reset the configuration cache.
 */
export function resetConfig(): void {
  config = null
}
