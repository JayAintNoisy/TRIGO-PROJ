import { Router } from 'express';
import { RidesController } from './rides.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { validate } from '../../shared/middleware/validate';
import { createRideSchema, cancelRideSchema, rateRideSchema } from './rides.schema';

const router = Router();
const controller = new RidesController();

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

export default router;
