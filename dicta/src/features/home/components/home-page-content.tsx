import { Plus } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'

import { Button } from '@/components/ui/button'
import {
  useTranscriptionsStore,
  initializeTranscriptions,
  setupTranscriptionsSync,
} from '@/features/transcriptions'

import { groupTranscriptionsByDate, filterTranscriptions } from '../utils'
import { EmptyState } from './empty-state'
import {
  SearchFilterBar,
  defaultFilterState,
  type FilterState,
} from './search-filter-bar'
import { StatsHeader } from './stats-header'
import { TranscriptionGroup } from './transcription-group'
import { UploadDialog } from './upload-dialog'

export function HomePageContent() {
  const { transcriptions, initialized, getStats, deleteTranscription } =
    useTranscriptionsStore()
  const [uploadDialogOpen, setUploadDialogOpen] = useState(false)
  const [filters, setFilters] = useState<FilterState>(defaultFilterState)

  const stats = getStats()

  // Initialize transcriptions store
  useEffect(() => {
    if (!initialized) {
      void initializeTranscriptions()
    }

    setupTranscriptionsSync()
  }, [initialized])

  // Filter transcriptions
  const filteredTranscriptions = useMemo(
    () => filterTranscriptions(transcriptions, filters),
    [transcriptions, filters]
  )

  // Group filtered transcriptions by date
  const groupedTranscriptions = useMemo(
    () => groupTranscriptionsByDate(filteredTranscriptions),
    [filteredTranscriptions]
  )

  const handleDeleteTranscription = (id: string) => {
    void deleteTranscription(id)
  }

  return (
    <div className="h-full w-full flex flex-col px-8">
      {/* Page Header */}
      <div className="shrink-0 pt-16 pb-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-medium tracking-tight text-foreground">
              Transcriptions
            </h1>
            <span className="text-xs font-medium text-muted-foreground bg-muted/60 px-2 py-0.5 rounded tabular-nums">
              {transcriptions.length}
            </span>
          </div>
          <Button size="sm" onClick={() => setUploadDialogOpen(true)}>
            <Plus className="w-3.5 h-3.5 mr-1.5" />
            Upload Audio
          </Button>
        </div>
        <p className="text-sm text-muted-foreground mt-1.5">
          Your voice recordings and uploaded audio transcriptions.
        </p>
      </div>

      {/* Stats Cards */}
      <div className="shrink-0 pb-4">
        <StatsHeader
          todayCount={stats.todayCount}
          totalTranscriptions={stats.totalTranscriptions}
          totalWords={stats.totalWords}
          todayWords={stats.todayWords}
          wordsPerMinute={stats.wordsPerMinute}
          timeSavedMinutes={stats.timeSavedMinutes}
        />
      </div>

      {/* Search and Filters */}
      {transcriptions.length > 0 && (
        <div className="shrink-0 pb-4">
          <SearchFilterBar
            filters={filters}
            onFiltersChange={setFilters}
            totalCount={transcriptions.length}
            filteredCount={filteredTranscriptions.length}
          />
        </div>
      )}

      {/* Transcription List */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden pb-8">
        {transcriptions.length === 0 ? (
          <EmptyState />
        ) : filteredTranscriptions.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <p className="text-sm text-muted-foreground">
              No transcriptions match your filters
            </p>
            <button
              onClick={() => setFilters(defaultFilterState)}
              className="mt-2 text-sm text-primary hover:underline"
            >
              Clear all filters
            </button>
          </div>
        ) : (
          groupedTranscriptions.map(group => (
            <TranscriptionGroup
              key={group.date}
              group={group}
              onDeleteTranscription={handleDeleteTranscription}
              searchQuery={filters.search}
            />
          ))
        )}
      </div>

      <UploadDialog
        open={uploadDialogOpen}
        onOpenChange={setUploadDialogOpen}
      />
    </div>
  )
}
