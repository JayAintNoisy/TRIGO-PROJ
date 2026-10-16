/// Pure logic behind the live tracking view: payload shapes, driver state
/// classification, filtering, relative times and the GeoJSON the map consumes.
///
/// Kept free of Vue and of the mapbox global so the rules can be read (and
/// changed) without touching the map code.

/// How often the fleet is re-fetched. Drivers broadcast every 15s, so polling
/// faster than that would only re-read the same fixes.
export const POLL_INTERVAL_MS = 10_000;

/// A fix older than this is shown as stale. The backend sweeper flips a driver
/// offline after 3 minutes of silence, so this warns before that happens.
export const STALE_AFTER_MS = 90_000;

export type DriverKind = 'on_trip' | 'available' | 'stale' | 'suspended';

export interface ActiveRide {
  rideId: string;
  status: string;
  customerName?: string;
  pickupAddress?: string | null;
  dropoffAddress?: string | null;
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  startedAt?: string | null;
}

/// One online driver, as returned by GET /tracking/active.
export interface LiveDriver {
  driverId: string;
  driverUserId?: string;
  driverName?: string;
  tricyclePlateNumber?: string;
  municipalityId?: string | null;
  municipalityName?: string | null;
  applicationStatus?: string;
  lat: number;
  lng: number;
  isOnline: boolean;
  lastSeenAt?: string | null;
  activeRide?: ActiveRide | null;
}

export interface Municipality {
  id: string;
  name: string;
  centerLat?: number;
  centerLng?: number;
  radiusKm?: number;
  boundaryGeojson?: any;
}

export interface TrailPoint {
  lat: number;
  lng: number;
  timestamp?: string;
}

export type LatLng = [number, number];

/// Whether the driver's most recent fix is old enough to warn about.
export function isStale(driver: LiveDriver, now: number = Date.now()): boolean {
  const seen = Date.parse(driver.lastSeenAt ?? '');
  if (Number.isNaN(seen)) return false;
  return now - seen > STALE_AFTER_MS;
}

/// The single state shown for a driver. A driver on a trip stays "on trip" even
/// with an ageing fix — that is the more important fact — but the UI pairs it
/// with [isStale] so a frozen GPS fix is still visible.
export function classifyDriver(driver: LiveDriver, now: number = Date.now()): DriverKind {
  if (driver.applicationStatus && driver.applicationStatus !== 'approved') return 'suspended';
  if (driver.activeRide) return 'on_trip';
  if (isStale(driver, now)) return 'stale';
  return 'available';
}

export function statusLabel(kind: DriverKind): string {
  switch (kind) {
    case 'on_trip': return 'On trip';
    case 'available': return 'Available';
    case 'stale': return 'Stale';
    case 'suspended': return 'Suspended';
  }
}

export function statusBadgeVariant(kind: DriverKind): 'success' | 'warning' | 'danger' | 'neutral' {
  switch (kind) {
    case 'on_trip': return 'warning';
    case 'available': return 'success';
    case 'stale': return 'neutral';
    case 'suspended': return 'danger';
  }
}

/// Marker colours are inline styles rather than utility classes: these elements
/// are created imperatively (outside Vue templates), so nothing guarantees a
/// class name would survive Tailwind's source scan.
export function markerColors(kind: DriverKind, selected: boolean): { background: string; border: string; text: string } {
  const palette: Record<DriverKind, string> = {
    on_trip: '#f59e0b',
    available: '#10b981',
    stale: '#94a3b8',
    suspended: '#ef4444',
  };
  return {
    background: palette[kind],
    border: selected ? '#1d4ed8' : '#ffffff',
    text: kind === 'on_trip' || kind === 'stale' ? '#0f172a' : '#ffffff',
  };
}

