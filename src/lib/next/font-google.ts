/**
 * Vite shim for `next/font/google`.
 * Loads the design fonts used by the original Open Notebook UI.
 * Fonts are fetched from Google Fonts CDN with a local fallback.
 */
import { CSSProperties } from 'react'

type FontOptions = {
  subsets?: string[]
  weight?: string | string[]
  variable?: string
  display?: string
  style?: string
}

type FontResult = {
  className: string
  style: CSSProperties
  variable: string
}

const FONT_FACES: Record<string, { family: string; css: string }> = {
  Instrument_Sans: {
    family: 'Instrument Sans',
    css: 'instrument-sans',
  },
  Bricolage_Grotesque: {
    family: 'Bricolage Grotesque',
    css: 'bricolage-grotesque',
  },
  Spline_Sans_Mono: {
    family: 'Spline Sans Mono',
    css: 'spline-sans-mono',
  },
}

function makeFont(name: string, options: FontOptions = {}): FontResult {
  const config = FONT_FACES[name] || { family: name, css: name.toLowerCase().replace(/_/g, '-') }
  const variable = options.variable || `--font-${config.css}`

  // Inject Google Fonts stylesheet once
  if (typeof document !== 'undefined' && !document.getElementById(`font-${config.css}`)) {
    const link = document.createElement('link')
    link.id = `font-${config.css}`
    link.rel = 'stylesheet'
    const weights = Array.isArray(options.weight) ? options.weight.join(';') : options.weight || '400'
    link.href = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(config.family).replace(/%20/g, '+')}:wght@${weights.replace(/;/g, ';')}&display=swap`
    document.head.appendChild(link)
  }

  return {
    className: '',
    style: { fontFamily: `'${config.family}', sans-serif` },
    variable,
  }
}

export const Instrument_Sans = (options: FontOptions) => makeFont('Instrument_Sans', options)
export const Bricolage_Grotesque = (options: FontOptions) => makeFont('Bricolage_Grotesque', options)
export const Spline_Sans_Mono = (options: FontOptions) => makeFont('Spline_Sans_Mono', options)
