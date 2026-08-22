import express from 'express';
import cors from 'cors';
import { env } from './env';
import { accessLogger } from './shared/logging/access-logger';
import { errorHandler } from './shared/errors/error-handler';

import authRoutes from './features/auth/auth.routes';
import usersRoutes from './features/users/users.routes';
import municipalitiesRoutes from './features/municipalities/municipalities.routes';
import driversRoutes from './features/drivers/drivers.routes';
import ridesRoutes from './features/rides/rides.routes';
import trackingRoutes from './features/tracking/tracking.routes';
import paymentsRoutes from './features/payments/payments.routes';
import notificationsRoutes from './features/notifications/notifications.routes';
import uploadsRoutes from './features/uploads/uploads.routes';

const app = express();

app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }));
app.use(express.json());
app.use(accessLogger);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    service: 'trigo-backend',
    timestamp: new Date().toISOString(),
  });
});

// Feature API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/municipalities', municipalitiesRoutes);
app.use('/api/drivers', driversRoutes);
app.use('/api/rides', ridesRoutes);
app.use('/api/tracking', trackingRoutes);
app.use('/api/payments', paymentsRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/uploads', uploadsRoutes);

// Centralized error handling
app.use(errorHandler);

export default app;
