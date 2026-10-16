<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div class="flex flex-wrap items-center justify-between gap-3 w-full">
          <div>
            <h2 class="text-lg font-bold text-brand-slate-900">Live Fleet Tracking</h2>
            <p class="text-xs text-brand-slate-500">
              Real-time driver positions, active trips and service-area coverage
            </p>
          </div>
          <div class="flex items-center gap-2">
            <span class="text-xs font-semibold px-3 py-1 rounded-full border" :class="pollingPillClass">
              ● {{ pollingLabel }}
            </span>
            <AppButton size="sm" variant="outline" @click="fitFleet">Fit fleet</AppButton>
            <AppButton size="sm" variant="outline" @click="refreshNow">Refresh</AppButton>
            <AppButton size="sm" :variant="isPaused ? 'secondary' : 'outline'" @click="togglePolling">
              {{ isPaused ? 'Resume' : 'Pause' }}
            </AppButton>
          </div>
        </div>
      </template>

      <!-- Filters and fleet snapshot -->
      <div class="grid gap-3 md:grid-cols-4 mb-4">
        <AppSelect v-model="municipalityFilter" label="Service area" :options="municipalityOptions" />
        <AppInput v-model="searchQuery" label="Search fleet" placeholder="Plate or driver name" />
        <div class="flex flex-col gap-1.5 md:col-span-2">
          <span class="text-sm font-semibold text-brand-slate-900">Fleet snapshot</span>
          <div class="flex flex-wrap items-center gap-2 text-xs">
            <span class="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-700 font-semibold">
              {{ summary.online }} online
            </span>
            <span class="px-2.5 py-1 rounded-lg bg-amber-100 text-amber-800 font-semibold">
              {{ summary.onTrip }} on trip
            </span>
            <span class="px-2.5 py-1 rounded-lg bg-emerald-100 text-emerald-800 font-semibold">
              {{ summary.available }} available
            </span>
            <span class="px-2.5 py-1 rounded-lg bg-slate-100 text-slate-600 font-semibold">
              {{ summary.stale }} stale
            </span>
            <span v-if="summary.suspended" class="px-2.5 py-1 rounded-lg bg-red-100 text-red-700 font-semibold">
              {{ summary.suspended }} suspended
            </span>
            <span class="text-brand-slate-500">Updated {{ lastUpdatedLabel }}</span>
          </div>
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-3">
        <!-- Map -->
        <div class="lg:col-span-2">
          <div class="relative w-full h-[560px] rounded-xl overflow-hidden border border-brand-slate-200 shadow-inner bg-slate-100">
            <div ref="mapContainer" class="w-full h-full"></div>

            <div
              v-if="!mapReady"
              class="absolute inset-0 flex flex-col items-center justify-center gap-2 bg-slate-50 text-center p-6"
            >
              <p class="text-sm font-semibold text-brand-slate-700">Map unavailable</p>
              <p class="text-xs text-brand-slate-500 max-w-sm">{{ mapNotice }}</p>
            </div>

            <!-- A failed poll keeps the last known fleet on screen -->
            <div
              v-if="fetchError"
              class="absolute top-3 left-3 right-3 bg-amber-50/95 backdrop-blur border border-amber-200 text-amber-800 text-xs font-medium px-3 py-2 rounded-lg"
            >
              {{ fetchError }}
            </div>

            <div class="absolute bottom-3 left-3 bg-white/95 backdrop-blur border border-brand-slate-200 rounded-lg px-3 py-2 flex flex-wrap gap-3 text-[11px] font-semibold text-brand-slate-600 pointer-events-none">
              <span class="flex items-center gap-1.5"><span class="w-2.5 h-2.5 rounded-full bg-amber-500"></span>On trip</span>
              <span class="flex items-center gap-1.5"><span class="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>Available</span>
              <span class="flex items-center gap-1.5"><span class="w-2.5 h-2.5 rounded-full bg-slate-400"></span>Stale</span>
              <span class="flex items-center gap-1.5"><span class="w-2.5 h-2.5 rounded-full bg-red-500"></span>Suspended</span>
            </div>
          </div>
        </div>

        <!-- Selected driver, then the fleet list -->
        <div class="space-y-3">
          <div
            v-if="selectedDriver"
            class="border border-brand-slate-200 rounded-xl p-4 space-y-3 bg-brand-slate-50/60"
          >
            <div class="flex items-start justify-between gap-2">
              <div>
                <p class="font-bold text-brand-slate-900">{{ labelForDriver(selectedDriver) }}</p>
                <p class="text-xs text-brand-slate-500">
                  {{ plateForDriver(selectedDriver) }} · {{ municipalityLabel(selectedDriver) }}
                </p>
              </div>
              <AppBadge :variant="statusBadgeVariant(selectedKind)">{{ statusLabel(selectedKind) }}</AppBadge>
            </div>

            <div class="text-xs text-brand-slate-600 space-y-1">
              <p>Last fix: {{ formatLastSeen(selectedDriver.lastSeenAt, now) }}</p>
              <p
                v-if="isStale(selectedDriver, now) && selectedDriver.activeRide"
                class="text-amber-700 font-semibold"
              >
                Position is not updating while on a trip.
              </p>
            </div>

            <div v-if="selectedDriver.activeRide" class="border-t border-brand-slate-200 pt-3 space-y-2">
              <div class="flex items-center justify-between gap-2">
                <span class="text-xs font-bold text-brand-slate-700 uppercase tracking-wide">Active trip</span>
                <span class="text-xs font-mono text-brand-slate-500">
                  {{ shortId(selectedDriver.activeRide.rideId) }}
                </span>
              </div>
              <p class="text-xs text-brand-slate-600">
                {{ rideStatusLabel(selectedDriver.activeRide.status) }}
                <span v-if="selectedDriver.activeRide.customerName">
                  · {{ selectedDriver.activeRide.customerName }}
                </span>
              </p>
              <div class="text-xs text-brand-slate-700 space-y-1">
                <p>
                  <span class="font-semibold text-emerald-700">Pickup:</span>
                  {{ selectedDriver.activeRide.pickupAddress || 'Pinned location' }}
                </p>
                <p>
                  <span class="font-semibold text-red-700">Drop-off:</span>
                  {{ selectedDriver.activeRide.dropoffAddress || 'Pinned location' }}
                </p>
              </div>
              <button
                type="button"
                class="text-xs font-semibold text-brand-blue-base hover:underline"
                @click="toggleTrail"
              >
                {{ showTrail ? 'Hide recorded trail' : 'Show recorded trail' }}
              </button>
              <p v-if="showTrail && trailPoints.length < 2" class="text-xs text-brand-slate-500">
                No movement recorded for this trip yet.
              </p>
            </div>

            <div class="flex items-center gap-3 pt-1">
              <button
                type="button"
                class="text-xs font-semibold text-brand-blue-base hover:underline"
                @click="focusSelected"
              >
                Centre on driver
              </button>
              <button
                type="button"
                class="text-xs font-semibold text-brand-slate-500 hover:underline"
                @click="clearSelection"
              >
                Clear selection
              </button>
            </div>
          </div>

          <div class="border border-brand-slate-200 rounded-xl overflow-hidden">
            <div class="px-3 py-2 bg-brand-slate-50 border-b border-brand-slate-200 flex items-center justify-between">
              <span class="text-xs font-bold text-brand-slate-700 uppercase tracking-wide">Fleet</span>
              <span class="text-xs text-brand-slate-500">{{ visibleDrivers.length }} shown</span>
            </div>
            <div class="max-h-[460px] overflow-y-auto divide-y divide-brand-slate-100">
              <button
                v-for="driver in visibleDrivers"
                :key="driver.driverId"
                type="button"
                class="w-full text-left px-3 py-2.5 hover:bg-brand-slate-50 transition-colors"
                :class="driver.driverId === selectedDriverId ? 'bg-blue-50/70' : ''"
                @click="focusDriver(driver.driverId)"
              >
                <div class="flex items-center justify-between gap-2">
                  <span class="text-sm font-semibold text-brand-slate-900 truncate">
                    {{ labelForDriver(driver) }}
                  </span>
                  <span class="text-[11px] font-semibold px-2 py-0.5 rounded-full" :class="chipClassFor(driver)">
                    {{ statusLabel(classifyDriver(driver, now)) }}
                  </span>
                </div>
                <div class="flex items-center justify-between gap-2 mt-0.5">
                  <span class="text-xs text-brand-slate-500 truncate">
                    {{ plateForDriver(driver) }} · {{ municipalityLabel(driver) }}
                  </span>
                  <span class="text-[11px] text-brand-slate-400 shrink-0">
                    {{ formatLastSeen(driver.lastSeenAt, now) }}
                  </span>
                </div>
              </button>

              <p v-if="!visibleDrivers.length" class="px-3 py-6 text-xs text-center text-brand-slate-500">
                {{ emptyListMessage }}
              </p>
            </div>
          </div>
        </div>
      </div>
    </AppCard>
  </div>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import AppBadge from '@/components/ui/AppBadge.vue';
