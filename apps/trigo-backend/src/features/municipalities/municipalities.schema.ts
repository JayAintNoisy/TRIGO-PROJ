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
    boundaryGeojson: z.any().optional(),
  }),
});

export const updateFareConfigSchema = z.object({
  body: z.object({
    baseFare: z.number().nonnegative('Base fare cannot be negative').optional(),
    perKmRate: z.number().nonnegative('Per km rate cannot be negative').optional(),
    exclusiveMultiplier: z.number().min(1, 'Multiplier must be at least 1').max(4).optional(),
    minFare: z.number().nonnegative('Minimum fare cannot be negative').optional(),
    nightSurcharge: z.number().nonnegative('Night surcharge cannot be negative').optional(),
    maxPassengers: z.number().int().min(1).max(6).optional(),
  }).refine((data) => Object.keys(data).length > 0, { message: 'At least one fare field must be provided' }),
});

export const updateMunicipalitySchema = z.object({
  body: z.object({
    name: z.string().min(2, 'Municipality name required').optional(),
    province: z.string().nullable().optional(),
    centerLat: z.number().min(-90).max(90).optional(),
    centerLng: z.number().min(-180).max(180).optional(),
    radiusKm: z.number().positive('Radius must be positive').optional(),
    baseFare: z.number().nonnegative('Base fare cannot be negative').optional(),
    perKmRate: z.number().nonnegative('Per km rate cannot be negative').optional(),
    boundaryGeojson: z.any().optional(),
    isActive: z.boolean().optional(),
  }).refine((data) => Object.keys(data).length > 0, { message: 'At least one field must be provided' }),
});
