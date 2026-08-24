export interface MunicipalityEntity {
  id: string;
  name: string;
  province?: string | null;
  centerLat: number;
  centerLng: number;
  radiusKm: number;
  baseFare: number;
  perKmRate: number;
  exclusiveMultiplier: number;
  minFare: number;
  nightSurcharge: number;
  maxPassengers: number;
  boundaryGeojson?: any;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateMunicipalityInput {
  name: string;
  province?: string;
  centerLat: number;
  centerLng: number;
  radiusKm: number;
  baseFare?: number;
  perKmRate?: number;
  boundaryGeojson?: any;
}

export interface UpdateFareConfigInput {
  baseFare?: number;
  perKmRate?: number;
  exclusiveMultiplier?: number;
  minFare?: number;
  nightSurcharge?: number;
  maxPassengers?: number;
}

export interface UpdateMunicipalityInput {
  name?: string;
  province?: string | null;
  centerLat?: number;
  centerLng?: number;
  radiusKm?: number;
  baseFare?: number;
  perKmRate?: number;
  boundaryGeojson?: any;
  isActive?: boolean;
}