import AppButton from '@/components/ui/AppButton.vue';
import AppInput from '@/components/ui/AppInput.vue';
import AppSelect from '@/components/ui/AppSelect.vue';
import { useApi } from '@/composables/useApi';
import { MAP_STYLE, getMapbox, isMapboxReady } from '@/config/mapbox';
import {
  DriverKind,
  LiveDriver,
  Municipality,
  POLL_INTERVAL_MS,
  TrailPoint,
  boundsFor,
  boundaryFeatureCollection,
  classifyDriver,
  filterDrivers,
  fleetSummary,
  formatLastSeen,
  isStale,
  labelForDriver,
  markerColors,
  municipalityLabel,
  plateForDriver,
  removedDriverIds,
  rideStatusLabel,
  shortId,
  sortDrivers,
  statusBadgeVariant,
  statusLabel,
  trailFeatureCollection,
  tripEndpoints,
} from './tracking.helpers';

const api = useApi();

const drivers = ref<LiveDriver[]>([]);
const municipalities = ref<Municipality[]>([]);
const municipalityFilter = ref('');
const searchQuery = ref('');
const selectedDriverId = ref<string | null>(null);
const isPaused = ref(false);
const lastUpdatedAt = ref<number | null>(null);
const fetchError = ref('');
const mapReady = ref(false);
const mapNotice = ref('Loading the map…');
const trailPoints = ref<TrailPoint[]>([]);
const showTrail = ref(true);
const mapContainer = ref<HTMLDivElement | null>(null);

