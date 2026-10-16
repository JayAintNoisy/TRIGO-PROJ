import { Router } from 'express';
import { RidesController } from './rides.controller';
import { MessagingController } from '../messaging/messaging.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { validate } from '../../shared/middleware/validate';
import { createRideSchema, cancelRideSchema, rateRideSchema, setRidePaymentMethodSchema } from './rides.schema';
import { sendMessageSchema } from '../messaging/messaging.schema';

const router = Router();
const controller = new RidesController();
const messagingController = new MessagingController();

router.use(authenticate);

router.post('/', validate(createRideSchema), controller.requestRide);
router.get('/available', controller.listAvailableRides);
router.get('/', controller.listRides);
router.get('/:id', controller.getRideById);
router.get('/:id/tracking', controller.getRideTracking);
router.post('/:id/accept', controller.acceptRide);
router.post('/:id/arrive', controller.arrive);
router.post('/:id/start', controller.startRide);
router.post('/:id/complete', controller.completeRide);
router.post('/:id/cancel', validate(cancelRideSchema), controller.cancelRide);
router.post('/:id/rate', validate(rateRideSchema), controller.rateRide);
// Changing a rating already given, allowed within the edit window.
router.patch('/:id/rating', validate(rateRideSchema), controller.updateRating);
router.patch('/:id/payment-method', validate(setRidePaymentMethodSchema), controller.setPaymentMethod);

// In-app chat between the two participants of a ride
router.get('/:id/messages', messagingController.listMessages);
router.post('/:id/messages', validate(sendMessageSchema), messagingController.sendMessage);
router.patch('/:id/messages/read', messagingController.markRead);

export default router;
