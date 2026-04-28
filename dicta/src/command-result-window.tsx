import { StrictMode } from 'react'
import ReactDOM from 'react-dom/client'

import { CommandResult } from '@/features/command-result/components/command-result'

import './index.css'

function CommandResultWindowApp() {
  return (
    <StrictMode>
      <CommandResult />
    </StrictMode>
  )
}

const rootElement = document.getElementById('command-result-root')!
const root = ReactDOM.createRoot(rootElement)
root.render(<CommandResultWindowApp />)
