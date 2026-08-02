export interface MunicipalityEntity {
  id: string;
  name: string;
  province?: string | null;
  centerLat: number;
  centerLng: number;
  radiusKm: number;
  baseFare: number;
  perKmRate: number;
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
}

export interface UpdateFareConfigInput {
  baseFare: number;
  perKmRate: number;
}
