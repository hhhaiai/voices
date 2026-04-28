import { lazy, Suspense, useEffect } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'

import { AppLayout } from './components/app-layout'
import { AppToaster } from './components/app-toaster'
import { ProtectedRoute } from './components/protected-route'
import { UpdateModal } from './components/update-modal'
import { HelpPage } from './features/help'
import { HomePageContent } from './features/home'
import { initializeModelStatusListener } from './features/models'
import { ModelsPage } from './features/models'
import { OnboardingPage } from './features/onboarding'
import { SnippetsPage } from './features/snippets'
import { StatsPage } from './features/stats'
import { VibesPage } from './features/vibes'
import { VocabularyPage } from './features/vocabulary'
import { useLanguageSync } from './hooks/use-language-sync'
import { useMicrophoneDeviceSync } from './hooks/use-microphone-device-sync'
import { useUpdateChecker } from './hooks/use-update-checker'
import { AnalyticsProvider, useAnalytics } from './lib/analytics'
import { ThemeProvider } from './providers/theme-provider'

const DevTools = import.meta.env.DEV
  ? lazy(() =>
      import('./components/dev-tools').then(m => ({ default: m.DevTools }))
    )
  : () => null

import './index.css'

function AppContent() {
  const { capture, events } = useAnalytics()

  useEffect(() => {
    initializeModelStatusListener()
  }, [])

  useMicrophoneDeviceSync()
  useLanguageSync()

  const { updateState, setShowModal } = useUpdateChecker()

  useEffect(() => {
    capture(events.APP_LAUNCHED)
  }, [capture, events])

  return (
    <BrowserRouter>
      <AppToaster />
      {import.meta.env.DEV && (
        <Suspense fallback={null}>
          <DevTools />
        </Suspense>
      )}
      <UpdateModal
        open={updateState.showModal}
        onOpenChange={setShowModal}
        version={updateState.version}
        releaseNotes={updateState.releaseNotes}
        status={updateState.status}
        downloadProgress={updateState.downloadProgress}
      />
      <Routes>
        <Route path="/onboarding" element={<OnboardingPage />} />
        <Route
          path="/*"
          element={
            <ProtectedRoute>
              <AppLayout>
                <Routes>
                  <Route path="/" element={<HomePageContent />} />
                  <Route path="/snippets" element={<SnippetsPage />} />
                  <Route path="/vocabulary" element={<VocabularyPage />} />
                  <Route path="/vibes" element={<VibesPage />} />
                  <Route path="/help" element={<HelpPage />} />
                  <Route path="/models" element={<ModelsPage />} />
                  <Route path="/stats" element={<StatsPage />} />
                  <Route path="*" element={<Navigate to="/" replace />} />
                </Routes>
              </AppLayout>
            </ProtectedRoute>
          }
        />
      </Routes>
    </BrowserRouter>
  )
}

function App() {
  return (
    <ThemeProvider defaultTheme="system">
      <AnalyticsProvider>
        <AppContent />
      </AnalyticsProvider>
    </ThemeProvider>
  )
}

export default App
