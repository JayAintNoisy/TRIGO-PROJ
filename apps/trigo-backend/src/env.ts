import { z } from 'zod';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().transform((val) => parseInt(val, 10)).default('4000'),
  JWT_SECRET: z.string().default('trigo-jwt-secret-key-change-in-production'),
  JWT_REFRESH_SECRET: z.string().default('trigo-jwt-refresh-secret-key-change-in-production'),
  JWT_EXPIRES_IN: z.string().default('1d'),
  DATABASE_URL: z.string().optional().default('postgres://postgres:postgres@localhost:5432/trigo_db'),
  CORS_ORIGIN: z.string().default('*'),
});

const parseEnv = () => {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    console.error('Invalid environment variables:', result.error.flatten().fieldErrors);
    throw new Error('Environment variable validation failed');
  }
  return result.data;
};

export const env = parseEnv();
