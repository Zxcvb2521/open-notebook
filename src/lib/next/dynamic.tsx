/**
 * Vite shim for `next/dynamic`.
 */
import React, { lazy, Suspense, ComponentType } from 'react'

type Loader<T> = () => Promise<{ default: T }>

export function dynamic<T extends ComponentType<any>>(
  loader: Loader<T>,
  options?: { ssr?: boolean; loading?: () => React.ReactNode; ssrDisabled?: boolean }
) {
  // React.lazy requires the promise to resolve to `{ default: Component }`.
  // Callers often write `dynamic(() => import('x').then((m) => m.default))`
  // (the Next.js pattern), which resolves to the component itself — React
  // then looks for `.default` on it, gets `undefined`, and throws
  // "Lazy element type must resolve to a class or function". Normalize the
  // resolved value so either shape works.
  const LazyComp = lazy(() =>
    loader().then((resolved) => {
      if (resolved && typeof resolved === 'object' && 'default' in resolved) {
        return resolved as { default: T }
      }
      return { default: resolved } as { default: T }
    })
  )
  const Loading = options?.loading
  const Wrapped = (props: React.ComponentProps<T>) => (
    <Suspense fallback={Loading ? <Loading /> : null}>
      <LazyComp {...props} />
    </Suspense>
  )
  Wrapped.displayName = 'DynamicComponent'
  return Wrapped
}

export default dynamic
