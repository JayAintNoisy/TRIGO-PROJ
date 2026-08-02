import app from './app';
import { env } from './env';
import { migrate } from './shared/database/migrate';
import { logger } from './shared/logging/logger';

const startServer = async () => {
  try {
    await migrate();
    app.listen(env.PORT, () => {
      logger.info(`🚀 TriGo Backend Service running on port ${env.PORT} [env: ${env.NODE_ENV}]`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