/// Drives every relative-time label, on its own slow ticker, so ages stay
/// honest between polls without re-rendering the tree every second.
const now = ref(Date.now());

const mapbox = getMapbox();
let map: any = null;
/// Set only when Mapbox itself is unusable, so a missing library is not retried
/// on every poll while a missing-data attempt still is.
let mapUnavailable = false;
let isInitializingMap = false;
const markers = new Map<string, any>();
let endpointMarkers: any[] = [];
let endpointRideId: string | null = null;
let pollTimer: ReturnType<typeof setInterval> | null = null;
let clockTimer: ReturnType<typeof setInterval> | null = null;
let isFetching = false;

const summary = computed(() => fleetSummary(drivers.value, now.value));

const visibleDrivers = computed(() =>
  sortDrivers(
    filterDrivers(drivers.value, {
      municipalityId: municipalityFilter.value,
      query: searchQuery.value,
    })
  )
);

/// Falls back to the full list so a driver stays selected while a search or
/// filter temporarily hides them.
const selectedDriver = computed(
  () =>
    visibleDrivers.value.find((d) => d.driverId === selectedDriverId.value) ??
    drivers.value.find((d) => d.driverId === selectedDriverId.value) ??
    null
);

const selectedKind = computed<DriverKind>(() =>
  selectedDriver.value ? classifyDriver(selectedDriver.value, now.value) : 'available'
);

const municipalityOptions = computed(() => [
  { label: 'All municipalities', value: '' },
  ...municipalities.value.map((m) => ({ label: m.name, value: m.id })),
]);

const lastUpdatedLabel = computed(() => {
  if (lastUpdatedAt.value == null) return 'waiting for data';
  return formatLastSeen(new Date(lastUpdatedAt.value).toISOString(), now.value);
});

const pollingLabel = computed(() =>
  isPaused.value ? 'Polling paused' : `Polling every ${Math.round(POLL_INTERVAL_MS / 1000)}s`
);

const pollingPillClass = computed(() =>
  isPaused.value
    ? 'text-brand-slate-600 bg-brand-slate-100 border-brand-slate-200'
    : 'text-brand-green-base bg-emerald-50 border-emerald-200'
);

const emptyListMessage = computed(() =>
  drivers.value.length
    ? 'No drivers match this service area or search.'
    : 'No online drivers right now.'
);

