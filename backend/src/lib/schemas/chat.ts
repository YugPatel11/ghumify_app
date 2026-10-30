import { z } from 'zod';
import { ItineraryModelSchema } from './itinerary';
import { MultiDayItineraryModelSchema } from './multi-day-itinerary';

export const ChatMessageModelSchema = z.object({
  id: z.string().min(1),
  role: z.enum(['user', 'assistant']),
  content: z.string(),
  timestamp: z.string().optional(),
  updatedItinerary: z.union([
    ItineraryModelSchema,
    MultiDayItineraryModelSchema,
    z.record(z.string(), z.any()),
  ]).nullable().optional(),
}).strip();

export type ChatMessageModel = z.infer<typeof ChatMessageModelSchema>;

export const ChatResponseSchema = z.object({
  chatMessage: z.string(),
  updatedItinerary: z.union([
    ItineraryModelSchema,
    MultiDayItineraryModelSchema,
    z.record(z.string(), z.any()),
  ]).nullable().optional(),
}).strip();

export type ChatResponse = z.infer<typeof ChatResponseSchema>;

