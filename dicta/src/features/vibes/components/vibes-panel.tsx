import { Plus } from 'lucide-react'
import { useState } from 'react'

import appleMailIcon from '@/assets/apps/apple-mail.svg'
import appleNotesIcon from '@/assets/apps/apple-notes.svg'
import chatgptIcon from '@/assets/apps/chatgpt.svg'
import gmailIcon from '@/assets/apps/gmail.svg'
import googleDocsIcon from '@/assets/apps/google-docs.svg'
import jiraIcon from '@/assets/apps/jira.svg'
import messagesIcon from '@/assets/apps/messages.svg'
import teamsIcon from '@/assets/apps/microsoft-teams.svg'
import outlookIcon from '@/assets/apps/outlook.svg'
import slackIcon from '@/assets/apps/slack.svg'
import superhumanIcon from '@/assets/apps/superhuman.svg'
import telegramIcon from '@/assets/apps/telegram.svg'
import vscodeIcon from '@/assets/apps/vscode.svg'
import whatsappIcon from '@/assets/apps/whatsapp.svg'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { cn } from '@/lib/cn'

import { useVibesStore } from '../store'
import { AppAvatarGroup } from './app-avatar-group'
import { DefaultPreview } from './preview/default-preview'
import { EmailPreview } from './preview/email-preview'
import { MessengerPreview } from './preview/messenger-preview'
import { SlackPreview } from './preview/slack-preview'
import { VibeCard } from './vibe-card'
import { VibeDialog } from './vibe-dialog'

import type { Vibe, VibeCategory } from '../types'

const CATEGORIES: readonly VibeCategory[] = [
  'personal',
  'work',
  'email',
  'other',
] as const

const CATEGORY_CONFIG: Record<
  VibeCategory,
  {
    label: string
    info?: { title: string; subtitle: string }
    icons?: string[]
  }
> = {
  personal: {
    label: 'Personal',
    info: {
      title: 'For personal messengers',
      subtitle: 'iMessage, WhatsApp, Telegram and more',
    },
    icons: [messagesIcon, whatsappIcon, telegramIcon],
  },
  work: {
    label: 'Work',
    info: {
      title: 'For work communication',
      subtitle: 'Slack, Teams, and professional tools',
    },
    icons: [slackIcon, jiraIcon, teamsIcon],
  },
  email: {
    label: 'Email',
    info: {
      title: 'For email clients',
      subtitle: 'Gmail, Outlook, Superhuman and more',
    },
    icons: [gmailIcon, outlookIcon, superhumanIcon, appleMailIcon],
  },
  other: {
    label: 'Other',
    info: {
      title: 'For other apps',
      subtitle: 'Docs, Notes, Code editors and more',
    },
    icons: [googleDocsIcon, vscodeIcon, appleNotesIcon, chatgptIcon],
  },
}

const getPreviewComponent = (category: VibeCategory, text: string) => {
  const previews = {
    personal: <MessengerPreview text={text} />,
    work: <SlackPreview text={text} />,
    email: <EmailPreview text={text} />,
    other: <DefaultPreview text={text} />,
  }
  return previews[category]
}

function CategoryInfoBanner({ category }: { category: VibeCategory }) {
  const config = CATEGORY_CONFIG[category]
  const { info, icons } = config

  if (!info && !icons) return null

  return (
    <div className="relative rounded-lg border border-border/50 bg-card/50 backdrop-blur-sm overflow-hidden group hover:border-border/80 transition-colors">
      {/* Gradient accent line at top - matching KPI cards */}
      <div
        className="absolute top-0 left-0 right-0 h-[2px] opacity-60"
        style={{
          background: `linear-gradient(90deg, #4ade8000, #4ade80, #4ade8000)`,
        }}
      />

      <div className="px-3.5 py-2.5 flex items-center gap-3">
        {icons && <AppAvatarGroup icons={icons} />}
        <div className="flex-1 min-w-0">
          <h3 className="text-[12px] font-medium text-foreground">
            {info?.title}
          </h3>
          <p className="text-[10px] text-muted-foreground mt-0.5">
            {info?.subtitle}
          </p>
        </div>
      </div>
    </div>
  )
}

function AddVibeButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        'group relative rounded-xl border border-dashed transition-all',
        'border-border/40 hover:border-primary/40',
        'flex flex-col items-center justify-center min-h-[200px]',
        'bg-transparent hover:bg-primary/[0.02]'
      )}
    >
      <div
        className={cn(
          'w-10 h-10 rounded-full flex items-center justify-center mb-2 transition-all',
          'bg-muted/30 group-hover:bg-primary/10 group-hover:scale-105'
        )}
      >
        <Plus className="w-4 h-4 text-muted-foreground group-hover:text-primary transition-colors" />
      </div>
      <p className="text-xs font-medium text-muted-foreground group-hover:text-foreground transition-colors">
        Create Custom Vibe
      </p>
    </button>
  )
}

export function VibesPanel() {
  const { vibes, selectedVibes, selectVibeForCategory, deleteVibe } =
    useVibesStore()

  const [activeTab, setActiveTab] = useState<VibeCategory>('personal')
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editingVibe, setEditingVibe] = useState<
    | (Pick<Vibe, 'id' | 'name' | 'description' | 'prompt'> & {
        example?: string
      })
    | null
  >(null)
  const [creatingForCategory, setCreatingForCategory] =
    useState<VibeCategory | null>(null)

  const handleEdit = (vibe: Vibe) => {
    setEditingVibe({
      id: vibe.id,
      name: vibe.name,
      description: vibe.description,
      prompt: vibe.prompt,
      example: vibe.example,
    })
    setCreatingForCategory(null)
    setDialogOpen(true)
  }

  const handleCreate = (category: VibeCategory) => {
    setEditingVibe(null)
    setCreatingForCategory(category)
    setDialogOpen(true)
  }

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this vibe?')) return
    try {
      await deleteVibe(id)
    } catch (error) {
      console.error('Failed to delete vibe:', error)
    }
  }

  const handleSelect = async (category: VibeCategory, vibeId: string) => {
    await selectVibeForCategory(category, vibeId)
  }

  const getCategoryVibes = (category: VibeCategory) =>
    vibes.filter(s => s.category === category)

  return (
    <>
      <Tabs
        value={activeTab}
        onValueChange={v => setActiveTab(v as VibeCategory)}
        className="gap-3"
      >
        <TabsList className="bg-transparent border-b border-border/40 rounded-none p-0 h-auto gap-0">
          {CATEGORIES.map(category => {
            const count = vibes.filter(v => v.category === category).length
            const isActive = activeTab === category
            return (
              <TabsTrigger
                key={category}
                value={category}
                className={cn(
                  'relative rounded-none border-b-2 border-transparent px-4 py-2.5',
                  'text-[13px] font-medium transition-colors',
                  'data-[state=active]:border-primary data-[state=active]:text-foreground',
                  'data-[state=inactive]:text-muted-foreground hover:text-foreground',
                  'bg-transparent data-[state=active]:bg-transparent',
                  'shadow-none data-[state=active]:shadow-none'
                )}
              >
                {CATEGORY_CONFIG[category].label}
                <span
                  className={cn(
                    'ml-1.5 text-[11px] tabular-nums',
                    isActive ? 'text-primary' : 'text-muted-foreground/60'
                  )}
                >
                  {count}
                </span>
              </TabsTrigger>
            )
          })}
        </TabsList>

        {CATEGORIES.map(category => {
          const categoryVibes = getCategoryVibes(category)

          return (
            <TabsContent
              key={category}
              value={category}
              className="space-y-4 mt-4"
            >
              <CategoryInfoBanner category={category} />

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                {categoryVibes.map(vibe => (
                  <VibeCard
                    key={vibe.id}
                    id={vibe.id}
                    name={vibe.name}
                    description={vibe.description}
                    isSelected={selectedVibes[category] === vibe.id}
                    isDefault={vibe.isDefault}
                    showActions={category === 'other'}
                    preview={getPreviewComponent(
                      category,
                      vibe.example || 'No example provided'
                    )}
                    onSelect={() => handleSelect(category, vibe.id)}
                    onEdit={() => handleEdit(vibe)}
                    onDelete={() => handleDelete(vibe.id)}
                  />
                ))}

                {category === 'other' && (
                  <AddVibeButton onClick={() => handleCreate(category)} />
                )}
              </div>
            </TabsContent>
          )
        })}
      </Tabs>

      <VibeDialog
        open={dialogOpen}
        onOpenChange={setDialogOpen}
        editingVibe={editingVibe}
        category={creatingForCategory}
      />
    </>
  )
}
