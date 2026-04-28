import { SquareBottomDashedScissors, Plus, Pencil, Trash2 } from 'lucide-react'
import { useState } from 'react'

import { Button } from '@/components/ui/button'
import { SnippetsSupportBanner } from '@/components/ui/feature-banner'

import { SnippetDialog } from '../components/snippet-dialog'
import { useSnippetsStore } from '../store'

import type { Snippet } from '../types'

export function SnippetsPage() {
  const { snippets, deleteSnippet } = useSnippetsStore()
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editingSnippet, setEditingSnippet] = useState<Pick<
    Snippet,
    'id' | 'snippet' | 'expansion'
  > | null>(null)

  const handleCreate = () => {
    setEditingSnippet(null)
    setDialogOpen(true)
  }

  const handleEdit = (snippet: Snippet) => {
    setEditingSnippet({
      id: snippet.id,
      snippet: snippet.snippet,
      expansion: snippet.expansion,
    })
    setDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this snippet?')) return
    try {
      await deleteSnippet(id)
    } catch (error) {
      console.error('Failed to delete snippet:', error)
    }
  }

  return (
    <div className="h-full w-full flex flex-col px-8">
      <div className="shrink-0 pt-16 pb-6">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <h1 className="text-2xl font-medium tracking-tight text-foreground">
              Snippets
            </h1>
            <span className="text-xs font-medium text-muted-foreground bg-muted/60 px-2 py-0.5 rounded tabular-nums">
              {snippets.length}
            </span>
          </div>
          <Button size="sm" onClick={handleCreate}>
            <Plus className="w-3.5 h-3.5 mr-1.5" />
            New Snippet
          </Button>
        </div>
        <p className="text-sm text-muted-foreground mt-1.5">
          Save frequently used phrases and insert them with a shortcut.
        </p>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto">
        {snippets.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 px-4">
            <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-muted/60 mb-4">
              <SquareBottomDashedScissors
                className="w-5 h-5 text-muted-foreground/60"
                strokeWidth={1.5}
              />
            </div>
            <h3 className="text-sm font-medium text-foreground mb-1">
              No snippets yet
            </h3>
            <p className="text-xs text-muted-foreground text-center max-w-[260px] leading-relaxed">
              Create your first snippet to save time on repetitive text
            </p>
          </div>
        ) : (
          <div className="space-y-2">
            {snippets.map(snippet => (
              <div
                key={snippet.id}
                className="group rounded-lg border border-border bg-card px-4 py-3 hover:bg-accent/40 transition-colors"
              >
                <div className="flex justify-between items-start gap-4">
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <code className="text-xs font-mono bg-primary/8 text-primary px-1.5 py-0.5 rounded">
                        {snippet.snippet}
                      </code>
                    </div>
                    <p className="text-[13px] text-muted-foreground leading-relaxed line-clamp-2">
                      {snippet.expansion}
                    </p>
                  </div>

                  <div className="flex gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity shrink-0">
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      onClick={() => handleEdit(snippet)}
                    >
                      <Pencil className="h-3.5 w-3.5" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon-sm"
                      onClick={() => handleDelete(snippet.id)}
                      className="text-muted-foreground hover:text-destructive"
                    >
                      <Trash2 className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Bottom Banner */}
      <SnippetsSupportBanner className="shrink-0 mt-6 mb-8" />

      <SnippetDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        editingSnippet={editingSnippet}
      />
    </div>
  )
}
