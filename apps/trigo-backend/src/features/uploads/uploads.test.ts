import { describe, it, expect } from 'vitest';
import { MAX_UPLOAD_BYTES, readUpload, saveUpload } from './uploads.service';

describe('UploadsService', () => {
  it('stores a PNG and returns a relative url in the concern folder', async () => {
    const stored = await saveUpload(
      'driver-documents',
      'image/png',
      Buffer.from([0x89, 0x50, 0x4e, 0x47]),
    );
    expect(stored.url).toMatch(/^\/uploads\/driver-documents\/[a-f0-9-]{36}\.png$/);
    expect(stored.mimeType).toBe('image/png');
  });

  it('rejects unsupported file types', async () => {
    await expect(saveUpload('driver-documents', 'application/zip', Buffer.from('zip'))).rejects.toThrow(
      'Unsupported file type',
    );
  });

  it('rejects unknown folders', async () => {
    await expect(saveUpload('../escape', 'image/png', Buffer.from('x'))).rejects.toThrow(
      'Unknown upload folder',
    );
  });

  it('refuses to fetch files it did not generate', async () => {
    await expect(readUpload('driver-documents', '..%2F..%2F.env')).rejects.toThrow('Invalid file name');
  });

  it('round-trips a saved file through the reader', async () => {
    const stored = await saveUpload('driver-documents', 'application/pdf', Buffer.from('%PDF-1.4'));
    const read = await readUpload('driver-documents', stored.fileName);
    expect(read.mimeType).toBe('application/pdf');
    expect(read.absolutePath).toContain('driver-documents');
  });

  it('caps uploads at five megabytes', () => {
    expect(MAX_UPLOAD_BYTES).toBe(5 * 1024 * 1024);
  });
});