const chipClassFor = (driver: LiveDriver): string => {
  switch (classifyDriver(driver, now.value)) {
    case 'on_trip': return 'bg-amber-100 text-amber-800';
    case 'available': return 'bg-emerald-100 text-emerald-800';
    case 'suspended': return 'bg-red-100 text-red-700';
    default: return 'bg-slate-100 text-slate-600';
  }
};

// ---------------------------------------------------------------- data loading

const loadMunicipalities = async () => {
  try {
    const res = await api.get('/municipalities');
    municipalities.value = res.data.data ?? [];
  } catch {
    // Boundaries are decoration here: without them the map still tracks drivers.
    municipalities.value = [];
  }
};

const loadDrivers = async () => {
  if (isFetching) return;
  isFetching = true;
  try {
    const res = await api.get('/tracking/active', {
      // Omitted entirely for "all areas": the API validates a UUID.
      params: municipalityFilter.value ? { municipalityId: municipalityFilter.value } : {},
    });
    const incoming: LiveDriver[] = res.data.data ?? [];
    const gone = removedDriverIds(drivers.value, incoming);

    drivers.value = incoming;
    lastUpdatedAt.value = Date.now();
    fetchError.value = '';

    gone.forEach((id) => {
      markers.get(id)?.remove();
      markers.delete(id);
    });
    if (selectedDriverId.value && gone.includes(selectedDriverId.value)) {
      selectedDriverId.value = null;
      clearTrail();
    }

    syncMarkers();
    syncTrail();
    // Retried here so the map appears as soon as there is anything to draw.
    if (!map && !mapUnavailable) tryInitMap();
  } catch {
    // Keep the last known fleet on screen: the age label shows how old it is.
    fetchError.value = navigator.onLine
      ? 'Could not reach the tracking API — showing the last known positions.'
      : 'You appear to be offline — showing the last known positions.';
  } finally {
    isFetching = false;
  }
};

const loadTrail = async (rideId: string) => {
  try {
    const res = await api.get(`/rides/${rideId}/tracking`);
    trailPoints.value = res.data.data ?? [];
  } catch {
    // Keep the previous line rather than flickering the map.
  }
};

// ------------------------------------------------------------------ map setup

const tryInitMap = async () => {
  if (map || mapUnavailable || isInitializingMap) return;
  isInitializingMap = true;

  try {
    if (!isMapboxReady() || !mapbox) {
      mapUnavailable = true;
      mapNotice.value =
        'The Mapbox library could not be loaded (offline, blocked, or a bad token). The fleet list still works.';
      return;
    }

    await nextTick();
    if (!mapContainer.value) return;

    const bounds = boundsFor(visibleDrivers.value, municipalities.value);
    if (!bounds) {
      // Nothing to draw yet. Deliberately not marked as attempted: the next
      // poll retries once a driver or a service area exists.
      mapNotice.value = 'No service areas or online drivers to display yet.';
      return;
    }

    const center = [(bounds[0][0] + bounds[1][0]) / 2, (bounds[0][1] + bounds[1][1]) / 2];

    map = new mapbox.Map({
      container: mapContainer.value,
      style: MAP_STYLE,
      center,
      zoom: 11,
    });
    map.addControl(new mapbox.NavigationControl({ showCompass: false }), 'top-right');

    map.on('load', () => {
      map.addSource('municipality-boundaries', {
        type: 'geojson',
        data: boundaryFeatureCollection(municipalities.value),
      });
      map.addLayer({
        id: 'municipality-fill',
        type: 'fill',
        source: 'municipality-boundaries',
        paint: { 'fill-color': '#2563EB', 'fill-opacity': 0.06 },
      });
      map.addLayer({
        id: 'municipality-line',
        type: 'line',
        source: 'municipality-boundaries',
        paint: { 'line-color': '#2563EB', 'line-width': 1.5, 'line-opacity': 0.5 },
      });
      map.addLayer({
        id: 'municipality-selected',
        type: 'line',
        source: 'municipality-boundaries',
        filter: selectedBoundaryFilter(),
        paint: { 'line-color': '#1D4ED8', 'line-width': 3 },
      });

      map.addSource('trip-trail', { type: 'geojson', data: trailFeatureCollection([]) });
      map.addLayer({
        id: 'trip-trail-line',
        type: 'line',
        source: 'trip-trail',
        paint: {
          'line-color': '#F59E0B',
          'line-width': 4,
          'line-dasharray': [2, 1.5],
          'line-opacity': 0.9,
        },
      });

      mapReady.value = true;
      mapNotice.value = '';
      syncMarkers();
      syncTrail();
      fitFleet();
    });

    map.on('error', () => {
      // Tile and style failures must not leave a blank panel with no explanation.
      if (!mapReady.value) {
        mapNotice.value = 'The map style failed to load. The fleet list still works.';
      }
    });
  } finally {
    isInitializingMap = false;
  }
};

