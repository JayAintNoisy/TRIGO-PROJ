import { z } from 'zod';

export const sendMessageSchema = z.object({
  body: z.object({
    body: z.string().trim().min(1, 'Message cannot be empty').max(500, 'Message is too long'),
  }),
});
