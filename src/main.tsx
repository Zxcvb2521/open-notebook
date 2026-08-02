import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import { installExternalLinkHandler } from '@/lib/open-external'
import { Instrument_Sans, Spline_Sans_Mono, Bricolage_Grotesque } from '@/lib/next/font-google'

installExternalLinkHandler()

// Bootstrap design fonts (Quiet Green): load from Google Fonts and map the
// family name to the CSS variables the design system references. Falls back
// to system fonts when offline.
function bootstrapFonts() {
  if (typeof document === 'undefined') return

  Instrument_Sans({ weight: ['400', '500', '600', '700'], variable: '--font-instrument-sans' })
  Spline_Sans_Mono({ weight: ['400', '500', '600'], variable: '--font-spline-mono' })
  Bricolage_Grotesque({ weight: ['600', '700', '800'], variable: '--font-bricolage' })
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)

bootstrapFonts()