<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div class="flex items-center justify-between w-full">
          <div>
            <h2 class="text-lg font-bold text-brand-slate-900">Active Tricycle Drivers</h2>
            <p class="text-xs text-brand-slate-500">Manage online statuses, driver profiles, and suspensions</p>
          </div>
        </div>
      </template>

      <AppTable>
        <template #headers>
          <th class="p-3">Driver Name</th>
          <th class="p-3">Phone Number</th>
          <th class="p-3">Plate Number</th>
          <th class="p-3">Rating</th>
          <th class="p-3">Total Rides</th>
          <th class="p-3">Online Status</th>
          <th class="p-3 text-right">Actions</th>
        </template>
        <template #rows>
          <tr v-for="driver in drivers" :key="driver.id" class="hover:bg-brand-slate-50/50">
            <td class="p-3 font-semibold text-brand-slate-900">{{ driver.userName || 'Juan Dela Cruz' }}</td>
            <td class="p-3 text-xs font-mono text-brand-slate-700">{{ driver.userPhone || '+639171112233' }}</td>
            <td class="p-3 text-xs font-mono text-brand-slate-700">{{ driver.tricyclePlateNumber }}</td>
            <td class="p-3 font-bold text-amber-600">⭐ {{ driver.averageRating.toFixed(1) }}</td>
            <td class="p-3 text-brand-slate-900 font-semibold">{{ driver.totalRides }} rides</td>
            <td class="p-3">
              <AppBadge :variant="driver.isOnline ? 'success' : 'neutral'">
                {{ driver.isOnline ? 'ONLINE' : 'OFFLINE' }}
              </AppBadge>
            </td>
            <td class="p-3 text-right">
              <AppButton size="sm" :variant="driver.applicationStatus === 'suspended' ? 'secondary' : 'danger'" @click="toggleSuspend(driver)">
                {{ driver.applicationStatus === 'suspended' ? 'Reactivate' : 'Suspend' }}
              </AppButton>
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
import AppButton from '@/components/ui/AppButton.vue';
import { useApi } from '@/composables/useApi';

const api = useApi();
const drivers = ref<any[]>([]);

const fetchDrivers = async () => {
  try {
    const res = await api.get('/drivers');
    drivers.value = res.data.data;
  } catch {
    drivers.value = [];
  }
};

onMounted(fetchDrivers);

const toggleSuspend = async (driver: any) => {
  const newStatus = driver.applicationStatus === 'suspended' ? 'approved' : 'suspended';
  try {
    await api.patch(`/drivers/${driver.id}/status`, { status: newStatus });
    fetchDrivers();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Status update failed');
  }
};
</script>
