import app from './app';
import { env } from './env';
import { migrate } from './shared/database/migrate';
import { logger } from './shared/logging/logger';
import { ensureUploadsRoot } from './features/uploads/uploads.service';
import { DriversService } from './features/drivers/drivers.service';

const driversService = new DriversService();

const startServer = async () => {
  try {
    await migrate();
    await ensureUploadsRoot();

    // Initial sweep on boot
    try {
      const initialSwept = await driversService.sweepStaleDrivers(3);
      if (initialSwept > 0) {
        logger.info(`🧹 Initial cleanup: marked ${initialSwept} stale driver(s) as offline`);
      }
    } catch (err) {
      logger.error('Initial stale driver sweep failed:', err);
    }

    // Periodic sweeper running every 60 seconds
    setInterval(async () => {
      try {
        const swept = await driversService.sweepStaleDrivers(3);
        if (swept > 0) {
          logger.info(`🧹 Swept ${swept} stale driver(s) to offline`);
        }
      } catch (err) {
        logger.error('Periodic stale driver sweep error:', err);
      }
    }, 60 * 1000);

    app.listen(env.PORT, () => {
      logger.info(`🚀 TriGo Backend Service running on port ${env.PORT} [env: ${env.NODE_ENV}]`);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

startServer();
