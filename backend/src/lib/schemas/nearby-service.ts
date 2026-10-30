import { z } from 'zod';

export const NearbyServiceSchema = z.object({
  name: z.string().min(1),
  type: z.enum(['hospital', 'police']).or(z.string()),
  latitude: z.number(),
  longitude: z.number(),
  address: z.string().nullable().optional(),
  distanceKm: z.number().nullable().optional(),
}).strip();

export type NearbyService = z.infer<typeof NearbyServiceSchema>;

