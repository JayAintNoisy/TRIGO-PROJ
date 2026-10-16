<template>
  <div class="space-y-6">
    <AppCard>
      <template #header>
        <div>
          <h2 class="text-lg font-bold text-brand-slate-900">Driver Verification Applications</h2>
          <p class="text-xs text-brand-slate-500">Review submitted credentials, license, tricycle registration, and documents</p>
        </div>
      </template>

      <!-- Status filter -->
      <div class="flex flex-wrap gap-2 mb-4">
        <button
          v-for="filter in statusFilters"
          :key="filter.value"
          class="px-3 py-1.5 rounded-full text-xs font-semibold transition-colors"
          :class="activeFilter === filter.value
            ? 'bg-brand-blue-600 text-white'
            : 'bg-brand-slate-100 text-brand-slate-600 hover:bg-brand-slate-200'"
          @click="setFilter(filter.value)"
        >
          {{ filter.label }}
        </button>
      </div>

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
          <tr v-for="app in pageItems" :key="app.id" class="hover:bg-brand-slate-50/50">
            <td class="p-3 font-semibold text-brand-slate-900">{{ app.userName || 'Juan Dela Cruz' }}</td>
            <td class="p-3 font-mono text-xs text-brand-slate-700">{{ app.licenseNumber }}</td>
            <td class="p-3 font-mono text-xs text-brand-slate-700">{{ app.tricyclePlateNumber }}</td>
            <td class="p-3 text-brand-slate-700">{{ app.municipalityName || '—' }}</td>
            <td class="p-3">
              <AppBadge :variant="statusVariant(app.applicationStatus)">
                {{ statusLabel(app.applicationStatus) }}
              </AppBadge>
            </td>
            <td class="p-3 text-right">
              <div class="flex justify-end gap-2">
                <AppButton size="sm" variant="secondary" @click="openDocumentsModal(app)">
                  Documents
                </AppButton>
                <AppButton v-if="app.applicationStatus === 'pending'" size="sm" variant="ghost" @click="handleStartReview(app)">
                  Start Review
                </AppButton>
                <AppButton
                  v-if="['pending', 'reviewing'].includes(app.applicationStatus)"
                  size="sm" variant="primary"
                  @click="handleApprove(app.id)"
                >
                  ✓ Approve
                </AppButton>
                <AppButton
                  v-if="['pending', 'reviewing'].includes(app.applicationStatus)"
                  size="sm" variant="danger"
                  @click="openRejectModal(app)"
                >
                  ✕ Decline
                </AppButton>
              </div>
            </td>
          </tr>
          <tr v-if="pageItems.length === 0">
            <td colspan="6" class="p-8 text-center text-sm text-brand-slate-500">
              No applications match this filter.
            </td>
          </tr>
        </template>
      </AppTable>

      <AppPagination v-model:page="page" v-model:page-size="pageSize" :total="totalItems" />
    </AppCard>

    <!-- Reject Reason Modal -->
    <AppModal :is-open="isRejectModalOpen" title="Decline Driver Application" @close="isRejectModalOpen = false">
      <div class="space-y-4">
        <p class="text-sm text-brand-slate-600">Please state the decline reason so the applicant can correct and resubmit:</p>
        <AppInput v-model="rejectReason" label="Decline Reason" placeholder="Invalid license or missing clear document photo" />
      </div>
      <template #footer>
        <AppButton variant="ghost" @click="isRejectModalOpen = false">Cancel</AppButton>
        <AppButton variant="danger" :loading="actionLoading" @click="confirmReject">Confirm Decline</AppButton>
      </template>
    </AppModal>

    <!-- Documents Viewer Modal -->
    <AppModal :is-open="isDocumentsModalOpen" title="Submitted Documents" @close="isDocumentsModalOpen = false">
      <div v-if="documentsLoading" class="py-8 text-center text-sm text-brand-slate-500">Loading documents…</div>
      <div v-else-if="viewedDocuments.length === 0" class="py-8 text-center text-sm text-brand-slate-500">
        No documents were attached to this application.
      </div>
      <div v-else class="space-y-4 max-h-[60vh] overflow-y-auto">
        <div v-for="doc in viewedDocuments" :key="doc.documentUrl" class="space-y-1">
          <div class="flex items-center justify-between">
            <span class="text-xs font-bold uppercase tracking-wide text-brand-slate-700">{{ prettyDocType(doc.documentType) }}</span>
            <a :href="doc.objectUrl" target="_blank" rel="noopener" class="text-xs font-semibold text-brand-blue-600 hover:underline">Open full size</a>
          </div>
          <img
            v-if="doc.kind === 'image'"
            :src="doc.objectUrl"
            :alt="prettyDocType(doc.documentType)"
            class="w-full rounded-lg border border-brand-slate-200 bg-brand-slate-50 object-contain max-h-72"
          />
          <div v-else class="rounded-lg border border-brand-slate-200 bg-brand-slate-50 p-4 text-sm text-brand-slate-600">
            PDF document — use "Open full size" to view.
          </div>
        </div>
      </div>
    </AppModal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import AppTable from '@/components/ui/AppTable.vue';
