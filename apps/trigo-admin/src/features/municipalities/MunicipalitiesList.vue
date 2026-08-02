<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div class="flex items-center justify-between w-full">
          <div>
            <h2 class="text-lg font-bold text-brand-slate-900">Municipality Jurisdictions & Fare Matrix</h2>
            <p class="text-xs text-brand-slate-500">Configure base fares, per-km rates, and service boundary radius per municipality</p>
          </div>
          <AppButton variant="primary" size="sm" @click="isCreateModalOpen = true">
            + Add Municipality
          </AppButton>
        </div>
      </template>

      <AppTable>
        <template #headers>
          <th class="p-3">Municipality Name</th>
          <th class="p-3">Province</th>
          <th class="p-3">Center Lat / Lng</th>
          <th class="p-3">Radius Boundary</th>
          <th class="p-3">Base Fare</th>
          <th class="p-3">Per KM Rate</th>
          <th class="p-3 text-right">Actions</th>
        </template>
        <template #rows>
          <tr v-for="muni in municipalities" :key="muni.id" class="hover:bg-brand-slate-50/50">
            <td class="p-3 font-bold text-brand-slate-900">{{ muni.name }}</td>
            <td class="p-3 text-brand-slate-600">{{ muni.province || 'Bukidnon' }}</td>
            <td class="p-3 text-xs font-mono text-brand-slate-500">{{ muni.centerLat }}, {{ muni.centerLng }}</td>
            <td class="p-3 font-semibold text-brand-blue-base">{{ muni.radiusKm }} km</td>
            <td class="p-3 font-bold text-brand-slate-900">₱{{ muni.baseFare?.toFixed(2) }}</td>
            <td class="p-3 font-bold text-emerald-600">₱{{ muni.perKmRate?.toFixed(2) }}/km</td>
            <td class="p-3 text-right">
              <AppButton size="sm" variant="outline" @click="openEditModal(muni)">
                ⚙️ Edit Fare
              </AppButton>
            </td>
          </tr>
        </template>
      </AppTable>
    </AppCard>

    <!-- Create Municipality Modal -->
    <AppModal :is-open="isCreateModalOpen" title="Create New Municipality Jurisdiction" @close="isCreateModalOpen = false">
      <div class="space-y-4">
        <AppInput v-model="createForm.name" label="Municipality Name" placeholder="e.g. Malaybalay City" />
        <AppInput v-model="createForm.province" label="Province" placeholder="e.g. Bukidnon" />
        <div class="grid grid-cols-2 gap-3">
          <AppInput v-model.number="createForm.centerLat" label="Center Latitude" placeholder="8.1575" type="number" step="any" />
          <AppInput v-model.number="createForm.centerLng" label="Center Longitude" placeholder="125.1278" type="number" step="any" />
        </div>
        <AppInput v-model.number="createForm.radiusKm" label="Boundary Radius (km)" placeholder="15" type="number" />
        <div class="grid grid-cols-2 gap-3">
          <AppInput v-model.number="createForm.baseFare" label="Base Fare (₱)" placeholder="30.00" type="number" />
          <AppInput v-model.number="createForm.perKmRate" label="Per KM Rate (₱)" placeholder="10.00" type="number" />
        </div>
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="isCreateModalOpen = false">Cancel</AppButton>
        <AppButton variant="primary" :loading="createLoading" @click="handleCreate">Create Municipality</AppButton>
      </template>
    </AppModal>

    <!-- Edit Fare Config Modal -->
    <AppModal :is-open="isEditModalOpen" title="Update Fare Configuration Matrix" @close="isEditModalOpen = false">
      <div v-if="selectedMuni" class="space-y-4">
        <p class="text-sm font-semibold text-brand-slate-900">{{ selectedMuni.name }} Jurisdiction</p>
        <AppInput v-model.number="editForm.baseFare" label="Base Fare (₱)" type="number" step="any" />
        <AppInput v-model.number="editForm.perKmRate" label="Per KM Rate (₱)" type="number" step="any" />
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="isEditModalOpen = false">Cancel</AppButton>
        <AppButton variant="primary" :loading="editLoading" @click="handleUpdateFare">Save Fare Changes</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import AppTable from '@/components/ui/AppTable.vue';
import AppButton from '@/components/ui/AppButton.vue';
import AppModal from '@/components/ui/AppModal.vue';
import AppInput from '@/components/ui/AppInput.vue';
import { useApi } from '@/composables/useApi';

const api = useApi();
const municipalities = ref<any[]>([]);
const isCreateModalOpen = ref(false);
const isEditModalOpen = ref(false);
const createLoading = ref(false);
const editLoading = ref(false);

const selectedMuni = ref<any>(null);

const createForm = ref({
  name: '',
  province: 'Bukidnon',
  centerLat: 8.1575,
  centerLng: 125.1278,
  radiusKm: 15,
  baseFare: 30.0,
  perKmRate: 10.0,
});

const editForm = ref({
  baseFare: 30.0,
  perKmRate: 10.0,
});

const fetchMunicipalities = async () => {
  try {
    const res = await api.get('/municipalities');
    municipalities.value = res.data.data;
  } catch {
    municipalities.value = [];
  }
};

onMounted(fetchMunicipalities);

const handleCreate = async () => {
  createLoading.value = true;
  try {
    await api.post('/municipalities', createForm.value);
    isCreateModalOpen.value = false;
    fetchMunicipalities();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Creation failed');
  } finally {
    createLoading.value = false;
  }
};

const openEditModal = (muni: any) => {
  selectedMuni.value = muni;
  editForm.value = {
    baseFare: muni.baseFare,
    perKmRate: muni.perKmRate,
  };
  isEditModalOpen.value = true;
};

const handleUpdateFare = async () => {
  if (!selectedMuni.value) return;
  editLoading.value = true;
  try {
    await api.patch(`/municipalities/${selectedMuni.value.id}/fare-config`, editForm.value);
    isEditModalOpen.value = false;
    fetchMunicipalities();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Update failed');
  } finally {
    editLoading.value = false;
  }
};
</script>
