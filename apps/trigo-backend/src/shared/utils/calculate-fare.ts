import { calculateDistanceKm } from './calculate-distance';

export interface FareCalculationInput {
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  baseFare: number;
  perKmRate: number;
}

export interface FareCalculationResult {
  distanceKm: number;
  totalFare: number;
}

export const calculateFare = (input: FareCalculationInput): FareCalculationResult => {
  const distanceKm = calculateDistanceKm(
    input.pickupLat,
    input.pickupLng,
    input.dropoffLat,
    input.dropoffLng
  );
  
  // Fare = base_fare + (distance_km * per_km_rate)
  const calculatedFare = input.baseFare + distanceKm * input.perKmRate;
  const totalFare = Math.round(calculatedFare * 100) / 100;

  return {
    distanceKm,
    totalFare,
  };
};
