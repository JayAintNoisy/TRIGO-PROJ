<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div class="flex items-center justify-between w-full">
          <div>
            <h2 class="text-lg font-bold text-brand-slate-900">All Tricycle Rides</h2>
            <p class="text-xs text-brand-slate-500">Monitor active, completed, and cancelled bookings</p>
          </div>
        </div>
      </template>

      <AppTable>
        <template #headers>
          <th class="p-3">Ride ID</th>
          <th class="p-3">Customer</th>
          <th class="p-3">Driver</th>
          <th class="p-3">Pickup Address</th>
          <th class="p-3">Dropoff Address</th>
          <th class="p-3">Est. Fare</th>
          <th class="p-3">Status</th>
        </template>
        <template #rows>
          <tr v-for="ride in rides" :key="ride.id" class="hover:bg-brand-slate-50/50">
            <td class="p-3 font-mono text-xs text-brand-slate-500">{{ ride.id.slice(0, 8) }}...</td>
            <td class="p-3 font-semibold text-brand-slate-900">{{ ride.customerName || 'Customer' }}</td>
            <td class="p-3 text-brand-slate-700">{{ ride.driverName || 'Unassigned' }}</td>
            <td class="p-3 text-xs text-brand-slate-600">{{ ride.pickupAddress }}</td>
            <td class="p-3 text-xs text-brand-slate-600">{{ ride.dropoffAddress }}</td>
            <td class="p-3 font-bold text-brand-slate-900">₱{{ ride.fareEstimate?.toFixed(2) }}</td>
            <td class="p-3">
              <AppBadge :variant="getStatusBadge(ride.status)">{{ ride.status }}</AppBadge>
            </td>
          </tr>
        </template>
      </AppTable>
    </AppCard>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import AppTable from '@/components/ui/AppTable.vue';
import AppBadge from '@/components/ui/AppBadge.vue';
import { useApi } from '@/composables/useApi';

const api = useApi();
const rides = ref<any[]>([]);

onMounted(async () => {
  try {
    const res = await api.get('/rides');
    rides.value = res.data.data;
  } catch {
    rides.value = [];
  }
});

const getStatusBadge = (status: string) => {
  switch (status) {
    case 'completed': return 'success';
    case 'in_progress': return 'warning';
    case 'requested': return 'info';
    case 'cancelled': return 'danger';
    default: return 'neutral';
  }
};
</script>
