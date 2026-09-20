<template>
  <div class="space-y-3">
    <!-- Header with Quick Actions -->
    <div class="flex items-center justify-between bg-brand-slate-100 p-2.5 rounded-xl border border-brand-slate-200">
      <div class="flex items-center gap-2">
        <span class="text-xs font-bold text-brand-slate-700 uppercase tracking-wider">Boundary Geometry:</span>
        <span class="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-bold rounded-lg bg-brand-blue-base text-white shadow-sm">
          ✏️ Custom Polygon
        </span>
      </div>

      <!-- Icon-Only Action Buttons -->
      <div class="flex items-center gap-1.5">
        <button
          type="button"
          title="Undo last point"
          class="w-8 h-8 flex items-center justify-center text-sm font-semibold bg-white hover:bg-brand-slate-50 border border-brand-slate-300 rounded-lg text-brand-slate-700 transition disabled:opacity-40 disabled:cursor-not-allowed shadow-sm hover:shadow"
          :disabled="polygonPoints.length === 0"
          @click="undoLastPoint"
        >
          ↩️
        </button>
        <button
          type="button"
          title="Clear all points"
          class="w-8 h-8 flex items-center justify-center text-sm font-semibold bg-red-50 hover:bg-red-100 border border-red-200 rounded-lg text-red-700 transition disabled:opacity-40 disabled:cursor-not-allowed shadow-sm hover:shadow"
          :disabled="polygonPoints.length === 0"
          @click="clearPolygon"
        >
          🗑️
        </button>
      </div>
    </div>

    <!-- Instruction Bar -->
    <div class="text-xs px-3 py-2 rounded-lg flex items-center justify-between bg-blue-50 text-blue-800 border border-blue-200">
      <div class="flex items-center gap-1.5">
        <span class="font-bold">Instructions:</span>
        <span>Click on the map to define boundary corner points (min. 3 points). Drag any marker to adjust.</span>
      </div>

      <span class="font-bold text-xs bg-blue-200/60 px-2.5 py-0.5 rounded-full">
        {{ polygonPoints.length }} vertex points
      </span>
    </div>

    <!-- Mapbox Container -->
    <div class="relative w-full h-[360px] rounded-xl overflow-hidden border border-brand-slate-300 shadow-inner">
      <div ref="mapContainer" class="w-full h-full"></div>

      <!-- Helper / Status Overlay -->
      <div class="absolute bottom-2 left-2 bg-white/90 backdrop-blur px-2.5 py-1 rounded-md text-[11px] text-brand-slate-600 shadow border border-brand-slate-200 pointer-events-none">
        <span v-if="polygonPoints.length === 0">Click on the map to place first boundary point</span>
        <span v-else-if="polygonPoints.length < 3">Need {{ 3 - polygonPoints.length }} more point(s) to close polygon</span>
        <span v-else class="text-emerald-700 font-semibold">✓ Valid closed polygon ({{ polygonPoints.length }} vertices)</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';

declare const mapboxgl: any;

const MAPBOX_TOKEN = 'pk.eyJ1Ijoia2VudHgiLCJhIjoiY210NWJ1bndqMDdidjJ3czU4ajRpdHl5eiJ9.bIrzKPttbOo0gAf4_jtj5g';

interface BoundaryData {
  centerLat: number;
  centerLng: number;
  radiusKm?: number;
  boundaryGeojson?: any;
}

const props = defineProps<{
  modelValue: BoundaryData;
  municipalityName?: string;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: BoundaryData): void;
}>();

const mapContainer = ref<HTMLDivElement | null>(null);

// Polygon points as [lng, lat], starts with 0 points by default
const polygonPoints = ref<[number, number][]>([]);

let mapInstance: any = null;
let vertexMarkers: any[] = [];
let resizeObserver: ResizeObserver | null = null;

// Snapshot of the last modelValue we emitted ourselves. The parent's v-model
// writes it straight back, which would otherwise retrigger the watcher below:
// initPointsFromProps() would see boundaryGeojson: null and reset the
// in-progress points to [], wiping every click before 3 points are reached.
// Skipping our own echo breaks that loop while genuine external changes
// (different municipality, form reset) still sync through.
const lastEmittedJson = ref<string | null>(null);

