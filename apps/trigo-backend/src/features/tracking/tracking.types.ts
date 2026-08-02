export interface DriverLocationUpdate {
  rideId?: string;
  lat: number;
  lng: number;
  accuracy?: number;
}

export interface ActiveDriverLocation {
  driverId: string;
  driverName?: string;
  tricyclePlateNumber?: string;
  lat: number;
  lng: number;
  isOnline: boolean;
  activeRideId?: string | null;
  updatedAt: Date;
}
