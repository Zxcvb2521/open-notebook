import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import { installExternalLinkHandler } from '@/lib/open-external'

installExternalLinkHandler()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)