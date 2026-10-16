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
          <tr v-for="ride in pageItems" :key="ride.id" class="hover:bg-brand-slate-50/50">
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
          <tr v-if="pageItems.length === 0">
            <td colspan="7" class="p-8 text-center text-sm text-brand-slate-500">
              No rides found.
            </td>
          </tr>
        </template>
      </AppTable>

      <AppPagination v-model:page="page" v-model:page-size="pageSize" :total="totalItems" />
    </AppCard>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import AppTable from '@/components/ui/AppTable.vue';
import AppBadge from '@/components/ui/AppBadge.vue';
import AppPagination from '@/components/ui/AppPagination.vue';
import { useApi } from '@/composables/useApi';
import { usePagination } from '@/composables/usePagination';

const api = useApi();
const rides = ref<any[]>([]);

// The list endpoint returns every ride; paging happens in the browser.
const { page, pageSize, pageItems, totalItems } = usePagination(rides);

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