const selectedBoundaryFilter = () => [
  '==',
  ['get', 'id'],
  municipalityFilter.value || '__none__',
];

const refreshBoundaries = () => {
  if (!map || !mapReady.value) return;
  map.getSource('municipality-boundaries')?.setData(boundaryFeatureCollection(municipalities.value));
  if (map.getLayer('municipality-selected')) {
    map.setFilter('municipality-selected', selectedBoundaryFilter());
  }
};

// -------------------------------------------------------------------- markers

/// Markers are plain DOM so they can carry a plate label. Styling is inline:
/// these nodes live outside Vue templates, where a Tailwind class name would
/// depend on the source scanner picking it up.
const styleMarkerElement = (el: HTMLElement, driver: LiveDriver) => {
  const colors = markerColors(classifyDriver(driver, now.value), driver.driverId === selectedDriverId.value);
  el.style.cssText = [
    'display:flex',
    'align-items:center',
    'gap:6px',
    'padding:3px 8px 3px 6px',
    'border-radius:999px',
    'box-shadow:0 2px 6px rgba(15,23,42,0.25)',
    'font-size:11px',
    'font-weight:700',
    'white-space:nowrap',
    'cursor:pointer',
    `background:${colors.background}`,
    `color:${colors.text}`,
    `border:2px solid ${colors.border}`,
  ].join(';');
};

const refreshMarkerElement = (el: HTMLElement, driver: LiveDriver) => {
  styleMarkerElement(el, driver);
  const label = el.querySelector('span[data-role="label"]');
  if (label) {
    // textContent, not innerHTML: plate and name are driver-supplied strings.
    label.textContent = `${plateForDriver(driver)}${driver.activeRide ? ' • on trip' : ''}`;
  }
};

const createMarkerElement = (driver: LiveDriver) => {
  const el = document.createElement('button');
  el.type = 'button';
  styleMarkerElement(el, driver);

  const dot = document.createElement('span');
  dot.style.cssText = 'width:7px;height:7px;border-radius:999px;background:rgba(255,255,255,0.85)';
  el.appendChild(dot);

  const label = document.createElement('span');
  label.dataset.role = 'label';
  label.textContent = `${plateForDriver(driver)}${driver.activeRide ? ' • on trip' : ''}`;
  el.appendChild(label);

  el.addEventListener('click', (event) => {
    event.stopPropagation();
    focusDriver(driver.driverId);
  });

  return el;
};

/// Adds markers for new drivers, moves and restyles the rest in place, and
/// drops anyone filtered out — so a poll never resets the operator's map.
const syncMarkers = () => {
  if (!map || !mapReady.value) return;

  const visibleIds = new Set(visibleDrivers.value.map((d) => d.driverId));
  markers.forEach((marker, id) => {
    if (!visibleIds.has(id)) {
      marker.remove();
      markers.delete(id);
    }
  });

  visibleDrivers.value.forEach((driver) => {
    const existing = markers.get(driver.driverId);
    if (existing) {
      existing.setLngLat([driver.lng, driver.lat]);
      refreshMarkerElement(existing.getElement(), driver);
      return;
    }
    const marker = new mapbox.Marker({ element: createMarkerElement(driver) })
      .setLngLat([driver.lng, driver.lat])
      .addTo(map);
    markers.set(driver.driverId, marker);
  });
};

