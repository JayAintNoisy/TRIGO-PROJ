import { promises as fs } from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { AppError } from '../../shared/errors/app-error';
import { ERROR_CODES } from '../../shared/errors/error-codes';

/** Storage buckets, one folder per concern — add new concerns here */
export const UPLOAD_FOLDERS = ['driver-documents'] as const;

export type UploadFolder = (typeof UPLOAD_FOLDERS)[number];

const MIME_EXTENSIONS: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'application/pdf': '.pdf',
};

export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

const FILENAME_PATTERN =
  /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}\.(jpg|png|webp|pdf)$/i;

/** Resolved once so every request targets the same directory regardless of cwd */
export const uploadsRoot = path.resolve(process.cwd(), 'uploads');

export async function ensureUploadsRoot(): Promise<void> {
  await fs.mkdir(uploadsRoot, { recursive: true });
}

function assertFolder(folder: string): asserts folder is UploadFolder {
  if (!UPLOAD_FOLDERS.includes(folder as UploadFolder)) {
    throw new AppError(
      `Unknown upload folder. Allowed: ${UPLOAD_FOLDERS.join(', ')}`,
      400,
      ERROR_CODES.VALIDATION_ERROR,
    );
  }
}

function assertFilename(filename: string): void {
  // Only files this service generated may be fetched
  if (!FILENAME_PATTERN.test(filename)) {
    throw new AppError('Invalid file name', 400, ERROR_CODES.VALIDATION_ERROR);
  }
}

export interface StoredUpload {
  url: string;
  fileName: string;
  mimeType: string;
}

export async function saveUpload(
  folder: string,
  mimetype: string,
  data: Buffer,
): Promise<StoredUpload> {
  assertFolder(folder);
  const extension = MIME_EXTENSIONS[mimetype];
  if (!extension) {
    throw new AppError(
      'Unsupported file type. Allowed: JPG, PNG, WEBP, PDF',
      400,
      ERROR_CODES.VALIDATION_ERROR,
    );
  }

  const fileName = `${uuidv4()}${extension}`;
  const folderDir = path.join(uploadsRoot, folder);
  await fs.mkdir(folderDir, { recursive: true });
  await fs.writeFile(path.join(folderDir, fileName), data);

  return {
    url: `/uploads/${folder}/${fileName}`,
    fileName,
    mimeType: mimetype,
  };
}

export async function readUpload(
  folder: string,
  filename: string,
): Promise<{ absolutePath: string; mimeType: string }> {
  assertFolder(folder);
  assertFilename(filename);

  const extension = filename.split('.').pop()!.toLowerCase();
  const mimeType =
    Object.entries(MIME_EXTENSIONS).find(([, ext]) => ext === `.${extension}`)?.[0] ??
    'application/octet-stream';

  return {
    absolutePath: path.join(uploadsRoot, folder, filename),
    mimeType,
  };
}
