'use client'

import React, { useEffect, useMemo } from 'react'
import { usePathname } from 'next/navigation'
import { RedirectSignal } from '@/lib/next/navigation'
import '@/styles/globals.css'

// Providers
import { ThemeProvider } from '@/components/providers/ThemeProvider'
import { QueryProvider } from '@/components/providers/QueryProvider'
import { I18nProvider } from '@/components/providers/I18nProvider'
import { ConnectionGuard } from '@/components/common/ConnectionGuard'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { Toaster } from '@/components/ui/sonner'

// Pages
import LoginPage from '@/pages/(auth)/login/page'
import DashboardLayout from '@/pages/(dashboard)/layout'
import NotebooksPage from '@/pages/(dashboard)/notebooks/page'
import NotebookDetailPage from '@/pages/(dashboard)/notebooks/[id]/page'
import SourcesPage from '@/pages/(dashboard)/sources/page'
import SourceDetailPage from '@/pages/(dashboard)/sources/[id]/page'
import PodcastsPage from '@/pages/(dashboard)/podcasts/page'
import SearchPage from '@/pages/(dashboard)/search/page'
import SettingsPage from '@/pages/(dashboard)/settings/page'
import ApiKeysPage from '@/pages/(dashboard)/settings/api-keys/page'
import TransformationsPage from '@/pages/(dashboard)/transformations/page'
import AdvancedPage from '@/pages/(dashboard)/advanced/page'

/**
 * Catches RedirectSignal thrown by redirect() (next/navigation shim)
 * and performs the navigation.
 */
class RedirectBoundary extends React.Component<
  { children: React.ReactNode },
  { redirectHref: string | null }
> {
  constructor(props: { children: React.ReactNode }) {
    super(props)
    this.state = { redirectHref: null }
  }

  static getDerivedStateFromError(error: unknown) {
    if (error instanceof RedirectSignal) {
      return { redirectHref: error.href }
    }
    return null
  }

  componentDidCatch(error: unknown) {
    if (error instanceof RedirectSignal) {
      // Navigate on the next tick
      setTimeout(() => {
        window.location.hash = error.href.startsWith('#') ? error.href : `#${error.href}`
        this.setState({ redirectHref: null })
      }, 0)
    }
  }

  render() {
    if (this.state.redirectHref) {
      return <div style={{ display: 'none' }} />
    }
    return this.props.children
  }
}

function matchPath(pathname: string): { key: string; params: Record<string, string> } {
  const segments = pathname.split('/').filter(Boolean)

  if (segments.length === 0) return { key: 'dashboard', params: {} }

  const [first, second] = segments

  switch (first) {
    case 'login':
      return { key: 'login', params: {} }
    case 'notebooks':
      if (second && second !== 'recently-viewed') return { key: 'notebook-detail', params: { id: second } }
      return { key: 'notebooks', params: {} }
    case 'sources':
      if (second) return { key: 'source-detail', params: { id: second } }
      return { key: 'sources', params: {} }
    case 'podcasts':
      return { key: 'podcasts', params: {} }
    case 'search':
      return { key: 'search', params: {} }
    case 'settings':
      if (second === 'api-keys') return { key: 'api-keys', params: {} }
      return { key: 'settings', params: {} }
    case 'transformations':
      return { key: 'transformations', params: {} }
    case 'advanced':
      return { key: 'advanced', params: {} }
    case 'dev':
      return { key: 'notebooks', params: {} }
    default:
      return { key: 'notebooks', params: {} }
  }
}

function Router() {
  const pathname = usePathname()
  const route = useMemo(() => matchPath(pathname), [pathname])

  const page = useMemo(() => {
    switch (route.key) {
      case 'login':
        return <LoginPage />
      case 'notebooks':
        return <NotebooksPage />
      case 'notebook-detail':
        return <NotebookDetailPage />
      case 'sources':
        return <SourcesPage />
      case 'source-detail':
        return <SourceDetailPage />
      case 'podcasts':
        return <PodcastsPage />
      case 'search':
        return <SearchPage />
      case 'settings':
        return <SettingsPage />
      case 'api-keys':
        return <ApiKeysPage />
      case 'transformations':
        return <TransformationsPage />
      case 'advanced':
        return <AdvancedPage />
      default:
        return <NotebooksPage />
    }
  }, [route.key])

  if (route.key === 'login') {
    return <>{page}</>
  }

  return (
    <RedirectBoundary>
      <DashboardLayout>{page}</DashboardLayout>
    </RedirectBoundary>
  )
}

export default function App() {
  useEffect(() => {
    // Ensure we start at a valid route
    if (!window.location.hash) {
      window.location.hash = '#/notebooks'
    }
  }, [])

  return (
    <ErrorBoundary>
      <ThemeProvider>
        <QueryProvider>
          <I18nProvider>
            <ConnectionGuard>
              <Router />
              <Toaster position="top-right" richColors />
            </ConnectionGuard>
          </I18nProvider>
        </QueryProvider>
      </ThemeProvider>
    </ErrorBoundary>
  )
}
