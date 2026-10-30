import { z } from 'zod';

export const PlaceSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  city: z.string(),
  state: z.string().default(''),
  category: z.string(),
  description: z.string().default(''),
  history: z.string().default(''),
  latitude: z.number(),
  longitude: z.number(),
  address: z.string().nullable().optional(),
  openingHours: z.record(z.string(), z.string()).default({}),
  photoUrls: z.array(z.string()).default([]),
  thumbnailUrl: z.string().nullable().optional(),
  avgVisitDurationMinutes: z.number().default(60),
  rating: z.number().nullable().optional(),
  reviewCount: z.number().int().nullable().optional(),
  entryFee: z.number().nullable().optional(),
  tags: z.array(z.string()).default([]),
  nearbyPlaceIds: z.array(z.string()).default([]),
  googlePlaceId: z.string().nullable().optional(),
  isHiddenGem: z.boolean().default(false),
  specialNote: z.string().nullable().optional(),
  createdAt: z.string().optional(),
}).strip();

export type Place = z.infer<typeof PlaceSchema>;

