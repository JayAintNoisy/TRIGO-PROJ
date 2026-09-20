import { RIDE_STATUS } from '../../shared/constants/ride-status';

export interface RideEntity {
  id: string;
  customerId: string;
  driverId?: string | null;
  municipalityId: string;
  pickupLat: number;
  pickupLng: number;
  pickupAddress?: string | null;
  dropoffLat: number;
  dropoffLng: number;
  dropoffAddress?: string | null;
  status: RIDE_STATUS;
  fareEstimate: number;
  fareFinal?: number | null;
  distanceKm: number;
  cancellationReason?: string | null;
  cancelledBy?: 'customer' | 'driver' | null;
  cancellationFee?: number | null;
  startedAt?: Date | null;
  completedAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
  // Joined details
  customerName?: string;
  customerPhone?: string;
  driverName?: string;
  driverPhone?: string;
  tricyclePlateNumber?: string;
  municipalityName?: string;
  /// Last broadcast position of the assigned driver, joined from
  /// driver_profiles. Null until a driver is assigned or before their first
  /// GPS broadcast. Lets the passenger track the driver live.
  driverLat?: number | null;
  driverLng?: number | null;
}

export interface CreateRideInput {
  municipalityId: string;
  pickupLat: number;
  pickupLng: number;
  pickupAddress?: string;
  dropoffLat: number;
  dropoffLng: number;
  dropoffAddress?: string;
}

export interface RateRideInput {
  rating: number; // 1 to 5
  comment?: string;
}
