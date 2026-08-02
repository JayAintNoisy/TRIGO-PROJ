import { Pool } from 'pg';
import { env } from '../../env';
import { logger } from '../logging/logger';

export const pool = new Pool({
  connectionString: env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

pool.on('error', (err) => {
  logger.error('Unexpected error on idle PostgreSQL client', err);
});

export const query = async (text: string, params?: any[]) => {
  try {
    return await pool.query(text, params);
  } catch (error) {
    logger.warn(`PostgreSQL query error: ${error instanceof Error ? error.message : error}. Falling back if needed.`);
    throw error;
  }
};