import AppBadge from '@/components/ui/AppBadge.vue';
import AppButton from '@/components/ui/AppButton.vue';
import AppModal from '@/components/ui/AppModal.vue';
import AppInput from '@/components/ui/AppInput.vue';
import AppPagination from '@/components/ui/AppPagination.vue';
import { useApi } from '@/composables/useApi';
import { usePagination } from '@/composables/usePagination';

const api = useApi();
const applications = ref<any[]>([]);
const activeFilter = ref('all');
const isRejectModalOpen = ref(false);
const selectedApp = ref<any>(null);
const rejectReason = ref('');
const actionLoading = ref(false);

const isDocumentsModalOpen = ref(false);
const documentsLoading = ref(false);
const viewedDocuments = ref<Array<{ documentType: string; documentUrl: string; kind: 'image' | 'pdf'; objectUrl: string }>>([]);

const statusFilters = [
  { value: 'all', label: 'All' },
  { value: 'pending', label: 'For Review' },
  { value: 'reviewing', label: 'Reviewing' },
  { value: 'approved', label: 'Approved' },
  { value: 'rejected', label: 'Declined' },
];

// Documents live on the detail payload; the list rows carry them too when present
const filteredApplications = computed(() =>
  activeFilter.value === 'all'
    ? applications.value
    : applications.value.filter((a) => a.applicationStatus === activeFilter.value)
);

// Page the filtered result set; changing the filter returns to the first page.
const { page, pageSize, pageItems, totalItems, reset: resetPage } = usePagination(filteredApplications);

function setFilter(value: string) {
  activeFilter.value = value;
  resetPage();
}

function statusLabel(status: string): string {
  switch (status) {
    case 'reviewing': return 'Reviewing';
    case 'approved': return 'Approved';
    case 'rejected': return 'Declined';
    case 'suspended': return 'Suspended';
    default: return 'For Review';
  }
}

function statusVariant(status: string): 'success' | 'warning' | 'danger' | 'info' {
  switch (status) {
    case 'approved': return 'success';
    case 'rejected': return 'danger';
    case 'suspended': return 'danger';
    case 'reviewing': return 'info';
    default: return 'warning';
  }
}

function prettyDocType(type: string): string {
  return type.replace(/_/g, ' ');
}

function docKind(url: string): 'image' | 'pdf' {
  return url.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image';
}

/** Fetch each document as an authenticated blob so reviewers see real evidence */
async function openDocumentsModal(app: any) {
  isDocumentsModalOpen.value = true;
  documentsLoading.value = true;
  let docs: any[] = app.documents ?? [];
  if (docs.length === 0 && app.id) {
    try {
      const res = await api.get(`/drivers/applications/${app.id}`);
      docs = res.data.data?.documents ?? [];
    } catch {
      docs = [];
    }
  }
  const loaded: typeof viewedDocuments.value = [];
  for (const doc of docs) {
    try {
      // Stored URLs are /uploads/...; the api client's baseURL already ends in /api
      const response = await api.get(doc.documentUrl, { responseType: 'blob' });
      const contentType = String(response.headers['content-type'] ?? 'application/octet-stream');
      const blob = new Blob([response.data], { type: contentType });
      loaded.push({
        documentType: doc.documentType,
        documentUrl: doc.documentUrl,
        kind: docKind(doc.documentUrl),
        objectUrl: URL.createObjectURL(blob),
      });
    } catch {
      // Skip unreadable files rather than blocking the rest
    }
  }
  viewedDocuments.value = loaded;
  documentsLoading.value = false;
}

function revokeObjectUrls() {
  for (const doc of viewedDocuments.value) URL.revokeObjectURL(doc.objectUrl);
  viewedDocuments.value = [];
}

const fetchApplications = async () => {
  try {
    const res = await api.get('/drivers/applications');
    applications.value = res.data.data;
  } catch {
    applications.value = [];
  }
};

onMounted(fetchApplications);
onUnmounted(revokeObjectUrls);

const handleStartReview = async (app: any) => {
  try {
    await api.patch(`/drivers/applications/${app.id}/review`);
    fetchApplications();
  } catch (err: any) {
    alert(err.response?.data?.error?.message || 'Failed to start review');
  }
};

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
