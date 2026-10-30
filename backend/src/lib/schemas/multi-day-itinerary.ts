import { z } from 'zod';
import { ExpenseSummarySchema, ItineraryModelSchema, ItineraryStopSchema } from './itinerary';

// Single day object inside raw multi-day AI output
export const RawMultiDayDaySchema = z.object({
  dayNumber: z.number().int().positive(),
  date: z.string().min(1),
  aiSummary: z.string().optional(),
  expenseSummary: ExpenseSummarySchema.optional(),
  stops: z.array(ItineraryStopSchema),
}).strip();

export type RawMultiDayDay = z.infer<typeof RawMultiDayDaySchema>;

// Raw output from AI generation for multi-day itinerary
export const RawMultiDayAIOutputSchema = z.object({
  overallSummary: z.string().optional(),
  weatherSummary: z.string().nullable().optional(),
  whatToCarry: z.array(z.string()).default([]),
  overallExpenseSummary: ExpenseSummarySchema.optional(),
  days: z.array(RawMultiDayDaySchema),
}).strip();

export type RawMultiDayAIOutput = z.infer<typeof RawMultiDayAIOutputSchema>;

// Full Multi-day Itinerary Model matching Flutter MultiDayItineraryModel
export const MultiDayItineraryModelSchema = z.object({
  id: z.string().min(1),
  userId: z.string(),
  city: z.string().min(1),
  startDate: z.string().min(1),
  endDate: z.string().min(1),
  numberOfDays: z.number().int().positive(),
  dailyStartTime: z.string().min(1),
  dailyEndTime: z.string().min(1),
  interests: z.array(z.string()).default([]),
  travelMode: z.string().default('driving'),
  pace: z.string().default('moderate'),
  days: z.array(ItineraryModelSchema).default([]),
  overallSummary: z.string().nullable().optional(),
  weatherSummary: z.string().nullable().optional(),
  whatToCarry: z.array(z.string()).default([]),
  isSaved: z.boolean().default(false),
  createdAt: z.string().optional(),
  age: z.number().int().nullable().optional(),
  travelers: z.number().int().nullable().optional(),
  budget: z.number().int().nullable().optional(),
  currency: z.string().default('INR'),
  estimatedTotalCost: z.number().int().nullable().optional(),
  remainingBudget: z.number().int().nullable().optional(),
  overallExpenseSummary: ExpenseSummarySchema.nullable().optional(),
}).strip();

export type MultiDayItineraryModel = z.infer<typeof MultiDayItineraryModelSchema>;

