<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div class="flex items-center justify-between w-full">
          <div>
            <h2 class="text-lg font-bold text-brand-slate-900">Registered User Accounts</h2>
            <p class="text-xs text-brand-slate-500">System user directory including passengers, drivers, and admin accounts</p>
          </div>
        </div>
      </template>

      <AppTable>
        <template #headers>
          <th class="p-3">User ID</th>
          <th class="p-3">Full Name</th>
          <th class="p-3">Email Address</th>
          <th class="p-3">Phone Number</th>
          <th class="p-3">Role</th>
        </template>
        <template #rows>
          <tr v-for="user in pageItems" :key="user.id" class="hover:bg-brand-slate-50/50">
            <td class="p-3 font-mono text-xs text-brand-slate-500">{{ user.id.slice(0, 8) }}...</td>
            <td class="p-3 font-semibold text-brand-slate-900">{{ user.firstName }} {{ user.lastName }}</td>
            <td class="p-3 text-brand-slate-700">{{ user.email }}</td>
            <td class="p-3 font-mono text-xs text-brand-slate-700">{{ user.phone }}</td>
            <td class="p-3">
              <AppBadge :variant="user.role === 'admin' ? 'danger' : user.role === 'driver' ? 'warning' : 'info'">
                {{ user.role }}
              </AppBadge>
            </td>
          </tr>
          <tr v-if="pageItems.length === 0">
            <td colspan="5" class="p-8 text-center text-sm text-brand-slate-500">
              No user accounts found.
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
const users = ref<any[]>([]);

// The list endpoint returns every account; paging happens in the browser.
const { page, pageSize, pageItems, totalItems } = usePagination(users);

onMounted(async () => {
  try {
    const res = await api.get('/users');
    users.value = res.data.data;
  } catch {
    users.value = [];
  }
});
</script>
