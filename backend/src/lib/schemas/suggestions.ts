import { z } from 'zod';

export const PlaceHistorySchema = z.object({
  history: z.string().min(1),
}).strip();

export type PlaceHistory = z.infer<typeof PlaceHistorySchema>;

export const CarrySuggestionsSchema = z.object({
  suggestions: z.array(z.string().min(1)).min(1).max(10),
}).strip();

export type CarrySuggestions = z.infer<typeof CarrySuggestionsSchema>;

