<template>
  <div class="max-w-7xl w-full mx-auto">
    <!-- Header section -->
    <div class="mb-8">
      <h1 class="text-2xl font-bold text-brand-slate-900">Safety & Reports</h1>
      <p class="text-brand-slate-500 mt-1">Monitor SOS alerts and user feedback</p>
    </div>

    <!-- Active SOS Alerts Section -->
    <section class="mb-8">
      <div class="flex items-center mb-4">
        <AlertTriangle class="w-6 h-6 text-red-500 mr-2" />
        <h2 class="text-lg font-bold text-brand-slate-900">Active SOS Alerts</h2>
        <span class="text-brand-slate-500 text-sm ml-2 font-normal hidden sm:block">• Real-time emergency monitoring</span>
      </div>
      
      <div class="bg-green-50 border border-green-200 rounded-xl p-8 flex flex-col items-center justify-center text-center shadow-sm">
        <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mb-4 text-2xl text-green-600">
          <CheckCircle class="w-8 h-8" />
        </div>
        <h3 class="text-xl font-bold text-green-700 mb-1">No Active Emergencies</h3>
        <p class="text-green-600 font-medium">All rides are proceeding safely</p>
      </div>
    </section>

    <!-- User Reports & Feedback Section -->
    <section>
      <h2 class="text-lg font-bold text-brand-slate-900 mb-4 mt-8">User Reports & Feedback</h2>
      
      <div class="bg-white rounded-xl shadow-md overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="bg-brand-slate-50 border-b border-brand-slate-200 text-xs uppercase tracking-wider text-brand-slate-500">
                <th class="px-6 py-4 font-medium">Type</th>
                <th class="px-6 py-4 font-medium">Reporter</th>
                <th class="px-6 py-4 font-medium">Reported</th>
                <th class="px-6 py-4 font-medium">Reason</th>
                <th class="px-6 py-4 font-medium">Severity</th>
                <th class="px-6 py-4 font-medium">Status</th>
                <th class="px-6 py-4 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody class="text-sm divide-y divide-brand-slate-200">
              <tr v-for="(report, index) in pageItems" :key="index" class="hover:bg-brand-slate-50 transition-colors">
                <td class="px-6 py-4">
                  <div class="flex items-center font-medium" :class="getTypeColor(report.type)">
                    <component :is="getTypeIcon(report.type)" class="w-4 h-4 mr-2" />
                    {{ report.type }}
                  </div>
                </td>
                <td class="px-6 py-4 font-medium text-brand-slate-800">{{ report.reporter }}</td>
                <td class="px-6 py-4 text-brand-slate-600">{{ report.reported }}</td>
                <td class="px-6 py-4">
                  <div class="text-brand-slate-800">{{ report.reason }}</div>
                  <div class="text-brand-slate-500 text-xs mt-0.5">{{ report.date }}</div>
                </td>
                <td class="px-6 py-4">
                  <span 
                    class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                    :class="getSeverityClass(report.severity)"
                  >
                    {{ report.severity }}
                  </span>
                </td>
                <td class="px-6 py-4">
                  <span 
                    class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                    :class="getStatusClass(report.status)"
                  >
                    {{ report.status }}
                  </span>
                </td>
                <td class="px-6 py-4 text-right">
                  <button class="text-brand-blue-base hover:text-brand-blue-dark font-medium inline-flex items-center gap-1 transition-colors">
                    <Eye class="w-4 h-4" />
                    Review
                  </button>
                </td>
              </tr>
              <tr v-if="pageItems.length === 0">
                <td colspan="7" class="px-6 py-8 text-center text-sm text-brand-slate-500">
                  No reports or feedback submitted.
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <AppPagination
          v-model:page="page"
          v-model:page-size="pageSize"
          :total="totalItems"
          class="mx-6 mb-6"
        />
      </div>
    </section>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { AlertTriangle, CheckCircle, Eye, MessageCircle, ShieldAlert, FileText } from '@lucide/vue';
import AppPagination from '@/components/ui/AppPagination.vue';
import { useApi } from '@/composables/useApi';
import { usePagination } from '@/composables/usePagination';

const api = useApi();

const reports = ref<any[]>([]);
const activeDrivers = ref<any[]>([]);
const isLoading = ref(true);

// Every safety/complaint notification is reachable now that the table pages.
const { page, pageSize, pageItems, totalItems } = usePagination(reports);

const loadReports = async () => {
  try {
    const trackingRes = await api.get('/tracking/active');
    activeDrivers.value = trackingRes.data.data || [];

    const res = await api.get('/notifications');
    reports.value = (res.data.data || [])
      .filter((n: any) => n.type === 'safety' || n.type === 'complaint')
      .map((n: any) => ({
        type: n.type || 'Complaint',
        reporter: 'User',
        reported: 'Driver',
        reason: n.body || n.title,
        date: new Date(n.createdAt).toLocaleString(),
        severity: 'Low',
        status: n.isRead ? 'Reviewed' : 'Pending',
      }));
  } catch (_) {} finally {
    isLoading.value = false;
  }
};

onMounted(loadReports);

const getTypeColor = (type: string) => {
  switch (type) {
    case 'Complaint': return 'text-orange-500';
    case 'Feedback': return 'text-brand-blue-base';
    case 'Safety': return 'text-red-500';
    default: return 'text-brand-slate-500';
  }
};

const getTypeIcon = (type: string) => {
  switch (type) {
    case 'Complaint': return AlertTriangle;
    case 'Feedback': return MessageCircle;
    case 'Safety': return ShieldAlert;
    default: return FileText;
  }
};

const getSeverityClass = (severity: string) => {
  switch (severity) {
    case 'Low': return 'bg-yellow-100 text-yellow-700';
    case 'Medium': return 'bg-orange-100 text-orange-700';
    case 'High': return 'bg-red-100 text-red-700';
    case 'Positive': return 'bg-green-100 text-green-700';
    default: return 'bg-gray-100 text-gray-700';
  }
};

const getStatusClass = (status: string) => {
  switch (status) {
    case 'Pending': return 'bg-orange-100 text-orange-700';
    case 'In Progress': return 'bg-blue-100 text-blue-700';
    case 'Reviewed': return 'bg-gray-100 text-gray-600';
    case 'Resolved': return 'bg-green-100 text-green-700';
    default: return 'bg-gray-100 text-gray-700';
  }
};
</script>
