import { Search, X, Filter } from 'lucide-react'
import { useState, useCallback, useMemo } from 'react'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Input } from '@/components/ui/input'
import { cn } from '@/lib/cn'

export type SourceFilter = 'all' | 'recording' | 'upload'
export type TimeFilter = 'all' | 'today' | 'week' | 'month'
export type AudioFilter = 'all' | 'with-audio' | 'without-audio'

export interface FilterState {
  search: string
  source: SourceFilter
  time: TimeFilter
  audio: AudioFilter
}

interface SearchFilterBarProps {
  filters: FilterState
  onFiltersChange: (filters: FilterState) => void
  totalCount: number
  filteredCount: number
}

interface FilterOption<T extends string> {
  value: T
  label: string
}

const sourceOptions: FilterOption<SourceFilter>[] = [
  { value: 'all', label: 'All Sources' },
  { value: 'recording', label: 'Recordings' },
  { value: 'upload', label: 'Uploads' },
]

const timeOptions: FilterOption<TimeFilter>[] = [
  { value: 'all', label: 'All Time' },
  { value: 'today', label: 'Today' },
  { value: 'week', label: 'This Week' },
  { value: 'month', label: 'This Month' },
]

const audioOptions: FilterOption<AudioFilter>[] = [
  { value: 'all', label: 'All' },
  { value: 'with-audio', label: 'With Audio' },
  { value: 'without-audio', label: 'Without Audio' },
]

export function SearchFilterBar({
  filters,
  onFiltersChange,
  totalCount,
  filteredCount,
}: SearchFilterBarProps) {
  const [searchFocused, setSearchFocused] = useState(false)

  const updateFilter = useCallback(
    <K extends keyof FilterState>(key: K, value: FilterState[K]) => {
      onFiltersChange({ ...filters, [key]: value })
    },
    [filters, onFiltersChange]
  )

  const clearSearch = useCallback(() => {
    updateFilter('search', '')
  }, [updateFilter])

  const activeFilterCount = useMemo(() => {
    let count = 0
    if (filters.source !== 'all') count++
    if (filters.time !== 'all') count++
    if (filters.audio !== 'all') count++
    return count
  }, [filters])

  const hasActiveFilters = useMemo(() => {
    return filters.search !== '' || activeFilterCount > 0
  }, [filters.search, activeFilterCount])

  const clearAllFilters = useCallback(() => {
    onFiltersChange({
      search: '',
      source: 'all',
      time: 'all',
      audio: 'all',
    })
  }, [onFiltersChange])

  const clearDropdownFilters = useCallback(() => {
    onFiltersChange({
      ...filters,
      source: 'all',
      time: 'all',
      audio: 'all',
    })
  }, [filters, onFiltersChange])

  const isFiltered = filteredCount !== totalCount

  return (
    <div className="space-y-2.5">
      {/* Search and Filter Row */}
      <div className="flex items-center justify-between">
        {/* Search Input */}
        <div className="relative w-72">
          <Search
            className={cn(
              'absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 transition-colors',
              searchFocused ? 'text-primary' : 'text-muted-foreground'
            )}
          />
          <Input
            type="text"
            placeholder="Search transcriptions..."
            value={filters.search}
            onChange={e => updateFilter('search', e.target.value)}
            onFocus={() => setSearchFocused(true)}
            onBlur={() => setSearchFocused(false)}
            className="pl-9 pr-9 h-9 text-sm bg-muted/30 border-border/50 focus:border-primary/50 focus:bg-background"
          />
          {filters.search && (
            <button
              onClick={clearSearch}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
            >
              <X className="h-4 w-4" />
            </button>
          )}
        </div>

        {/* Filter Dropdown */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button
              variant="outline"
              size="icon"
              className={cn(
                'relative border-border/50',
                activeFilterCount > 0 &&
                  'bg-primary/10 border-primary/30 text-primary hover:bg-primary/15'
              )}
            >
              <Filter className="h-4 w-4" />
              {activeFilterCount > 0 && (
                <span className="absolute -top-1 -right-1 flex h-4 w-4 items-center justify-center rounded-full bg-primary text-[10px] font-medium text-primary-foreground">
                  {activeFilterCount}
                </span>
              )}
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-48">
            {/* Source Filter */}
            <DropdownMenuLabel className="text-xs text-muted-foreground font-normal">
              Source
            </DropdownMenuLabel>
            <DropdownMenuRadioGroup
              value={filters.source}
              onValueChange={v => updateFilter('source', v as SourceFilter)}
            >
              {sourceOptions.map(option => (
                <DropdownMenuRadioItem
                  key={option.value}
                  value={option.value}
                  className="text-sm"
                >
                  {option.label}
                </DropdownMenuRadioItem>
              ))}
            </DropdownMenuRadioGroup>

            <DropdownMenuSeparator />

            {/* Time Filter */}
            <DropdownMenuLabel className="text-xs text-muted-foreground font-normal">
              Time
            </DropdownMenuLabel>
            <DropdownMenuRadioGroup
              value={filters.time}
              onValueChange={v => updateFilter('time', v as TimeFilter)}
            >
              {timeOptions.map(option => (
                <DropdownMenuRadioItem
                  key={option.value}
                  value={option.value}
                  className="text-sm"
                >
                  {option.label}
                </DropdownMenuRadioItem>
              ))}
            </DropdownMenuRadioGroup>

            <DropdownMenuSeparator />

            {/* Audio Filter */}
            <DropdownMenuLabel className="text-xs text-muted-foreground font-normal">
              Audio
            </DropdownMenuLabel>
            <DropdownMenuRadioGroup
              value={filters.audio}
              onValueChange={v => updateFilter('audio', v as AudioFilter)}
            >
              {audioOptions.map(option => (
                <DropdownMenuRadioItem
                  key={option.value}
                  value={option.value}
                  className="text-sm"
                >
                  {option.label}
                </DropdownMenuRadioItem>
              ))}
            </DropdownMenuRadioGroup>

            {/* Clear Filters */}
            {activeFilterCount > 0 && (
              <>
                <DropdownMenuSeparator />
                <button
                  onClick={clearDropdownFilters}
                  className="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                >
                  <X className="h-4 w-4" />
                  Clear filters
                </button>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>

      {/* Results count and clear */}
      {hasActiveFilters && (
        <div className="flex items-center justify-between text-xs">
          <span className="text-muted-foreground">
            {isFiltered ? (
              <>
                Showing{' '}
                <span className="font-medium text-foreground">
                  {filteredCount}
                </span>{' '}
                of{' '}
                <span className="font-medium text-foreground">
                  {totalCount}
                </span>{' '}
                transcriptions
              </>
            ) : (
              <>
                <span className="font-medium text-foreground">
                  {totalCount}
                </span>{' '}
                transcriptions
              </>
            )}
          </span>
          <button
            onClick={clearAllFilters}
            className="text-muted-foreground hover:text-foreground transition-colors flex items-center gap-1"
          >
            <X className="h-3 w-3" />
            Clear all
          </button>
        </div>
      )}
    </div>
  )
}

export const defaultFilterState: FilterState = {
  search: '',
  source: 'all',
  time: 'all',
  audio: 'all',
}
