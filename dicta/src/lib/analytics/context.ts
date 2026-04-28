import { createContext, useContext } from 'react'

export interface AnalyticsContextValue {
  isInitialized: boolean
  isEnabled: boolean
}

export const AnalyticsContext = createContext<AnalyticsContextValue>({
  isInitialized: false,
  isEnabled: false,
})

export function useAnalyticsContext() {
  return useContext(AnalyticsContext)
}