// Initialize polygon points from prop
const initPointsFromProps = () => {
  let geojson = props.modelValue?.boundaryGeojson;
  if (!geojson) {
    polygonPoints.value = [];
    return;
  }
  if (typeof geojson === 'string') {
    try {
      geojson = JSON.parse(geojson);
    } catch (_) {}
  }
  if (geojson && typeof geojson === 'object') {
    if (geojson.type === 'Polygon' && Array.isArray(geojson.coordinates) && geojson.coordinates.length > 0) {
      const ring = geojson.coordinates[0];
      // Exclude duplicate closing point
      const pts = ring.slice(0, ring.length > 3 && ring[0][0] === ring[ring.length - 1][0] && ring[0][1] === ring[ring.length - 1][1] ? -1 : ring.length);
      polygonPoints.value = pts.map((p: any) => [parseFloat(p[0]), parseFloat(p[1])]);
      return;
    } else if (Array.isArray(geojson) && geojson.length >= 3) {
      polygonPoints.value = geojson.map((p: any) => [parseFloat(p[0]), parseFloat(p[1])]);
      return;
    }
  }
  polygonPoints.value = [];
};

const createGeoJsonFeature = (points: [number, number][]) => {
  if (points.length === 0) return { type: 'FeatureCollection', features: [] };
  if (points.length === 1) {
    return {
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'Point',
        coordinates: points[0],
      },
    };
  }
  if (points.length === 2) {
    return {
      type: 'Feature',
      properties: {},
      geometry: {
        type: 'LineString',
        coordinates: points,
      },
    };
  }
  const closed = [...points];
  if (closed[0][0] !== closed[closed.length - 1][0] || closed[0][1] !== closed[closed.length - 1][1]) {
    closed.push([closed[0][0], closed[0][1]]);
  }
  return {
    type: 'Feature',
    properties: {},
    geometry: {
      type: 'Polygon',
      coordinates: [closed],
    },
  };
};

const createGeoJsonPolygon = (points: [number, number][]) => {
  if (points.length < 3) return null;
  const closed = [...points];
  if (closed[0][0] !== closed[closed.length - 1][0] || closed[0][1] !== closed[closed.length - 1][1]) {
    closed.push([closed[0][0], closed[0][1]]);
  }
  return {
    type: 'Polygon',
    coordinates: [closed],
  };
};

const calculateCentroid = (points: [number, number][]): [number, number] => {
  if (points.length === 0) return [props.modelValue?.centerLng || 125.1278, props.modelValue?.centerLat || 8.1575];
  let sumLng = 0;
  let sumLat = 0;
  for (const pt of points) {
    sumLng += pt[0];
    sumLat += pt[1];
  }
  return [sumLng / points.length, sumLat / points.length];
};

const emitUpdate = () => {
  let next: BoundaryData;
  if (polygonPoints.value.length >= 3) {
    const [cLng, cLat] = calculateCentroid(polygonPoints.value);
    const geojson = createGeoJsonPolygon(polygonPoints.value);
    next = {
      ...props.modelValue,
      centerLat: parseFloat(cLat.toFixed(6)),
      centerLng: parseFloat(cLng.toFixed(6)),
      boundaryGeojson: geojson,
    };
  } else {
    next = {
      ...props.modelValue,
      boundaryGeojson: null,
    };
  }
  lastEmittedJson.value = JSON.stringify(next);
  emit('update:modelValue', next);
};

const undoLastPoint = () => {
  if (polygonPoints.value.length > 0) {
    polygonPoints.value.pop();
    updateMapLayers();
    emitUpdate();
  }
};

const clearPolygon = () => {
  polygonPoints.value = [];
  updateMapLayers();
  emitUpdate();
};

