<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div class="flex items-center justify-between w-full">
          <div>
            <h2 class="text-lg font-bold text-brand-slate-900">Municipality Jurisdictions & Service Boundaries</h2>
            <p class="text-xs text-brand-slate-500">Configure custom polygon boundary geometries and fare matrices per municipality</p>
          </div>
          <AppButton variant="primary" size="sm" @click="openCreateModal">
            + Add Municipality
          </AppButton>
        </div>
      </template>

      <AppTable>
        <template #headers>
          <th class="p-3">Municipality Name</th>
          <th class="p-3">Province</th>
          <th class="p-3">Center Lat / Lng</th>
          <th class="p-3">Polygon Boundary</th>
          <th class="p-3">Base Fare</th>
          <th class="p-3">Per KM Rate</th>
          <th class="p-3 text-right">Actions</th>
        </template>
        <template #rows>
          <tr v-for="muni in pageItems" :key="muni.id" class="hover:bg-brand-slate-50/50">
            <td class="p-3 font-bold text-brand-slate-900">{{ muni.name }}</td>
            <td class="p-3 text-brand-slate-600">{{ muni.province || 'Bukidnon' }}</td>
            <td class="p-3 text-xs font-mono text-brand-slate-500">{{ muni.centerLat?.toFixed(4) }}, {{ muni.centerLng?.toFixed(4) }}</td>
            <td class="p-3">
              <span
                v-if="muni.boundaryGeojson"
                class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-blue-100 text-blue-700 border border-blue-200"
              >
                ✏️ Custom Polygon
              </span>
              <span
                v-else
                class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-brand-slate-100 text-brand-slate-600 border border-brand-slate-200"
              >
                Draft (0 points)
              </span>
            </td>
            <td class="p-3 font-bold text-brand-slate-900">₱{{ muni.baseFare?.toFixed(2) }}</td>
            <td class="p-3 font-bold text-emerald-600">₱{{ muni.perKmRate?.toFixed(2) }}/km</td>
            <td class="p-3 text-right">
              <div class="inline-flex items-center gap-2">
                <AppButton size="sm" variant="outline" @click="openEditBoundaryModal(muni)">
                  🗺️ Map Boundary
                </AppButton>
                <AppButton size="sm" variant="ghost" @click="openEditFareModal(muni)">
                  ⚙️ Fare
                </AppButton>
              </div>
            </td>
          </tr>
          <tr v-if="pageItems.length === 0">
            <td colspan="7" class="p-8 text-center text-sm text-brand-slate-500">
              No municipalities configured yet.
            </td>
          </tr>
        </template>
      </AppTable>

      <AppPagination v-model:page="page" v-model:page-size="pageSize" :total="totalItems" />
    </AppCard>

    <!-- Create Municipality & Boundary Modal -->
    <AppModal :is-open="isCreateModalOpen" title="Create New Municipality Jurisdiction" size="xl" @close="isCreateModalOpen = false">
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <AppInput v-model="createForm.name" label="Municipality Name" placeholder="e.g. Malaybalay City" />
          <AppInput v-model="createForm.province" label="Province" placeholder="e.g. Bukidnon" />
        </div>

        <!-- Interactive Mapbox Boundary Mapper -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold text-brand-slate-700 uppercase tracking-wider">
            Polygon Boundary Geometry (Click map to add corner points)
          </label>
          <MunicipalityBoundaryMapper
            v-model="createBoundaryData"
            :municipality-name="createForm.name"
          />
        </div>

        <div class="grid grid-cols-2 gap-3">
          <AppInput v-model.number="createBoundaryData.centerLat" label="Centroid Latitude" type="number" step="any" readonly />
          <AppInput v-model.number="createBoundaryData.centerLng" label="Centroid Longitude" type="number" step="any" readonly />
        </div>

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

    <!-- Edit Municipality & Boundary Geometry Modal -->
    <AppModal :is-open="isEditBoundaryModalOpen" title="Edit Jurisdiction Polygon Boundary" size="xl" @close="isEditBoundaryModalOpen = false">
      <div v-if="selectedMuni" class="space-y-4">
        <div class="grid grid-cols-2 gap-3">
          <AppInput v-model="editInfoForm.name" label="Municipality Name" />
          <AppInput v-model="editInfoForm.province" label="Province" />
        </div>

        <!-- Interactive Mapbox Boundary Mapper -->
        <div class="space-y-1.5">
          <label class="block text-xs font-bold text-brand-slate-700 uppercase tracking-wider">
            Polygon Boundary Geometry (Click map to add corner vertices)
          </label>
          <MunicipalityBoundaryMapper
            v-model="editBoundaryData"
            :municipality-name="editInfoForm.name"
          />
        </div>

        <div class="grid grid-cols-2 gap-3">
          <AppInput v-model.number="editBoundaryData.centerLat" label="Centroid Latitude" type="number" step="any" readonly />
          <AppInput v-model.number="editBoundaryData.centerLng" label="Centroid Longitude" type="number" step="any" readonly />
        </div>
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="isEditBoundaryModalOpen = false">Cancel</AppButton>
        <AppButton variant="primary" :loading="editLoading" @click="handleUpdateBoundary">Save Boundary Polygon</AppButton>
      </template>
    </AppModal>

    <!-- Edit Fare Config Modal -->
    <AppModal :is-open="isEditFareModalOpen" title="Update Fare Configuration Matrix" @close="isEditFareModalOpen = false">
      <div v-if="selectedMuni" class="space-y-4">
        <p class="text-sm font-semibold text-brand-slate-900">{{ selectedMuni.name }} Jurisdiction</p>
        <AppInput v-model.number="editFareForm.baseFare" label="Base Fare (₱)" type="number" step="any" />
        <AppInput v-model.number="editFareForm.perKmRate" label="Per KM Rate (₱)" type="number" step="any" />
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="isEditFareModalOpen = false">Cancel</AppButton>
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
import AppPagination from '@/components/ui/AppPagination.vue';
import MunicipalityBoundaryMapper from './MunicipalityBoundaryMapper.vue';
import { useApi } from '@/composables/useApi';
import { usePagination } from '@/composables/usePagination';

