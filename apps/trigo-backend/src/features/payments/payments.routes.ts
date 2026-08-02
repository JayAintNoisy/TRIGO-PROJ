import { Router } from 'express';
import { PaymentsController } from './payments.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { authorize } from '../../shared/middleware/authorize';
import { USER_ROLE } from '../../shared/constants/roles';

const router = Router();
const controller = new PaymentsController();

router.use(authenticate);

router.get('/', authorize(USER_ROLE.ADMIN), controller.getAll);
router.get('/ride/:rideId', controller.getByRideId);
router.get('/:id', authorize(USER_ROLE.ADMIN), controller.getById);

export default router;