const updateMapLayers = () => {
  if (!mapInstance) return;

  // Clear existing markers
  vertexMarkers.forEach((m) => m.remove());
  vertexMarkers = [];

  // Update Polygon Source if style is ready
  if (mapInstance.isStyleLoaded()) {
    const polySource = mapInstance.getSource('boundary-polygon-src');
    if (polySource) {
      polySource.setData(createGeoJsonFeature(polygonPoints.value));
    }
  }

  // Render draggable vertex markers directly
  polygonPoints.value.forEach((pt, index) => {
    const el = document.createElement('div');
    el.className = 'w-4 h-4 bg-brand-blue-base border-2 border-white rounded-full shadow-md cursor-grab active:cursor-grabbing hover:scale-125 transition-transform';

    const marker = new mapboxgl.Marker({ element: el, draggable: true })
      .setLngLat(pt)
      .addTo(mapInstance);

    marker.on('drag', () => {
      const lngLat = marker.getLngLat();
      polygonPoints.value[index] = [lngLat.lng, lngLat.lat];
      if (mapInstance && mapInstance.isStyleLoaded()) {
        const polySource = mapInstance.getSource('boundary-polygon-src');
        if (polySource) {
          polySource.setData(createGeoJsonFeature(polygonPoints.value));
        }
      }
    });

    marker.on('dragend', () => {
      emitUpdate();
    });

    vertexMarkers.push(marker);
  });
};

const fitToPolygon = () => {
  if (!mapInstance || polygonPoints.value.length < 2) return;
  const bounds = new mapboxgl.LngLatBounds();
  polygonPoints.value.forEach((pt) => bounds.extend(pt));
  mapInstance.fitBounds(bounds, { padding: 50, maxZoom: 14, duration: 600 });
};

const initMap = () => {
  if (!mapContainer.value || typeof mapboxgl === 'undefined') return;

  mapboxgl.accessToken = MAPBOX_TOKEN;

  // Derive initial center directly from points if available
  let initialCenter: [number, number] = [
    props.modelValue?.centerLng || 125.1278,
    props.modelValue?.centerLat || 8.1575,
  ];
  if (polygonPoints.value.length > 0) {
    const [cLng, cLat] = calculateCentroid(polygonPoints.value);
    initialCenter = [cLng, cLat];
  }

  mapInstance = new mapboxgl.Map({
    container: mapContainer.value,
    style: 'mapbox://styles/mapbox/streets-v12',
    center: initialCenter,
    zoom: polygonPoints.value.length >= 3 ? 12 : 11.5,
  });

  mapInstance.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right');

  mapInstance.on('load', () => {
    // Add Polygon Source with immediate initial data
    mapInstance.addSource('boundary-polygon-src', {
      type: 'geojson',
      data: createGeoJsonFeature(polygonPoints.value),
    });

    mapInstance.addLayer({
      id: 'boundary-polygon-fill',
      type: 'fill',
      source: 'boundary-polygon-src',
      paint: {
        'fill-color': '#2563EB',
        'fill-opacity': 0.18,
      },
    });

    mapInstance.addLayer({
      id: 'boundary-polygon-line',
      type: 'line',
      source: 'boundary-polygon-src',
      paint: {
        'line-color': '#2563EB',
        'line-width': 3,
      },
    });

    updateMapLayers();
    if (polygonPoints.value.length >= 3) {
      fitToPolygon();
    }

    // Map Click Handler for adding polygon vertices
    mapInstance.on('click', (e: any) => {
      polygonPoints.value.push([e.lngLat.lng, e.lngLat.lat]);
      updateMapLayers();
      emitUpdate();
    });

    // Resize map after modal mount
    setTimeout(() => {
      if (mapInstance) {
        mapInstance.resize();
        if (polygonPoints.value.length >= 3) {
          fitToPolygon();
        }
      }
    }, 150);
  });

  // Watch for container resize when modal opens
  if (mapContainer.value && window.ResizeObserver) {
    resizeObserver = new ResizeObserver(() => {
      if (mapInstance) {
        mapInstance.resize();
      }
    });
    resizeObserver.observe(mapContainer.value);
  }
};

watch(
  () => props.modelValue,
  (incoming) => {
    // Ignore the echo of our own emit (parent v-model write-back) so
    // in-progress points are never wiped; anything else is a genuine
    // external change and re-syncs from props.
    if (incoming && JSON.stringify(incoming) === lastEmittedJson.value) return;
    lastEmittedJson.value = null;
    initPointsFromProps();
    updateMapLayers();
    if (mapInstance && polygonPoints.value.length >= 3) {
      fitToPolygon();
    }
  },
  { deep: true }
);

onMounted(async () => {
  initPointsFromProps();
  await nextTick();
  initMap();
});

onUnmounted(() => {
  if (resizeObserver) {
    resizeObserver.disconnect();
  }
  if (mapInstance) {
    mapInstance.remove();
    mapInstance = null;
  }
});
</script>
