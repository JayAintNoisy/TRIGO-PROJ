import { describe, it, expect } from 'vitest';
import { calculateFare } from './calculate-fare';

describe('calculateFare', () => {
  it('correctly calculates fare based on base fare, distance, and per-km rate', () => {
    // 0km distance (same coordinates)
    const resultSame = calculateFare({
      pickupLat: 14.5995,
      pickupLng: 120.9842,
      dropoffLat: 14.5995,
      dropoffLng: 120.9842,
      baseFare: 30,
      perKmRate: 10,
    });

    expect(resultSame.distanceKm).toBe(0);
    expect(resultSame.totalFare).toBe(30);

    // ~2km distance
    const result2km = calculateFare({
      pickupLat: 14.5995,
      pickupLng: 120.9842,
      dropoffLat: 14.6100,
      dropoffLng: 120.9900,
      baseFare: 30,
      perKmRate: 10,
    });

    expect(result2km.distanceKm).toBeGreaterThan(1);
    expect(result2km.totalFare).toBeGreaterThan(40);
  });
});
