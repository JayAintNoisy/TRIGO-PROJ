import { z } from 'zod';

export const createMunicipalitySchema = z.object({
  body: z.object({
    name: z.string().min(2, 'Municipality name required'),
    province: z.string().optional(),
    centerLat: z.number({ required_error: 'Center latitude required' }),
    centerLng: z.number({ required_error: 'Center longitude required' }),
    radiusKm: z.number().positive('Radius must be positive'),
    baseFare: z.number().nonnegative().optional().default(30.0),
    perKmRate: z.number().nonnegative().optional().default(10.0),
  }),
});

export const updateFareConfigSchema = z.object({
  body: z.object({
    baseFare: z.number().nonnegative('Base fare cannot be negative'),
    perKmRate: z.number().nonnegative('Per km rate cannot be negative'),
  }),
});
