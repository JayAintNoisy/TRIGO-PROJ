import { Router } from 'express';
import { UsersController } from './users.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { authorize } from '../../shared/middleware/authorize';
import { validate } from '../../shared/middleware/validate';
import { updateProfileSchema } from './users.schema';
import { USER_ROLE } from '../../shared/constants/roles';

const router = Router();
const controller = new UsersController();

router.get('/', authenticate, authorize(USER_ROLE.ADMIN), controller.getAllUsers);
router.get('/:id', authenticate, authorize(USER_ROLE.ADMIN), controller.getUserById);
router.put('/:id', authenticate, validate(updateProfileSchema), controller.updateOwnProfile);

export default router;