/// "just now" / "42s ago" / "7m ago" / "3h ago" / "2d ago".
export function formatLastSeen(lastSeenAt?: string | null, now: number = Date.now()): string {
  const seen = Date.parse(lastSeenAt ?? '');
  if (Number.isNaN(seen)) return 'never';
  const seconds = Math.max(0, Math.round((now - seen) / 1000));
  if (seconds < 10) return 'just now';
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

/// Which markers must be dropped after a poll: everything that disappeared from
/// the payload (a driver who went offline or lost their fix).
export function removedDriverIds(previous: LiveDriver[], incoming: LiveDriver[]): string[] {
  const nextIds = new Set(incoming.map((d) => d.driverId));
  return previous.filter((d) => !nextIds.has(d.driverId)).map((d) => d.driverId);
}

/// Applies the service-area filter and the free-text search over name and plate.
export function filterDrivers(
  drivers: LiveDriver[],
  options: { municipalityId?: string; query?: string } = {}
): LiveDriver[] {
  const query = (options.query ?? '').trim().toLowerCase();
  return drivers.filter((driver) => {
    if (options.municipalityId && driver.municipalityId !== options.municipalityId) return false;
    if (!query) return true;
    return [driver.driverName, driver.tricyclePlateNumber]
      .filter(Boolean)
      .some((value) => String(value).toLowerCase().includes(query));
  });
}

/// Busy drivers first, then whoever checked in most recently.
export function sortDrivers(drivers: LiveDriver[]): LiveDriver[] {
  return [...drivers].sort((a, b) => {
    const aBusy = a.activeRide ? 1 : 0;
    const bBusy = b.activeRide ? 1 : 0;
    if (aBusy !== bBusy) return bBusy - aBusy;
    const aSeen = Date.parse(a.lastSeenAt ?? '') || 0;
    const bSeen = Date.parse(b.lastSeenAt ?? '') || 0;
    if (aSeen !== bSeen) return bSeen - aSeen;
    return labelForDriver(a).localeCompare(labelForDriver(b));
  });
}

export function labelForDriver(driver: LiveDriver): string {
  return driver.driverName || 'Unnamed driver';
}

export function plateForDriver(driver: LiveDriver): string {
  return driver.tricyclePlateNumber || 'No plate';
}

/// The municipality a driver belongs to, for the list and the details panel.
export function municipalityLabel(driver: LiveDriver): string {
  return driver.municipalityName || 'Unassigned area';
}

export function rideStatusLabel(status?: string): string {
  switch (status) {
    case 'requested': return 'Finding a driver';
    case 'accepted': return 'Driver on the way';
    case 'driver_arriving': return 'Driver arriving';
    case 'in_progress': return 'Trip in progress';
    case 'completed': return 'Completed';
    case 'cancelled': return 'Cancelled';
    default: return 'Active';
  }
}

/// Short, copyable ride reference for the panel.
export function shortId(id?: string | null): string {
  if (!id) return '—';
  return id.length > 8 ? `${id.slice(0, 8)}…` : id;
}

/// The swatch of the fleet map: driver positions plus the centres of any
/// municipality that has no polygon, so an operator's first view is the whole
/// service area rather than a default city.
export function boundsFor(drivers: LiveDriver[], municipalities: Municipality[] = []): [LatLng, LatLng] | null {
  const points: LatLng[] = [];

  drivers.forEach((d) => {
    points.push([d.lng, d.lat]);
    if (d.activeRide) {
      points.push([d.activeRide.pickupLng, d.activeRide.pickupLat]);
      points.push([d.activeRide.dropoffLng, d.activeRide.dropoffLat]);
    }
  });

  municipalities.forEach((m) => {
    if (m.centerLat != null && m.centerLng != null) points.push([m.centerLng, m.centerLat]);
  });

  if (!points.length) return null;

  const lngs = points.map((p) => p[0]);
  const lats = points.map((p) => p[1]);
  return [
    [Math.min(...lngs), Math.min(...lats)],
    [Math.max(...lngs), Math.max(...lats)],
  ];
}

/// Boundary polygons for the map source, skipping municipalities that have none
/// (the boundary mapper can be left empty for a new area).
export function boundaryFeatureCollection(municipalities: Municipality[]): any {
  const features = municipalities
    .map((municipality) => {
      const geometry = parseBoundary(municipality.boundaryGeojson);
      if (!geometry) return null;
      return {
        type: 'Feature',
        properties: { id: municipality.id, name: municipality.name },
        geometry,
      };
    })
    .filter(Boolean);

  return { type: 'FeatureCollection', features };
}

/// The stored boundary may arrive as an object or as a JSON string.
export function parseBoundary(boundary: any): any | null {
  if (!boundary) return null;
  let value = boundary;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  }
  if (value && value.type === 'Polygon' && Array.isArray(value.coordinates)) return value;
  if (Array.isArray(value) && value.length >= 3) {
    const ring = value.map((p: any) => [Number(p[0]), Number(p[1])]);
    ring.push(ring[0]);
    return { type: 'Polygon', coordinates: [ring] };
  }
  return null;
}

/// The recorded breadcrumb of the selected trip, as a line for the map.
export function trailFeatureCollection(points: TrailPoint[]): any {
  const coordinates = points.map((p) => [p.lng, p.lat]);
  if (coordinates.length < 2) return { type: 'FeatureCollection', features: [] };
  return {
    type: 'FeatureCollection',
    features: [
      { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates } },
    ],
  };
}

/// The two ends of the selected trip, drawn as distinct markers.
export function tripEndpoints(ride?: ActiveRide | null): { pickup: LatLng; dropoff: LatLng } | null {
  if (!ride) return null;
  return {
    pickup: [ride.pickupLng, ride.pickupLat],
    dropoff: [ride.dropoffLng, ride.dropoffLat],
  };
}

/// Counts for the summary strip.
export function fleetSummary(drivers: LiveDriver[], now: number = Date.now()) {
  const kinds = drivers.map((d) => classifyDriver(d, now));
  return {
    online: drivers.length,
    onTrip: kinds.filter((k) => k === 'on_trip').length,
    available: kinds.filter((k) => k === 'available').length,
    stale: kinds.filter((k) => k === 'stale').length,
    suspended: kinds.filter((k) => k === 'suspended').length,
  };
}
