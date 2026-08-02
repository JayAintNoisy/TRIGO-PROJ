<template>
  <div class="space-y-8">
    <!-- Page Title -->
    <div>
      <h1 class="text-2xl font-bold text-brand-slate-900">Dashboard Overview</h1>
      <p class="text-brand-slate-500 mt-1">{{ currentDate }}</p>
    </div>

    <!-- Metrics Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <div class="bg-white rounded-xl shadow-md p-6 flex flex-col">
        <div class="flex justify-between items-start mb-4">
          <div class="w-12 h-12 rounded-lg bg-blue-50 text-brand-blue-base flex items-center justify-center text-2xl">
            <Bike class="w-6 h-6" />
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-brand-slate-500 mb-1">Active Drivers</p>
          <div class="flex items-baseline gap-2">
            <h3 class="text-3xl font-bold text-brand-slate-900">{{ activeDriversCount }}</h3>
            <span class="text-sm font-medium text-brand-green-dark flex items-center">
              +12% today
            </span>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 flex flex-col">
        <div class="flex justify-between items-start mb-4">
          <div class="w-12 h-12 rounded-lg bg-green-50 text-brand-green-dark flex items-center justify-center text-2xl">
            <DollarSign class="w-6 h-6" />
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-brand-slate-500 mb-1">Today's Revenue</p>
          <div class="flex items-baseline gap-2">
            <h3 class="text-3xl font-bold text-brand-slate-900">₱{{ totalRevenueAmount.toLocaleString() }}</h3>
            <span class="text-sm font-medium text-brand-green-dark flex items-center">
              +8% today
            </span>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 flex flex-col">
        <div class="flex justify-between items-start mb-4">
          <div class="w-12 h-12 rounded-lg bg-blue-50 text-brand-blue-base flex items-center justify-center text-2xl">
            <CheckCircle class="w-6 h-6" />
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-brand-slate-500 mb-1">Completed Trips</p>
          <div class="flex items-baseline gap-2">
            <h3 class="text-3xl font-bold text-brand-slate-900">{{ completedTripsCount }}</h3>
            <span class="text-sm font-medium text-brand-green-dark flex items-center">
              +15% today
            </span>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 flex flex-col">
        <div class="flex justify-between items-start mb-4">
          <div class="w-12 h-12 rounded-lg bg-brand-slate-100 text-brand-slate-500 flex items-center justify-center text-2xl">
            <AlertTriangle class="w-6 h-6" />
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-brand-slate-500 mb-1">Active SOS</p>
          <div class="flex items-baseline gap-2">
            <h3 class="text-3xl font-bold text-brand-slate-900">0</h3>
            <span class="text-sm font-medium text-brand-slate-400">
              No active emergencies
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Recent Rides Table -->
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <div class="p-6 border-b border-brand-slate-100 flex items-center justify-between">
        <h2 class="text-lg font-bold text-brand-slate-900">Recent Rides</h2>
        <div class="relative">
          <span class="absolute inset-y-0 right-3 flex items-center pointer-events-none text-brand-slate-400">
            <Search class="w-4 h-4" />
          </span>
          <input type="text" placeholder="Search..." class="pl-4 pr-10 py-2 border border-brand-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-blue-base focus:border-transparent w-64 bg-brand-slate-50">
        </div>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-brand-slate-50 text-brand-slate-500 text-xs uppercase tracking-wider">
              <th class="px-6 py-4 font-semibold">Passenger</th>
              <th class="px-6 py-4 font-semibold">Driver</th>
              <th class="px-6 py-4 font-semibold">Fare</th>
              <th class="px-6 py-4 font-semibold">Status</th>
              <th class="px-6 py-4 font-semibold">Time</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-brand-slate-100 text-sm">
            <tr v-for="ride in recentRides" :key="ride.id" class="hover:bg-brand-slate-50 transition-colors">
              <td class="px-6 py-4 text-brand-slate-900">{{ ride.customerName }}</td>
              <td class="px-6 py-4 text-brand-slate-600">{{ ride.driverName || 'Unassigned' }}</td>
              <td class="px-6 py-4 text-brand-blue-base font-medium">₱{{ ride.fareEstimate.toFixed(0) }}</td>
              <td class="px-6 py-4">
                <span class="px-3 py-1 rounded-full text-xs font-semibold" :class="getStatusClass(ride.status)">
                  {{ getStatusText(ride.status) }}
                </span>
              </td>
              <td class="px-6 py-4 text-brand-slate-500">{{ ride.time || 'N/A' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <button class="w-full bg-brand-blue-base hover:bg-brand-blue-dark text-white rounded-xl py-4 px-6 flex items-center justify-center gap-3 font-semibold transition-all">
        <Settings class="w-5 h-5" />
        Update Fare Matrix
      </button>
      <button class="w-full bg-gradient-to-r from-brand-purple-base to-[#9333EA] hover:from-[#9333EA] hover:to-purple-700 text-white rounded-xl py-4 px-6 flex items-center justify-center gap-3 font-semibold transition-all">
        <Bell class="w-5 h-5" />
        Send Announcement
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { useApi } from '@/composables/useApi';
import { Bike, DollarSign, CheckCircle, AlertTriangle, Search, Settings, Bell } from '@lucide/vue';

const api = useApi();
const recentRides = ref<any[]>([]);
const activeDriversCount = ref(0);
const totalRevenueAmount = ref(0);
const completedTripsCount = ref(0);

const currentDate = computed(() => {
  return new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });
});

onMounted(async () => {
  try {
    const res = await api.get('/rides');
    const data = res.data.data || [];
    recentRides.value = data.slice(0, 5);
    completedTripsCount.value = data.filter(
      (r: any) => r.status === 'completed'
    ).length;
    totalRevenueAmount.value = data.reduce(
      (sum: number, r: any) => sum + (r.fareEstimate || 0),
      0
    );
  } catch {
    recentRides.value = [];
  }

  try {
    const driversRes = await api.get('/drivers');
    activeDriversCount.value = (driversRes.data.data || []).filter(
      (d: any) => d.isOnline
    ).length;
  } catch {}
});

const getStatusClass = (status: string) => {
  switch (status) {
    case 'completed': return 'bg-green-100 text-green-700';
    case 'in_transit': return 'bg-amber-100 text-amber-700';
    case 'cancelled': return 'bg-red-100 text-red-700';
    default: return 'bg-brand-slate-100 text-brand-slate-700';
  }
};

const getStatusText = (status: string) => {
  switch (status) {
    case 'completed': return 'Completed';
    case 'in_transit': return 'In Transit';
    case 'cancelled': return 'Cancelled';
    default: return status;
  }
};
</script>