const api = useApi();
const municipalities = ref<any[]>([]);

// The list endpoint returns every jurisdiction; paging happens in the browser.
const { page, pageSize, pageItems, totalItems } = usePagination(municipalities);
const isCreateModalOpen = ref(false);
const isEditBoundaryModalOpen = ref(false);
const isEditFareModalOpen = ref(false);
const createLoading = ref(false);
const editLoading = ref(false);

const selectedMuni = ref<any>(null);

const createForm = ref({
  name: '',
  province: 'Bukidnon',
  baseFare: 30.0,
  perKmRate: 10.0,
});

const createBoundaryData = ref({
  centerLat: 8.1575,
  centerLng: 125.1278,
  radiusKm: 10.0,
  boundaryGeojson: null as any,
});

const editInfoForm = ref({
  name: '',
  province: '',
});

const editBoundaryData = ref({
  centerLat: 8.1575,
  centerLng: 125.1278,
  radiusKm: 10.0,
  boundaryGeojson: null as any,
});

const editFareForm = ref({
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

const openCreateModal = () => {
  createForm.value = {
    name: '',
    province: 'Bukidnon',
    baseFare: 30.0,
    perKmRate: 10.0,
  };
  // Start with 0 points
  createBoundaryData.value = {
    centerLat: 8.1575,
    centerLng: 125.1278,
    radiusKm: 10.0,
    boundaryGeojson: null,
  };
  isCreateModalOpen.value = true;
};

const handleCreate = async () => {
  if (!createBoundaryData.value.boundaryGeojson) {
    alert('Please click on the map to define a polygon boundary with at least 3 points.');
    return;
  }
  createLoading.value = true;
  try {
    const payload = {
      ...createForm.value,
      ...createBoundaryData.value,
    };
    await api.post('/municipalities', payload);
    isCreateModalOpen.value = false;
    await fetchMunicipalities();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Creation failed');
  } finally {
    createLoading.value = false;
  }
};

const openEditBoundaryModal = (muni: any) => {
  selectedMuni.value = muni;
  editInfoForm.value = {
    name: muni.name,
    province: muni.province || '',
  };
  editBoundaryData.value = {
    centerLat: muni.centerLat,
    centerLng: muni.centerLng,
    radiusKm: muni.radiusKm || 10.0,
    boundaryGeojson: muni.boundaryGeojson
      ? JSON.parse(JSON.stringify(muni.boundaryGeojson))
      : null,
  };
  isEditBoundaryModalOpen.value = true;
};

const handleUpdateBoundary = async () => {
  if (!selectedMuni.value) return;
  editLoading.value = true;
  try {
    const payload = {
      name: editInfoForm.value.name,
      province: editInfoForm.value.province || null,
      centerLat: editBoundaryData.value.centerLat,
      centerLng: editBoundaryData.value.centerLng,
      radiusKm: editBoundaryData.value.radiusKm || 10.0,
      boundaryGeojson: editBoundaryData.value.boundaryGeojson,
    };
    await api.patch(`/municipalities/${selectedMuni.value.id}`, payload);
    isEditBoundaryModalOpen.value = false;
    await fetchMunicipalities();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Update failed');
  } finally {
    editLoading.value = false;
  }
};

const openEditFareModal = (muni: any) => {
  selectedMuni.value = muni;
  editFareForm.value = {
    baseFare: muni.baseFare,
    perKmRate: muni.perKmRate,
  };
  isEditFareModalOpen.value = true;
};

const handleUpdateFare = async () => {
  if (!selectedMuni.value) return;
  editLoading.value = true;
  try {
    await api.patch(`/municipalities/${selectedMuni.value.id}/fare-config`, editFareForm.value);
    isEditFareModalOpen.value = false;
    await fetchMunicipalities();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Update failed');
  } finally {
    editLoading.value = false;
  }
};
</script>
