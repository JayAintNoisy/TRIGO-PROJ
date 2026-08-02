import { Router } from 'express';
import { MunicipalitiesController } from './municipalities.controller';
import { authenticate } from '../../shared/middleware/authenticate';
import { authorize } from '../../shared/middleware/authorize';
import { validate } from '../../shared/middleware/validate';
import { createMunicipalitySchema, updateFareConfigSchema } from './municipalities.schema';
import { USER_ROLE } from '../../shared/constants/roles';

const router = Router();
const controller = new MunicipalitiesController();

router.get('/', controller.getAll);
router.get('/:id', controller.getById);
router.post('/', authenticate, authorize(USER_ROLE.ADMIN), validate(createMunicipalitySchema), controller.create);
router.patch('/:id/fare-config', authenticate, authorize(USER_ROLE.ADMIN), validate(updateFareConfigSchema), controller.updateFareConfig);

export default router;
