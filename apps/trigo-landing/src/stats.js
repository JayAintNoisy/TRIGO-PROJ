import { envText } from './env.js';

/**
 * Coverage figures used when the API cannot be reached. They mirror
 * `apps/trigo-backend/src/shared/database/seed.ts`, so an offline landing page
 * still describes the real seeded fare matrix instead of showing blanks.
 */
export const FALLBACK_COVERAGE = Object.freeze({
  municipalities: 2,
  provinceNames: ['Cebu'],
  municipalityNames: ['Lapu-Lapu City', 'Cordova'],
  provinces: 1,
  baseFare: 30,
  perKmRate: 10,
  radiusKm: 15,
  maxPassengers: 4,
});

const DEFAULT_API_BASE = 'http://localhost:4000/api';
const REQUEST_TIMEOUT_MS = 4500;

export function apiBaseUrl() {
  const configured = envText('API_BASE_URL') || DEFAULT_API_BASE;
  return configured.replace(/\/+$/, '');
}

/** `/health` lives at the server root, while the API itself is served under `/api`. */
export function backendOrigin() {
  try {
    return new URL(apiBaseUrl(), window.location.href).origin;
  } catch {
    return 'http://localhost:4000';
  }
}

async function getJson(url, timeoutMs = REQUEST_TIMEOUT_MS) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      signal: controller.signal,
      cache: 'no-store',
      headers: { Accept: 'application/json' },
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
}

/**
 * Reduce the municipality list from `GET /api/municipalities` to the handful of
 * figures the statistics section shows. Returns null when nothing usable is
 * present, which keeps the caller on the seeded fallback.
 */
export function deriveCoverage(municipalities) {
  if (!Array.isArray(municipalities)) return null;

  const active = municipalities.filter((item) => item && item.isActive !== false);
  if (active.length === 0) return null;

  const numbers = (key) =>
    active.map((item) => Number(item[key])).filter((value) => Number.isFinite(value));

  const provinceNames = [...new Set(active.map((item) => (item.province || '').trim()))].filter(
    Boolean,
  );
  const municipalityNames = active.map((item) => (item.name || '').trim()).filter(Boolean);

  const baseFares = numbers('baseFare');
  const perKmRates = numbers('perKmRate');
  const radii = numbers('radiusKm');
  const passengers = numbers('maxPassengers');

  return {
    municipalities: active.length,
    provinces: provinceNames.length,
    provinceNames,
    municipalityNames,
    baseFare: baseFares.length ? Math.min(...baseFares) : null,
    perKmRate: perKmRates.length ? median(perKmRates) : null,
    radiusKm: radii.length ? Math.max(...radii) : null,
    maxPassengers: passengers.length ? Math.max(...passengers) : null,
  };
}

function failureReason(result) {
  if (result.status !== 'rejected') return null;
  const reason = result.reason;
  if (reason && reason.name === 'AbortError') return 'timed out';
  return (reason && reason.message) || 'unreachable';
}

/**
 * Fetch the public API state. Never rejects: a backend that is down, an empty
 * database or a `file://` origin all resolve to the seeded fallback so the page
 * always renders complete numbers.
 */
export async function loadStats() {
  const origin = backendOrigin();
  const [healthResult, coverageResult] = await Promise.allSettled([
    getJson(`${origin}/health`),
    getJson(`${origin}/api/municipalities`),
  ]);

  const healthPayload = healthResult.status === 'fulfilled' ? healthResult.value : null;
  const health = {
    ok: Boolean(healthPayload && healthPayload.status === 'ok'),
    service: (healthPayload && healthPayload.service) || null,
    timestamp: (healthPayload && healthPayload.timestamp) || null,
    error: failureReason(healthResult),
  };

  const coverage =
    coverageResult.status === 'fulfilled'
      ? deriveCoverage(coverageResult.value && coverageResult.value.data)
      : null;

  return {
    origin,
    health,
    coverageIsLive: coverage !== null,
    coverage: coverage || FALLBACK_COVERAGE,
    fetchedAt: new Date(),
  };
}
