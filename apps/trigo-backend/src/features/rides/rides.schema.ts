import { z } from 'zod';

export const createRideSchema = z.object({
  body: z.object({
    municipalityId: z.string().min(1, 'Municipality ID required'),
    pickupLat: z.number(),
    pickupLng: z.number(),
    pickupAddress: z.string().optional(),
    dropoffLat: z.number(),
    dropoffLng: z.number(),
    dropoffAddress: z.string().optional(),
  }),
});

export const cancelRideSchema = z.object({
  body: z.object({
    reason: z.string().optional(),
  }),
});

export const rateRideSchema = z.object({
  body: z.object({
    rating: z.number().int().min(1).max(5),
    comment: z.string().optional(),
  }),
});