const syncTrail = () => {
  if (!map || !mapReady.value) return;

  const ride = selectedDriver.value?.activeRide ?? null;
  const points = showTrail.value && ride ? trailPoints.value : [];
  map.getSource('trip-trail')?.setData(trailFeatureCollection(points));

  // Endpoints only change when the selected trip does: recreating them every
  // poll would make the map flicker.
  const nextRideId = showTrail.value ? ride?.rideId ?? null : null;
  if (nextRideId === endpointRideId) return;

  endpointMarkers.forEach((marker) => marker.remove());
  endpointMarkers = [];
  endpointRideId = nextRideId;

  const ends = tripEndpoints(ride);
  if (!ends || !showTrail.value) return;

  endpointMarkers = [
    new mapbox.Marker({ color: '#10B981' }).setLngLat(ends.pickup).addTo(map),
    new mapbox.Marker({ color: '#EF4444' }).setLngLat(ends.dropoff).addTo(map),
  ];
};

// ----------------------------------------------------------------- behaviors

const clearTrail = () => {
  trailPoints.value = [];
  syncTrail();
};

const reloadTrailForSelection = () => {
  const ride = selectedDriver.value?.activeRide;
  if (ride && showTrail.value) {
    loadTrail(ride.rideId).then(syncTrail);
  }
};

const focusDriver = (driverId: string) => {
  selectedDriverId.value = driverId;
  const driver = drivers.value.find((d) => d.driverId === driverId);
  if (!driver) return;

  if (map && mapReady.value) {
    map.flyTo({ center: [driver.lng, driver.lat], zoom: Math.max(map.getZoom(), 13) });
  }
  // Selection changes the marker ring, so restyle before anything else.
  syncMarkers();

  if (driver.activeRide && showTrail.value) {
    loadTrail(driver.activeRide.rideId).then(syncTrail);
  } else {
    clearTrail();
  }
};

const focusSelected = () => {
  if (selectedDriverId.value) focusDriver(selectedDriverId.value);
};

const clearSelection = () => {
  selectedDriverId.value = null;
  clearTrail();
  syncMarkers();
};

const toggleTrail = () => {
  showTrail.value = !showTrail.value;
  if (showTrail.value) {
    reloadTrailForSelection();
    syncTrail();
  } else {
    clearTrail();
  }
};

const fitFleet = () => {
  if (!map || !mapReady.value) return;

  const scoped = municipalityFilter.value
    ? municipalities.value.filter((m) => m.id === municipalityFilter.value)
    : municipalities.value;
  const bounds = boundsFor(visibleDrivers.value, scoped);
  if (!bounds) return;

  if (bounds[0][0] === bounds[1][0] && bounds[0][1] === bounds[1][1]) {
    map.flyTo({ center: bounds[0], zoom: 14 });
    return;
  }
  map.fitBounds(bounds, { padding: 70, maxZoom: 15, duration: 600 });
};

const refreshNow = () => {
  reloadTrailForSelection();
  loadDrivers();
};

const startPolling = () => {
  stopPolling();
  pollTimer = setInterval(() => {
    loadDrivers();
    reloadTrailForSelection();
  }, POLL_INTERVAL_MS);
};

const stopPolling = () => {
  if (pollTimer) {
    clearInterval(pollTimer);
    pollTimer = null;
  }
};

const togglePolling = () => {
  isPaused.value = !isPaused.value;
  if (isPaused.value) {
    stopPolling();
  } else {
    loadDrivers();
    startPolling();
  }
};

/// A hidden tab has nothing to draw, so polling pauses and catches up on return.
const onVisibilityChange = () => {
  if (document.hidden) {
    stopPolling();
  } else if (!isPaused.value) {
    loadDrivers();
    startPolling();
  }
};

// The service-area filter scopes the request, the list, the boundaries and the
// viewport together.
watch(municipalityFilter, () => {
  refreshBoundaries();
  loadDrivers().then(fitFleet);
});

// ------------------------------------------------------------------ lifecycle

onMounted(async () => {
  await Promise.all([loadMunicipalities(), loadDrivers()]);
  await tryInitMap();

  clockTimer = setInterval(() => {
    now.value = Date.now();
  }, 5_000);
  document.addEventListener('visibilitychange', onVisibilityChange);
  if (!isPaused.value) startPolling();
});

onUnmounted(() => {
  stopPolling();
  if (clockTimer) clearInterval(clockTimer);
  document.removeEventListener('visibilitychange', onVisibilityChange);
  markers.forEach((marker) => marker.remove());
  markers.clear();
  endpointMarkers.forEach((marker) => marker.remove());
  endpointMarkers = [];
  if (map) {
    map.remove();
    map = null;
  }
});
</script>
