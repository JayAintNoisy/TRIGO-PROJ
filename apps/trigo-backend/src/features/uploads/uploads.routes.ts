import { Router } from 'express';
import multer from 'multer';
import { authenticate } from '../../shared/middleware/authenticate';
import { validate } from '../../shared/middleware/validate';
import { z } from 'zod';
import { UPLOAD_FOLDERS, MAX_UPLOAD_BYTES } from './uploads.service';
import { UploadsController } from './uploads.controller';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 1, fileSize: MAX_UPLOAD_BYTES },
});

const uploadSchema = z.object({
  body: z.object({
    folder: z.enum(UPLOAD_FOLDERS).optional(),
  }),
});

const router = Router();
const controller = new UploadsController();

router.post('/', authenticate, upload.single('file'), validate(uploadSchema), controller.uploadDocument);
router.get('/:folder/:filename', authenticate, controller.fetchDocument);

// Multer-specific failures (e.g. size limit) surface as plain 400s
router.use((error: any, req: any, res: any, next: any) => {
  if (error instanceof multer.MulterError) {
    const message =
      error.code === 'LIMIT_FILE_SIZE'
        ? 'File exceeds the 5 MB limit'
        : `Upload rejected: ${error.code}`;
    return res
      .status(400)
      .json({ success: false, error: { message, code: 'VALIDATION_ERROR' } });
  }
  return next(error);
});

export default router;
