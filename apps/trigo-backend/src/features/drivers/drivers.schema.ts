import { z } from 'zod';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';
import { DRIVER_PAYMENT_METHODS } from '../../shared/constants/payment-status';

// Documents must be files uploaded through POST /api/uploads
const uploadedDocumentPath = z
  .string()
  .regex(
    /^\/uploads\/[a-z0-9-]+\/[a-f0-9-]{36}\.(jpg|png|webp|pdf)$/i,
    'Document must be a path returned by the upload endpoint',
  );

// Payment QR codes must be cropped images uploaded through POST /api/uploads
const uploadedQrPath = z
  .string()
  .regex(
    /^\/uploads\/payment-qr\/[a-f0-9-]{36}\.(jpg|png|webp)$/i,
    'QR code must be a path returned by the upload endpoint',
  );

export const applyDriverSchema = z.object({
  body: z.object({
    municipalityId: z.string().min(1, 'Municipality ID required'),
    licenseNumber: z.string().min(3, 'License number required'),
    tricyclePlateNumber: z.string().min(3, 'Tricycle plate number required'),
    tricycleModel: z.string().optional(),
    documents: z.array(
      z.object({
        documentType: z.string().min(1),
        documentUrl: uploadedDocumentPath,
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

export const updatePaymentMethodSchema = z.object({
  params: z.object({
    method: z.enum(DRIVER_PAYMENT_METHODS),
  }),
  body: z.object({
    isEnabled: z.boolean(),
    qrCodeUrl: uploadedQrPath.optional(),
  }),
});
