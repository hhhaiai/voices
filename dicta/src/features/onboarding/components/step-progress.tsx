import { Check } from 'lucide-react'

interface StepProgressProps {
  totalSteps: number
  currentStep: number
}

export function StepProgress({ totalSteps, currentStep }: StepProgressProps) {
  return (
    <div className="flex items-center gap-2">
      {Array.from({ length: totalSteps }).map((_, index) => {
        const isCompleted = index < currentStep
        const isCurrent = index === currentStep

        return (
          <div key={index} className="flex items-center gap-2">
            {/* Step indicator */}
            <div
              className={`
                flex items-center justify-center w-6 h-6 rounded-full text-xs font-medium
                transition-colors duration-200
                ${
                  isCompleted
                    ? 'bg-primary text-primary-foreground'
                    : isCurrent
                      ? 'bg-primary/20 text-primary border border-primary/40'
                      : 'bg-zinc-800 text-muted-foreground border border-zinc-700'
                }
              `}
            >
              {isCompleted ? (
                <Check className="w-3 h-3" strokeWidth={2.5} />
              ) : (
                <span>{index + 1}</span>
              )}
            </div>

            {/* Connector line */}
            {index < totalSteps - 1 && (
              <div
                className={`
                  w-8 h-px transition-colors duration-200
                  ${isCompleted ? 'bg-primary/50' : 'bg-zinc-700'}
                `}
              />
            )}
          </div>
        )
      })}
    </div>
  )
}
