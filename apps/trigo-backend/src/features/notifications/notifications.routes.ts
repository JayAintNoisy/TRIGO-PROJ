import { Router } from 'express';
import { NotificationsController } from './notifications.controller';
import { authenticate } from '../../shared/middleware/authenticate';

const router = Router();
const controller = new NotificationsController();

router.use(authenticate);

router.get('/', controller.getNotifications);
router.patch('/:id/read', controller.markAsRead);
router.post('/register-device', controller.registerDevice);

export default router;
