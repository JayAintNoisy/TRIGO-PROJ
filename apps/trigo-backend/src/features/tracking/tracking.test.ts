import { describe, it, expect, vi } from 'vitest';
import { TrackingService } from './tracking.service';
import { TrackingRepository } from './tracking.repository';

describe('TrackingService', () => {
  const service = new TrackingService();

  it('records location update for driver', async () => {
    vi.spyOn(TrackingRepository.prototype, 'recordLocation').mockResolvedValue();
    const res = await service.recordLocation('00000000-0000-0000-0000-000000000002', {
      lat: 8.158,
      lng: 125.129,
      accuracy: 5,
    });
    expect(res.success).toBe(true);
  });
});
