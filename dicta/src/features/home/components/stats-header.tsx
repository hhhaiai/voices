interface StatsHeaderProps {
  todayCount: number
  totalTranscriptions: number
  totalWords: number
  todayWords?: number
  wordsPerMinute?: number
  timeSavedMinutes?: number
}

export function StatsHeader({
  todayCount,
  totalTranscriptions,
  totalWords,
  todayWords = 0,
  timeSavedMinutes = 0,
}: StatsHeaderProps) {
  return (
    <div>
      <div className="grid grid-cols-4 gap-2.5">
        <KPICard
          label="Today"
          value={todayWords}
          tag={`${todayCount} rec`}
          accentColor="primary"
        />
        <KPICard
          label="Total"
          value={totalWords}
          tag="words"
          accentColor="emerald"
        />
        <KPICard
          label="Recordings"
          value={totalTranscriptions}
          tag="all time"
          accentColor="blue"
        />
        <KPICard
          label="Saved"
          value={timeSavedMinutes}
          tag="minutes"
          accentColor="violet"
        />
      </div>
    </div>
  )
}

interface KPICardProps {
  label: string
  value: number
  tag: string
  accentColor: 'primary' | 'emerald' | 'blue' | 'violet'
}

function KPICard({ label, value, tag, accentColor }: KPICardProps) {
  const colorConfig: Record<
    typeof accentColor,
    {
      tagBg: string
      tagText: string
      accent: string
    }
  > = {
    primary: {
      tagBg: 'bg-primary/15',
      tagText: 'text-primary',
      accent: '#4ade80',
    },
    emerald: {
      tagBg: 'bg-emerald-500/15',
      tagText: 'text-emerald-400',
      accent: '#34d399',
    },
    blue: {
      tagBg: 'bg-blue-500/15',
      tagText: 'text-blue-400',
      accent: '#60a5fa',
    },
    violet: {
      tagBg: 'bg-violet-500/15',
      tagText: 'text-violet-400',
      accent: '#a78bfa',
    },
  }

  const config = colorConfig[accentColor]

  return (
    <div className="relative rounded-lg border border-border/50 bg-card/50 backdrop-blur-sm p-3 overflow-hidden group hover:border-border/80 transition-colors">
      {/* Subtle gradient accent line at top */}
      <div
        className="absolute top-0 left-0 right-0 h-[2px] opacity-60"
        style={{
          background: `linear-gradient(90deg, ${config.accent}00, ${config.accent}, ${config.accent}00)`,
        }}
      />

      <div className="relative">
        <p className="text-[10px] font-medium text-muted-foreground uppercase tracking-wider mb-1">
          {label}
        </p>
        <span className="text-xl font-bold tracking-tight text-foreground tabular-nums">
          {value.toLocaleString()}
        </span>
        <div
          className={`inline-flex items-center mt-1.5 px-1.5 py-0.5 rounded text-[9px] font-medium ${config.tagBg} ${config.tagText}`}
        >
          {tag}
        </div>
      </div>
    </div>
  )
}
