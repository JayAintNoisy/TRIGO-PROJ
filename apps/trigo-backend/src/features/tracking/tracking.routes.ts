import { Router } from 'express';
import { TrackingController } from './tracking.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { authorize } from '../../shared/middleware/authorize';
import { USER_ROLE } from '../../shared/constants/roles';

const router = Router();
const controller = new TrackingController();

router.post('/location', authenticate, controller.recordLocation);
router.get('/active', authenticate, authorize(USER_ROLE.ADMIN), controller.getActiveDrivers);

export default router;
