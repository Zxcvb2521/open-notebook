/**
 * Vite shim for `next/navigation`.
 * Hash-based routing so the same app works inside Tauri (file://) and in a browser.
 */

import { useCallback, useEffect, useMemo, useSyncExternalStore } from 'react'

export type AppRouterInstance = {
  push: (href: string) => void
  replace: (href: string) => void
  back: () => void
  forward: () => void
  refresh: () => void
  prefetch: (href: string) => void
}

function getHash(): string {
  return window.location.hash || ''
}

function parseHash(): { pathname: string; search: string } {
  const hash = getHash()
  // Support both "#/path" and "#path"
  const raw = hash.startsWith('#') ? hash.slice(1) : hash
  const qIndex = raw.indexOf('?')
  if (qIndex === -1) return { pathname: raw || '/', search: '' }
  return { pathname: raw.slice(0, qIndex) || '/', search: raw.slice(qIndex + 1) }
}

function subscribe(callback: () => void): () => void {
  window.addEventListener('hashchange', callback)
  return () => window.removeEventListener('hashchange', callback)
}

function getSnapshot(): string {
  return getHash()
}

/** Current pathname (from hash). Re-renders on hash change. */
export function usePathname(): string {
  const hash = useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
  return parseHashFromRaw(hash).pathname
}

function parseHashFromRaw(hash: string): { pathname: string; search: string } {
  const raw = hash.startsWith('#') ? hash.slice(1) : hash
  const qIndex = raw.indexOf('?')
  if (qIndex === -1) return { pathname: raw || '/', search: '' }
  return { pathname: raw.slice(0, qIndex) || '/', search: raw.slice(qIndex + 1) }
}

/** Current search params (from hash query). Re-renders on hash change. */
export function useSearchParams(): URLSearchParams {
  const hash = useSyncExternalStore(subscribe, getSnapshot, getSnapshot)
  const { search } = parseHashFromRaw(hash)
  return useMemo(() => new URLSearchParams(search), [search])
}

/** Route params for dynamic segments (/notebooks/:id, /sources/:id). */
export function useParams<T extends Record<string, string> = Record<string, string>>(): T {
  const pathname = usePathname()
  return useMemo(() => {
    const params: Record<string, string> = {}
    const match = pathname.match(/^\/(notebooks|sources)\/([^/]+)\/?$/)
    if (match) {
      params.id = decodeURIComponent(match[2])
    }
    return params as T
  }, [pathname])
}

function navigate(href: string, replace = false): void {
  const target = href.startsWith('#') ? href : `#${href.startsWith('/') ? href : '/' + href}`
  if (replace) {
    // location.replace with hash triggers hashchange
    const url = window.location.href.split('#')[0] + target
    window.location.replace(url)
  } else {
    if (getHash() === target) {
      // Force re-render for same-hash navigations
      window.dispatchEvent(new Event('hashchange'))
    } else {
      window.location.hash = target
    }
    window.scrollTo(0, 0)
  }
}

/** Router instance compatible with Next.js App Router. */
export function useRouter(): AppRouterInstance {
  const push = useCallback((href: string) => navigate(href, false), [])
  const replace = useCallback((href: string) => navigate(href, true), [])
  const back = useCallback(() => window.history.back(), [])
  const forward = useCallback(() => window.history.forward(), [])
  const refresh = useCallback(() => window.dispatchEvent(new Event('hashchange')), [])
  const prefetch = useCallback((_href: string) => {}, [])
  return { push, replace, back, forward, refresh, prefetch }
}

/** Redirect helper (Next.js throws; here we just navigate and return). */
export function redirect(href: string): never {
  navigate(href, true)
  // Next semantics: redirect() never returns. Emulate with a sentinel throw so
  // callers that rely on "unreachable after redirect" still behave.
  throw new RedirectSignal(href)
}

export class RedirectSignal extends Error {
  href: string
  constructor(href: string) {
    super(`Redirect to ${href}`)
    this.href = href
  }
}

/** NotFound helper. In a client-only app we render the nearest error boundary. */
export function notFound(): never {
  throw new Error('NEXT_NOT_FOUND')
}

/** next/navigation also exports these in some versions */
export const useSelectedLayoutSegment = () => null
export const useSelectedLayoutSegments = () => []
export const useRouterLegacy = useRouter
export default useRouter
