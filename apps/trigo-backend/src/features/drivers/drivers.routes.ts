import { Router } from 'express';
import { DriversController } from './drivers.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { authorize } from '../../shared/middleware/authorize';
import { validate } from '../../shared/middleware/validate';
import { applyDriverSchema, rejectDriverSchema, updateStatusSchema, toggleOnlineSchema } from './drivers.schema';
import { USER_ROLE } from '../../shared/constants/roles';

const router = Router();
const controller = new DriversController();

router.post('/apply', authenticate, validate(applyDriverSchema), controller.apply);
router.get('/me', authenticate, controller.getOwnProfile);
router.get('/online', authenticate, controller.getOnlineDrivers);
router.patch('/online-status', authenticate, validate(toggleOnlineSchema), controller.toggleOnlineStatus);

// Admin routes
router.get('/applications', authenticate, authorize(USER_ROLE.ADMIN), controller.getApplications);
router.get('/applications/:id', authenticate, authorize(USER_ROLE.ADMIN), controller.getApplicationById);
router.patch('/applications/:id/review', authenticate, authorize(USER_ROLE.ADMIN), controller.startReview);
router.patch('/applications/:id/approve', authenticate, authorize(USER_ROLE.ADMIN), controller.approveApplication);
router.patch('/applications/:id/reject', authenticate, authorize(USER_ROLE.ADMIN), validate(rejectDriverSchema), controller.rejectApplication);

router.get('/', authenticate, authorize(USER_ROLE.ADMIN), controller.getAllDrivers);
router.get('/:id', authenticate, authorize(USER_ROLE.ADMIN), controller.getDriverById);
router.patch('/:id/status', authenticate, authorize(USER_ROLE.ADMIN), validate(updateStatusSchema), controller.updateDriverStatus);

export default router;
