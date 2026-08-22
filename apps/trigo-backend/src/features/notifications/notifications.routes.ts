import { Router } from 'express';
import { NotificationsController } from './notifications.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { authorize } from '../../shared/middleware/authorize';
import { validate } from '../../shared/middleware/validate';
import { registerDeviceSchema, broadcastSchema } from './notifications.schema';
import { USER_ROLE } from '../../shared/constants/roles';

const router = Router();
const controller = new NotificationsController();

router.use(authenticate);

router.get('/', controller.getNotifications);
router.patch('/:id/read', controller.markAsRead);
router.post('/register-device', validate(registerDeviceSchema), controller.registerDevice);
router.post('/broadcast', authorize(USER_ROLE.ADMIN), validate(broadcastSchema), controller.broadcast);

export default router;
