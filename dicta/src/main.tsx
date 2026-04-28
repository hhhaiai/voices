import React from 'react'
import ReactDOM from 'react-dom/client'

import App from './app'
import { initializeSettings } from './features/settings'
import { initializeSnippets } from './features/snippets'
import { initializeVibes } from './features/vibes'
import { initializeVocabulary } from './features/vocabulary'
import { initializePermissions } from './lib/init-permissions'

const root = ReactDOM.createRoot(document.getElementById('root') as HTMLElement)

// Initialize settings, snippets, vocabulary, vibes, and permissions before rendering the app
Promise.all([
  initializeSettings(),
  initializeSnippets(),
  initializeVocabulary(),
  initializeVibes(),
  initializePermissions(),
]).then(() => {
  root.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>
  )
})
