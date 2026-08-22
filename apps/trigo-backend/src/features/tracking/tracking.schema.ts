import { z } from 'zod';

export const recordLocationSchema = z.object({
  body: z.object({
    rideId: z.string().uuid('rideId must be a valid UUID').optional(),
    lat: z.number().min(-90, 'Invalid latitude').max(90, 'Invalid latitude'),
    lng: z.number().min(-180, 'Invalid longitude').max(180, 'Invalid longitude'),
    accuracy: z.number().min(0).optional(),
  }),
});
