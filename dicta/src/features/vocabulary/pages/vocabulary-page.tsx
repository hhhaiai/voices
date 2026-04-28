import { BookOpen, MoreHorizontal, Pencil, Plus, Trash2 } from 'lucide-react'
import { useState } from 'react'

import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { VocabularySupportBanner } from '@/components/ui/feature-banner'

import { VocabularyDialog } from '../components/vocabulary-dialog'
import { useVocabularyStore } from '../store'

import type { VocabularyWord } from '../types'

export function VocabularyPage() {
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editingWord, setEditingWord] = useState<Pick<
    VocabularyWord,
    'id' | 'word'
  > | null>(null)

  const { words, deleteWord } = useVocabularyStore()

  const handleCreate = () => {
    setEditingWord(null)
    setDialogOpen(true)
  }

  const handleEdit = (word: VocabularyWord) => {
    setEditingWord({
      id: word.id,
      word: word.word,
    })
    setDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this word?')) return
    try {
      await deleteWord(id)
    } catch (error) {
      console.error('Failed to delete word:', error)
    }
  }

  return (
    <>
      <div className="h-full flex flex-col p-8 pt-16">
        {/* Header */}
        <div className="shrink-0 mb-8">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <h1 className="text-2xl font-medium tracking-tight text-foreground">
                Vocabulary
              </h1>
              <span className="text-xs font-medium text-muted-foreground bg-muted/60 px-2 py-0.5 rounded tabular-nums">
                {words.length}
              </span>
            </div>
            <Button size="sm" onClick={handleCreate}>
              <Plus className="w-3.5 h-3.5 mr-1.5" />
              Add Word
            </Button>
          </div>
          <p className="text-sm text-muted-foreground mt-1.5">
            Custom words and terms to improve transcription accuracy.
          </p>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto">
          {words.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 px-4">
              <div className="flex items-center justify-center w-12 h-12 rounded-lg bg-muted/60 mb-4">
                <BookOpen
                  className="w-5 h-5 text-muted-foreground/60"
                  strokeWidth={1.5}
                />
              </div>
              <h3 className="text-sm font-medium text-foreground mb-1">
                No words yet
              </h3>
              <p className="text-xs text-muted-foreground text-center max-w-[260px] leading-relaxed">
                Start building your custom vocabulary for better transcription
                accuracy
              </p>
            </div>
          ) : (
            <div className="flex flex-wrap gap-2">
              {words.map(word => (
                <div
                  key={word.id}
                  className="group relative inline-flex items-center rounded-md border border-border bg-card text-sm text-foreground hover:border-border/80 transition-colors"
                >
                  <span className="font-medium px-3 py-1.5">{word.word}</span>
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <button className="flex items-center justify-center h-full px-2 border-l border-border opacity-0 group-hover:opacity-100 hover:bg-accent/50 transition-all rounded-r-md focus:opacity-100 focus:outline-none">
                        <MoreHorizontal className="h-3.5 w-3.5 text-muted-foreground" />
                      </button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-32">
                      <DropdownMenuItem onClick={() => handleEdit(word)}>
                        <Pencil className="h-3.5 w-3.5" />
                        Edit
                      </DropdownMenuItem>
                      <DropdownMenuItem
                        variant="destructive"
                        onClick={() => handleDelete(word.id)}
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                        Delete
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Bottom Banner */}
        <VocabularySupportBanner className="shrink-0 mt-6" />
      </div>

      <VocabularyDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        editingWord={editingWord}
      />
    </>
  )
}
