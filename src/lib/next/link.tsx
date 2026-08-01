/**
 * Vite shim for `next/link`.
 * Renders an anchor that navigates via the hash router.
 */
import React, { forwardRef, AnchorHTMLAttributes } from 'react'

export interface LinkProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  href: string
  replace?: boolean
  scroll?: boolean
  prefetch?: boolean
  legacyBehavior?: boolean
  passHref?: boolean
  shallow?: boolean
  children?: React.ReactNode
}

export const Link = forwardRef<HTMLAnchorElement, LinkProps>(function Link(
  { href, replace, scroll, prefetch, legacyBehavior, passHref, children, onClick, ...rest },
  ref
) {
  const target = href.startsWith('#') ? href : `#${href.startsWith('/') ? href : '/' + href}`

  const handleClick = (e: React.MouseEvent<HTMLAnchorElement>) => {
    // Allow modified clicks / new tab behaviour
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
      if (onClick) onClick(e)
      return
    }
    if (onClick) onClick(e)
    if (e.defaultPrevented) return
    e.preventDefault()
    if (replace) {
      const url = window.location.href.split('#')[0] + target
      window.location.replace(url)
    } else {
      window.location.hash = target
    }
    if (scroll !== false) window.scrollTo(0, 0)
  }

  return (
    <a ref={ref} href={target} onClick={handleClick} {...rest}>
      {children}
    </a>
  )
})

export default Link
