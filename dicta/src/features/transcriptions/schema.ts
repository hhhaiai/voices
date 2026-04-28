import { z } from 'zod'

export const sourceTypeSchema = z.enum(['recording', 'upload', 'command'])

export const transcriptionRecordSchema = z.object({
  id: z.string(),
  text: z.string(),
  timestamp: z.number(),
  duration: z.number().optional().nullable(),
  wordCount: z.number(),
  modelId: z.string(),
  provider: z.string(),
  hasAudio: z.boolean().optional().default(false),
  sourceType: sourceTypeSchema.optional().default('recording'),
  originalFilename: z.string().optional().nullable(),
  translatedToEnglish: z.boolean().optional().default(false),
  language: z.string().optional().nullable(),
  // For command mode: the generated content (text field contains the instruction)
  commandResult: z.string().optional().nullable(),
})

export const transcriptionsStoreSchema = z.object({
  transcriptions: z.array(transcriptionRecordSchema),
})

export type SourceType = z.infer<typeof sourceTypeSchema>
export type Transcription = z.infer<typeof transcriptionRecordSchema>
export type Transcriptions = z.infer<typeof transcriptionsStoreSchema>
