<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div>
          <h2 class="text-lg font-bold text-brand-slate-900">Pending Driver Verification Applications</h2>
          <p class="text-xs text-brand-slate-500">Review driver submitted credentials, license, and tricycle registration</p>
        </div>
      </template>

      <AppTable>
        <template #headers>
          <th class="p-3">Applicant Name</th>
          <th class="p-3">License No.</th>
          <th class="p-3">Plate No.</th>
          <th class="p-3">Municipality</th>
          <th class="p-3">Status</th>
          <th class="p-3 text-right">Actions</th>
        </template>
        <template #rows>
          <tr v-for="app in applications" :key="app.id" class="hover:bg-brand-slate-50/50">
            <td class="p-3 font-semibold text-brand-slate-900">{{ app.userName || 'Juan Dela Cruz' }}</td>
            <td class="p-3 font-mono text-xs text-brand-slate-700">{{ app.licenseNumber }}</td>
            <td class="p-3 font-mono text-xs text-brand-slate-700">{{ app.tricyclePlateNumber }}</td>
            <td class="p-3 text-brand-slate-700">{{ app.municipalityName || 'Malaybalay City' }}</td>
            <td class="p-3">
              <AppBadge :variant="app.applicationStatus === 'approved' ? 'success' : app.applicationStatus === 'rejected' ? 'danger' : 'warning'">
                {{ app.applicationStatus }}
              </AppBadge>
            </td>
            <td class="p-3 text-right flex justify-end gap-2">
              <AppButton size="sm" variant="secondary" @click="handleApprove(app.id)">
                ✓ Approve
              </AppButton>
              <AppButton size="sm" variant="danger" @click="openRejectModal(app)">
                ✕ Reject
              </AppButton>
            </td>
          </tr>
          <tr v-if="applications.length === 0">
            <td colspan="6" class="p-8 text-center text-sm text-brand-slate-500">
              No pending driver verification applications at this time.
            </td>
          </tr>
        </template>
      </AppTable>
    </AppCard>

    <!-- Reject Reason Modal -->
    <AppModal :is-open="isRejectModalOpen" title="Reject Driver Application" @close="isRejectModalOpen = false">
      <div class="space-y-4">
        <p class="text-sm text-brand-slate-600">Please state the rejection reason to notify the applicant:</p>
        <AppInput v-model="rejectReason" label="Rejection Reason" placeholder="Invalid license or missing clear document photo" />
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="isRejectModalOpen = false">Cancel</AppButton>
        <AppButton variant="danger" :loading="actionLoading" @click="confirmReject">Confirm Rejection</AppButton>
      </template>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import AppTable from '@/components/ui/AppTable.vue';
import AppBadge from '@/components/ui/AppBadge.vue';
import AppButton from '@/components/ui/AppButton.vue';
import AppModal from '@/components/ui/AppModal.vue';
import AppInput from '@/components/ui/AppInput.vue';
import { useApi } from '@/composables/useApi';

const api = useApi();
const applications = ref<any[]>([]);
const isRejectModalOpen = ref(false);
const selectedApp = ref<any>(null);
const rejectReason = ref('');
const actionLoading = ref(false);

const fetchApplications = async () => {
  try {
    const res = await api.get('/drivers/applications');
    applications.value = res.data.data;
  } catch {
    applications.value = [];
  }
};

onMounted(fetchApplications);

const handleApprove = async (id: string) => {
  try {
    await api.patch(`/drivers/applications/${id}/approve`);
    fetchApplications();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Approval failed');
  }
};

const openRejectModal = (app: any) => {
  selectedApp.value = app;
  rejectReason.value = '';
  isRejectModalOpen.value = true;
};

const confirmReject = async () => {
  if (!selectedApp.value || !rejectReason.value) return;
  actionLoading.value = true;
  try {
    await api.patch(`/drivers/applications/${selectedApp.value.id}/reject`, { reason: rejectReason.value });
    isRejectModalOpen.value = false;
    fetchApplications();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Rejection failed');
  } finally {
    actionLoading.value = false;
  }
};
</script>
