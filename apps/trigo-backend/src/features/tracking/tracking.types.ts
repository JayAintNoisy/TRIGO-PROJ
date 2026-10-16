import { RIDE_STATUS } from '../../shared/constants/ride-status';
import { DRIVER_APPLICATION_STATUS } from '../../shared/constants/roles';

export interface DriverLocationUpdate {
  rideId?: string;
  lat: number;
  lng: number;
  accuracy?: number;
}

/// The trip a driver is on right now, so a dispatcher can see who is carrying a
/// passenger and where they are headed without opening the rides list.
export interface ActiveRideSummary {
  rideId: string;
  status: RIDE_STATUS;
  customerName?: string;
  pickupAddress?: string | null;
  dropoffAddress?: string | null;
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  startedAt?: Date | null;
}

export interface ActiveDriverLocation {
  /// driver_profiles.id
  driverId: string;
  /// users.id — the key rides store as driver_id, for cross-referencing
  driverUserId: string;
  driverName?: string;
  tricyclePlateNumber?: string;
  municipalityId?: string | null;
  municipalityName?: string | null;
  /// Surfaced so a suspended driver who is still broadcasting shows up as
  /// suspended rather than silently vanishing from the fleet map.
  applicationStatus?: DRIVER_APPLICATION_STATUS;
  lat: number;
  lng: number;
  isOnline: boolean;
  /// Last GPS fix or online toggle: driver_profiles.updated_at, the same stamp
  /// the stale-presence sweeper uses.
  lastSeenAt: Date;
  activeRide?: ActiveRideSummary | null;
}

export interface RideTrackingPoint {
  lat: number;
  lng: number;
  accuracy?: number | null;
  timestamp: Date;
}
