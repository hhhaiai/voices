import {
  CircleCheck,
  CircleX,
  Info,
  Loader2,
  TriangleAlert,
} from 'lucide-react'
import { Toaster } from 'sonner'

export function AppToaster() {
  return (
    <Toaster
      position="bottom-center"
      gap={8}
      closeButton
      expand={false}
      icons={{
        success: <CircleCheck className="size-5 text-emerald-400" />,
        error: <CircleX className="size-5 text-red-400" />,
        info: <Info className="size-5 text-blue-400" />,
        warning: <TriangleAlert className="size-5 text-amber-400" />,
        loading: <Loader2 className="size-5 text-white animate-spin ml-0.5" />,
      }}
      toastOptions={{
        unstyled: true,
        classNames: {
          toast:
            'group w-full p-4 pl-12 pr-4 rounded-xl border border-white/10 bg-zinc-900/95 backdrop-blur-xl shadow-2xl shadow-black/40 relative',
          title: 'text-sm font-medium text-white',
          description: 'text-xs text-zinc-400 mt-1',
          actionButton:
            'mt-3 bg-white/10 hover:bg-white/20 text-white text-xs font-medium px-4 py-2 rounded-lg transition-all duration-200 border border-white/10',
          cancelButton:
            'mt-3 bg-transparent hover:bg-white/5 text-zinc-400 hover:text-white text-xs font-medium px-4 py-2 rounded-lg transition-all duration-200',
          closeButton:
            'absolute top-3 right-3 bg-transparent border-0 shadow-none text-zinc-500 hover:text-white transition-colors p-1 rounded-md hover:bg-white/10',
          icon: 'absolute left-4 top-4',
          content: 'w-full',
        },
      }}
    />
  )
}
