import { z } from 'zod';

export const ItineraryStopSchema = z.object({
  name: z.string().min(1),
  type: z.enum(['place', 'food', 'market', 'travel', 'break']).or(z.string()).default('place'),
  placeId: z.string().nullable().optional(),
  startTime: z.string().min(1),
  endTime: z.string().min(1),
  durationMinutes: z.number().int().nonnegative(),
  latitude: z.number().nullable().optional(),
  longitude: z.number().nullable().optional(),
  description: z.string().default(''),
  photoUrl: z.string().nullable().optional(),
  travelMode: z.string().nullable().optional(),
  travelMinutes: z.number().int().nullable().optional(),
  tips: z.array(z.string()).default([]),
  estimatedCost: z.number().int().nullable().optional(),
}).strip();

export type ItineraryStop = z.infer<typeof ItineraryStopSchema>;

export const ExpenseSummarySchema = z.object({
  food: z.number().default(0),
  transport: z.number().default(0),
  activities: z.number().default(0),
  other: z.number().default(0),
  total: z.number().default(0),
}).strip();

export type ExpenseSummary = z.infer<typeof ExpenseSummarySchema>;

// Raw output from AI generation for single-day itinerary
export const RawSingleDayAIOutputSchema = z.object({
  aiSummary: z.string().optional(),
  stops: z.array(ItineraryStopSchema),
  expenseSummary: ExpenseSummarySchema.optional(),
  whatToCarry: z.array(z.string()).default([]),
  weatherSummary: z.string().nullable().optional(),
}).strip();

export type RawSingleDayAIOutput = z.infer<typeof RawSingleDayAIOutputSchema>;

// Full Single-day Itinerary Model matching Flutter ItineraryModel
export const ItineraryModelSchema = z.object({
  id: z.string().min(1),
  userId: z.string(),
  city: z.string().min(1),
  date: z.string().min(1),
  startTime: z.string().min(1),
  endTime: z.string().min(1),
  totalDurationMinutes: z.number().int().default(0),
  interests: z.array(z.string()).default([]),
  travelMode: z.string().default('driving'),
  pace: z.string().default('moderate'),
  stops: z.array(ItineraryStopSchema).default([]),
  weatherSummary: z.string().nullable().optional(),
  whatToCarry: z.array(z.string()).default([]),
  aiSummary: z.string().nullable().optional(),
  isSaved: z.boolean().default(false),
  dayNumber: z.number().int().default(1),
  createdAt: z.string().optional(),
  age: z.number().int().nullable().optional(),
  travelers: z.number().int().nullable().optional(),
  budget: z.number().int().nullable().optional(),
  currency: z.string().default('INR'),
  estimatedTotalCost: z.number().int().nullable().optional(),
  remainingBudget: z.number().int().nullable().optional(),
  expenseSummary: ExpenseSummarySchema.nullable().optional(),
}).strip();

export type ItineraryModel = z.infer<typeof ItineraryModelSchema>;

