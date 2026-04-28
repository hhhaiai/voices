import { Clock, Flame, Mic, Sparkles, TrendingUp } from 'lucide-react'
import { useEffect, useMemo } from 'react'
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'

import { useTranscriptionsStore } from '@/features/transcriptions'
import { cn } from '@/lib/cn'

export function StatsPage() {
  const { transcriptions, initialized, initialize, getStats } =
    useTranscriptionsStore()

  useEffect(() => {
    if (!initialized) {
      initialize()
    }
  }, [initialized, initialize])

  const stats = getStats()

  // Process data for activity chart (last 14 days)
  const activityData = useMemo(() => {
    const dailyData: Record<string, { words: number; count: number }> = {}
    const now = new Date()

    for (let i = 13; i >= 0; i--) {
      const date = new Date(now)
      date.setDate(date.getDate() - i)
      const key = date.toISOString().split('T')[0]
      dailyData[key] = { words: 0, count: 0 }
    }

    transcriptions.forEach(t => {
      const date = new Date(t.timestamp).toISOString().split('T')[0]
      if (dailyData[date]) {
        dailyData[date].words += t.wordCount
        dailyData[date].count += 1
      }
    })

    return Object.entries(dailyData).map(([date, data]) => ({
      date: new Date(date).toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
      }),
      words: data.words,
    }))
  }, [transcriptions])

  // Calculate streak
  function calculateStreak() {
    if (transcriptions.length === 0) return 0

    const today = new Date()
    today.setHours(0, 0, 0, 0)

    const dates = new Set(
      transcriptions.map(t => {
        const date = new Date(t.timestamp)
        date.setHours(0, 0, 0, 0)
        return date.getTime()
      })
    )

    let streak = 0
    let checkDate = today.getTime()

    while (dates.has(checkDate)) {
      streak++
      checkDate -= 24 * 60 * 60 * 1000
    }

    return streak
  }

  const streak = calculateStreak()

  // Time calculations
  const typingTimeMinutes = Math.round(stats.totalWords / 40)
  const speakingTimeMinutes = Math.round(stats.totalDuration / 60)
  const savedPercentage =
    typingTimeMinutes > 0
      ? Math.round(
          ((typingTimeMinutes - speakingTimeMinutes) / typingTimeMinutes) * 100
        )
      : 0

  // Tooltip style
  const tooltipStyle = {
    backgroundColor: 'rgba(0, 0, 0, 0.9)',
    border: '1px solid rgba(255, 255, 255, 0.1)',
    borderRadius: '8px',
    fontSize: '12px',
    color: '#fff',
  }

  // Empty state
  if (stats.totalTranscriptions === 0) {
    return (
      <div className="h-full w-full flex flex-col px-8">
        <div className="shrink-0 pt-16 pb-6">
          <h1 className="text-2xl font-medium tracking-tight text-foreground">
            Statistics
          </h1>
          <p className="text-sm text-muted-foreground mt-1.5">
            Track your transcription activity and productivity
          </p>
        </div>
        <div className="flex flex-col items-center justify-center py-24 text-center">
          <div className="w-20 h-20 rounded-full bg-muted/50 flex items-center justify-center mb-6">
            <Mic className="h-10 w-10 text-muted-foreground" />
          </div>
          <h3 className="text-xl font-semibold mb-2">No transcriptions yet</h3>
          <p className="text-muted-foreground max-w-sm">
            Start recording with the keyboard shortcut to see your statistics
            here.
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="h-full w-full flex flex-col px-8 pb-8 overflow-y-auto">
      {/* Header */}
      <div className="shrink-0 pt-16 pb-8">
        <h1 className="text-2xl font-medium tracking-tight text-foreground">
          Statistics
        </h1>
        <p className="text-sm text-muted-foreground mt-1.5">
          Your transcription insights at a glance
        </p>
      </div>

      {/* Hero Section - Total Words */}
      <div className="mb-8">
        <div className="flex items-end justify-between">
          <div>
            <p className="text-sm text-muted-foreground mb-2">
              Total words transcribed
            </p>
            <div className="flex items-baseline gap-3">
              <span className="text-4xl font-bold tracking-tight tabular-nums">
                {stats.totalWords.toLocaleString()}
              </span>
              <span className="text-sm text-muted-foreground">
                across {stats.totalTranscriptions} sessions
              </span>
            </div>
            {stats.todayWords > 0 && (
              <p className="text-sm text-emerald-500 mt-2">
                +{stats.todayWords.toLocaleString()} words today
              </p>
            )}
          </div>
          {stats.commandStats.totalCommands > 0 && (
            <div className="text-right">
              <div className="flex items-center gap-2 text-purple-400">
                <Sparkles className="h-4 w-4" />
                <span className="text-sm font-medium">
                  {stats.commandStats.wordsGenerated.toLocaleString()} words
                  generated
                </span>
              </div>
              <p className="text-xs text-muted-foreground mt-1">
                from {stats.commandStats.totalCommands} AI commands
              </p>
            </div>
          )}
        </div>
      </div>

      {/* Key Metrics - 3 cards */}
      <div className="grid grid-cols-3 gap-4 mb-8">
        {/* Streak */}
        <MetricCard>
          <div className="flex items-center gap-2 mb-3">
            <div className="p-1.5 rounded-md bg-orange-500/10">
              <Flame className="h-4 w-4 text-orange-500" />
            </div>
            <span className="text-sm text-muted-foreground">Streak</span>
          </div>
          <div className="flex items-center justify-between">
            <span className="text-3xl font-bold">{streak} days</span>
            <div className="flex gap-1">
              {[...Array(7)].map((_, i) => {
                const dayOffset = 6 - i
                const checkDate = new Date()
                checkDate.setDate(checkDate.getDate() - dayOffset)
                checkDate.setHours(0, 0, 0, 0)
                const hasActivity = transcriptions.some(t => {
                  const tDate = new Date(t.timestamp)
                  tDate.setHours(0, 0, 0, 0)
                  return tDate.getTime() === checkDate.getTime()
                })
                return (
                  <div
                    key={i}
                    className={cn(
                      'w-2 h-6 rounded-sm',
                      hasActivity ? 'bg-orange-500' : 'bg-white/10'
                    )}
                  />
                )
              })}
            </div>
          </div>
        </MetricCard>

        {/* Speaking Speed */}
        <MetricCard>
          <div className="flex items-center gap-2 mb-3">
            <div className="p-1.5 rounded-md bg-blue-500/10">
              <TrendingUp className="h-4 w-4 text-blue-500" />
            </div>
            <span className="text-sm text-muted-foreground">
              Speaking Speed
            </span>
          </div>
          <div className="flex items-end justify-between">
            <div>
              <span className="text-3xl font-bold">{stats.wordsPerMinute}</span>
              <span className="text-lg text-muted-foreground ml-1">wpm</span>
            </div>
            {stats.wordsPerMinute > 40 && (
              <div className="text-right">
                <span className="text-sm text-emerald-500 font-medium">
                  {Math.round((stats.wordsPerMinute / 40) * 100 - 100)}% faster
                </span>
                <p className="text-xs text-muted-foreground">than typing</p>
              </div>
            )}
          </div>
        </MetricCard>

        {/* Time Saved */}
        <MetricCard>
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center gap-2">
              <div className="p-1.5 rounded-md bg-emerald-500/10">
                <Clock className="h-4 w-4 text-emerald-500" />
              </div>
              <span className="text-sm text-muted-foreground">Time Saved</span>
            </div>
            <span className="text-sm font-medium text-emerald-500">
              {savedPercentage}% faster
            </span>
          </div>
          <div className="space-y-2">
            <div className="flex items-center gap-3">
              <span className="text-xs text-muted-foreground w-16">
                Speaking
              </span>
              <div className="flex-1 h-2 bg-white/5 rounded-full overflow-hidden">
                <div
                  className="h-full bg-emerald-500 rounded-full transition-all"
                  style={{
                    width: `${typingTimeMinutes > 0 ? (speakingTimeMinutes / typingTimeMinutes) * 100 : 0}%`,
                  }}
                />
              </div>
              <span className="text-xs font-medium w-10 text-right">
                {speakingTimeMinutes}m
              </span>
            </div>
            <div className="flex items-center gap-3">
              <span className="text-xs text-muted-foreground w-16">Typing</span>
              <div className="flex-1 h-2 bg-white/5 rounded-full overflow-hidden">
                <div className="h-full bg-white/20 rounded-full w-full" />
              </div>
              <span className="text-xs font-medium w-10 text-right text-muted-foreground">
                {typingTimeMinutes}m
              </span>
            </div>
          </div>
        </MetricCard>
      </div>

      {/* Activity Chart */}
      <div className="rounded-2xl border border-white/[0.08] bg-white/[0.02] p-6">
        <div className="flex items-center justify-between mb-6">
          <div>
            <h2 className="text-lg font-semibold">Activity</h2>
            <p className="text-sm text-muted-foreground">
              Words transcribed over the last 14 days
            </p>
          </div>
          <div className="text-right">
            <p className="text-2xl font-bold">
              {activityData
                .reduce((sum, d) => sum + d.words, 0)
                .toLocaleString()}
            </p>
            <p className="text-xs text-muted-foreground">total words</p>
          </div>
        </div>
        <div className="h-[200px] [&_.recharts-surface]:outline-none [&_.recharts-wrapper]:outline-none">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={activityData}>
              <defs>
                <linearGradient id="colorGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#3b82f6" stopOpacity={0.3} />
                  <stop offset="100%" stopColor="#3b82f6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid
                strokeDasharray="3 3"
                stroke="rgba(255,255,255,0.05)"
                vertical={false}
              />
              <XAxis
                dataKey="date"
                tick={{ fontSize: 11, fill: 'rgba(255,255,255,0.4)' }}
                tickLine={false}
                axisLine={false}
              />
              <YAxis
                tick={{ fontSize: 11, fill: 'rgba(255,255,255,0.4)' }}
                tickLine={false}
                axisLine={false}
                width={40}
              />
              <Tooltip
                contentStyle={tooltipStyle}
                cursor={{ fill: 'transparent' }}
              />
              <Area
                type="monotone"
                dataKey="words"
                stroke="#3b82f6"
                strokeWidth={2}
                fill="url(#colorGradient)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}

interface MetricCardProps {
  children: React.ReactNode
  className?: string
}

function MetricCard({ children, className }: MetricCardProps) {
  return (
    <div
      className={cn(
        'rounded-2xl border border-white/[0.08] bg-white/[0.02] p-5',
        className
      )}
    >
      {children}
    </div>
  )
}
