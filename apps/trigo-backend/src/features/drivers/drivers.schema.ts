import { z } from 'zod';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';

export const applyDriverSchema = z.object({
  body: z.object({
    municipalityId: z.string().min(1, 'Municipality ID required'),
    licenseNumber: z.string().min(3, 'License number required'),
    tricyclePlateNumber: z.string().min(3, 'Tricycle plate number required'),
    tricycleModel: z.string().optional(),
    documents: z.array(
      z.object({
        documentType: z.string().min(1),
        documentUrl: z.string().url('Must be a valid document URL'),
      })
    ).min(1, 'At least one verification document is required'),
  }),
});

export const rejectDriverSchema = z.object({
  body: z.object({
    reason: z.string().min(3, 'Rejection reason is required'),
  }),
});

export const updateStatusSchema = z.object({
  body: z.object({
    status: z.nativeEnum(DRIVER_APPLICATION_STATUS),
  }),
});

export const toggleOnlineSchema = z.object({
  body: z.object({
    isOnline: z.boolean(),
  }),
});
