<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div class="flex items-center justify-between w-full">
          <div>
            <h2 class="text-lg font-bold text-brand-slate-900">Live GPS Fleet Tracking Map</h2>
            <p class="text-xs text-brand-slate-500">Real-time driver positions across registered municipality service zones</p>
          </div>
          <span class="text-xs font-semibold text-brand-green-base bg-emerald-50 border border-emerald-200 px-3 py-1 rounded-full">
            ● Polling Live Updates (10s)
          </span>
        </div>
      </template>

      <!-- Simulated Map Display Box -->
      <div class="relative w-full h-[500px] rounded-xl bg-slate-900 overflow-hidden flex items-center justify-center border border-brand-slate-200 shadow-inner">
        <div class="absolute inset-0 opacity-30 bg-[radial-gradient(#3b82f6_1px,transparent_1px)] [background-size:16px_16px]"></div>

        <!-- Simulated Map Grid & Markers -->
        <div class="relative z-10 w-full h-full p-8 flex flex-col justify-between">
          <div class="flex justify-between items-start">
            <div class="bg-slate-800/90 backdrop-blur-md p-4 rounded-xl border border-slate-700 text-white max-w-sm">
              <p class="text-xs font-bold text-brand-blue-light uppercase tracking-wider">Active Jurisdiction</p>
              <h3 class="text-base font-bold">Malaybalay City, Bukidnon</h3>
              <p class="text-xs text-slate-400 mt-1">Center: 8.1575° N, 125.1278° E (15km radius)</p>
            </div>

            <div class="bg-slate-800/90 backdrop-blur-md px-4 py-2 rounded-xl border border-slate-700 text-white text-xs font-mono">
              Online Fleet: <span class="font-bold text-emerald-400">{{ activeDrivers.length }} Tricycles</span>
            </div>
          </div>

          <!-- Driver Marker Simulation -->
          <div v-for="(driver, index) in activeDrivers" :key="index" class="absolute flex flex-col items-center transform -translate-x-1/2 -translate-y-1/2" :style="getDriverStyle(index)">
            <div class="px-2.5 py-1 rounded-lg bg-emerald-500 text-slate-950 font-extrabold text-xs shadow-lg animate-bounce">
              🛺 {{ driver.driverName || 'Juan Dela Cruz' }} ({{ driver.tricyclePlateNumber || '123-ABC' }})
            </div>
            <div class="w-3 h-3 bg-emerald-400 rounded-full border-2 border-white shadow-md"></div>
          </div>
        </div>
      </div>
    </AppCard>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import { useApi } from '@/composables/useApi';

const api = useApi();
const activeDrivers = ref<any[]>([]);
let intervalId: any = null;

const fetchActiveDrivers = async () => {
  try {
    const res = await api.get('/tracking/active');
    activeDrivers.value = res.data.data;
  } catch {
    activeDrivers.value = [];
  }
};

onMounted(() => {
  fetchActiveDrivers();
  intervalId = setInterval(fetchActiveDrivers, 10000);
});

onUnmounted(() => {
  if (intervalId) clearInterval(intervalId);
});

const getDriverStyle = (index: number) => {
  const d = activeDrivers.value[index];
  if (d && d.lat && d.lng) {
    const top = `${((8.15 - d.lat) / 0.02) * 50 + 50}%`;
    const left = `${((d.lng - 125.1) / 0.02) * 50 + 50}%`;
    return { top, left };
  }
  return { top: '50%', left: '45%' };
};
</script>
