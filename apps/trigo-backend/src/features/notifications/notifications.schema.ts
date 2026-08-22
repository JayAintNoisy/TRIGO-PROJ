import { z } from 'zod';

export const registerDeviceSchema = z.object({
  body: z.object({
    fcmToken: z.string().min(10, 'FCM token is required'),
    platform: z.enum(['android', 'ios', 'web']),
  }),
});

export const broadcastSchema = z.object({
  body: z.object({
    title: z.string().min(1, 'Title required').max(255),
    body: z.string().min(1, 'Message body required'),
    audience: z.enum(['all', 'drivers', 'customers']).default('all'),
  }),
});
