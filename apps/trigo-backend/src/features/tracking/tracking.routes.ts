import { Router } from 'express';
import { TrackingController } from './tracking.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { authorize } from '../../shared/middleware/authorize';
import { validate } from '../../shared/middleware/validate';
import { recordLocationSchema, activeDriversQuerySchema } from './tracking.schema';
import { USER_ROLE } from '../../shared/constants/roles';

const router = Router();
const controller = new TrackingController();

router.post('/location', authenticate, authorize(USER_ROLE.DRIVER), validate(recordLocationSchema), controller.recordLocation);
router.get('/active', authenticate, authorize(USER_ROLE.ADMIN), validate(activeDriversQuerySchema), controller.getActiveDrivers);

export default router;
