/**
 * External link helper — Tauri edition.
 *
 * window.open() does not work inside the Tauri WebView (WebView2). To open a
 * link in the system default browser we must ask the Rust backend via the
 * shell plugin (`open_external` command). When running in a plain browser
 * (vite dev preview) we fall back to window.open.
 */

import type { MouseEvent as ReactMouseEvent } from 'react'

const isTauri = (): boolean =>
  typeof window !== 'undefined' && !!window.__TAURI__?.core?.invoke

/**
 * Open an external URL in the system default browser.
 * Falls back to window.open when not running inside Tauri.
 */
export async function openExternal(url: string): Promise<void> {
  if (!url) return
  // Safety: only allow http(s) links
  if (!/^https?:\/\//i.test(url)) return

  if (isTauri()) {
    try {
      await window.__TAURI__!.core!.invoke('open_external', { url })
      return
    } catch (err) {
      console.error('[open-external] Tauri open failed, falling back:', err)
    }
  }
  // Fallback: plain browser or Tauri failure
  const w = window.open(url, '_blank', 'noopener,noreferrer')
  if (w) w.opener = null
}

/**
 * Click handler for <a> elements: routes external links through the system
 * browser instead of the WebView. Attach via onClick on anchor tags.
 */
export function handleExternalLinkClick(
  e: ReactMouseEvent<HTMLAnchorElement>,
): void {
  const href = e.currentTarget.getAttribute('href')
  if (!href) return
  if (/^https?:\/\//i.test(href)) {
    e.preventDefault()
    void openExternal(href)
  }
}

/**
 * Global document-level click interceptor. Any <a target="_blank"> (or plain
 * external <a href>) is routed to the system browser. Call once at app boot.
 */
export function installExternalLinkHandler(): () => void {
  const listener = (e: MouseEvent): void => {
    if (e.defaultPrevented) return
    const target = e.target as HTMLElement | null
    const anchor = target?.closest?.('a') as HTMLAnchorElement | null
    if (!anchor) return
    const href = anchor.getAttribute('href')
    if (!href || !/^https?:\/\//i.test(href)) return
    // Skip links the app intentionally handles itself
    if (anchor.hasAttribute('data-no-external')) return
    if (!isTauri()) return
    e.preventDefault()
    void openExternal(href)
  }
  document.addEventListener('click', listener)
  return () => document.removeEventListener('click', listener)
}
