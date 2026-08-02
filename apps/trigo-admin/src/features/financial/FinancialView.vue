<template>
  <div class="space-y-8">
    <!-- Header Section -->
    <div class="flex flex-col sm:flex-row sm:justify-between sm:items-end gap-4">
      <div>
        <h1 class="text-2xl font-bold text-brand-slate-900 mb-1">Financial Ledger</h1>
        <p class="text-brand-slate-500 text-sm">Complete transaction audit trail</p>
      </div>
      
      <button class="flex items-center justify-center gap-2 bg-white border border-brand-slate-300 text-brand-slate-700 px-4 py-2 rounded-lg text-sm font-medium hover:bg-brand-slate-50 shadow-sm transition-colors">
        <Search class="w-4 h-4" />
        Filter
      </button>
    </div>

    <!-- Summary Cards Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Total Revenue (GREEN GRADIENT) -->
      <div class="bg-gradient-to-br from-emerald-500 to-emerald-600 rounded-xl shadow-sm p-6 text-white flex flex-col justify-between">
        <div class="flex items-center gap-3 mb-4 text-emerald-100">
          <div class="p-2 bg-white/20 rounded-lg">
            <DollarSign class="w-5 h-5" />
          </div>
          <span class="font-medium text-sm">Total Revenue</span>
        </div>
        <div>
            <h3 class="text-3xl font-bold">₱{{ totalRevenue.toLocaleString() }}</h3>
        </div>
      </div>

      <!-- Total Cash-outs -->
      <div class="bg-white rounded-xl shadow-md p-6 flex flex-col justify-between">
        <div class="flex items-center gap-3 mb-4 text-brand-slate-500">
          <div class="p-2 bg-red-50 text-red-600 rounded-lg">
            <Banknote class="w-5 h-5" />
          </div>
          <span class="font-medium text-sm">Total Cash-outs</span>
        </div>
        <div>
            <h3 class="text-3xl font-bold text-red-500">₱{{ totalCashouts.toLocaleString() }}</h3>
        </div>
      </div>

      <!-- Net Revenue -->
      <div class="bg-white rounded-xl shadow-md p-6 flex flex-col justify-between">
        <div class="flex items-center gap-3 mb-4 text-brand-slate-500">
          <div class="p-2 bg-emerald-50 text-emerald-600 rounded-lg">
            <TrendingUp class="w-5 h-5" />
          </div>
          <span class="font-medium text-sm">Net Revenue</span>
        </div>
        <div>
            <h3 class="text-3xl font-bold text-emerald-500">₱{{ netRevenue.toLocaleString() }}</h3>
        </div>
      </div>

      <!-- Payment Split -->
      <div class="bg-white rounded-xl shadow-md p-6 flex flex-col justify-between">
        <div class="flex items-center gap-3 mb-4 text-brand-slate-500">
          <div class="p-2 bg-blue-50 text-brand-blue-base rounded-lg">
            <CreditCard class="w-5 h-5" />
          </div>
          <span class="font-medium text-sm">Payment Split</span>
        </div>
        <div class="space-y-1">
          <div class="flex justify-between items-center text-sm font-bold text-brand-blue-base">
            <span>GCash</span>
            <span>₱{{ gcashTotal.toLocaleString() }}</span>
          </div>
          <div class="flex justify-between items-center text-sm font-bold text-emerald-600">
            <span>Cash</span>
            <span>₱{{ cashTotal.toLocaleString() }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Transaction Table -->
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-brand-slate-50 text-brand-slate-500 text-xs uppercase tracking-wider border-b border-brand-slate-200">
              <th class="px-6 py-4 font-medium">Type</th>
              <th class="px-6 py-4 font-medium">Details</th>
              <th class="px-6 py-4 font-medium">Amount</th>
              <th class="px-6 py-4 font-medium">Method</th>
              <th class="px-6 py-4 font-medium">Date</th>
              <th class="px-6 py-4 font-medium">Status</th>
            </tr>
          </thead>
          <tbody class="text-sm divide-y divide-brand-slate-100">
            <tr v-for="(tx, index) in transactions" :key="index" class="hover:bg-brand-slate-50 transition-colors group">
              <td class="px-6 py-4 whitespace-nowrap text-brand-slate-800 font-medium">
                {{ tx.type }}
              </td>
              <td class="px-6 py-4">
                <div v-if="tx.passenger" class="text-brand-slate-800">Passenger: {{ tx.passenger }}</div>
                <div v-if="tx.driver" :class="tx.passenger ? 'text-brand-slate-500 text-xs' : 'text-brand-slate-800'">Driver: {{ tx.driver }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap font-bold" :class="tx.amount > 0 ? 'text-emerald-600' : 'text-red-500'">
                {{ tx.amount > 0 ? '+' : '' }}₱{{ Math.abs(tx.amount) }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span 
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                  :class="{
                    'bg-blue-100 text-blue-700': tx.method === 'GCash',
                    'bg-gray-100 text-gray-700': tx.method === 'Cash',
                    'bg-purple-100 text-purple-700': tx.method === 'Wallet'
                  }"
                >
                  {{ tx.method }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-brand-slate-500 text-sm">
                {{ tx.date }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span 
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                  :class="tx.status === 'Completed' ? 'bg-green-100 text-green-700' : 'bg-blue-100 text-blue-700'"
                >
                  {{ tx.status }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { Search, DollarSign, Banknote, TrendingUp, CreditCard } from '@lucide/vue';
import { useApi } from '@/composables/useApi';

const api = useApi();

const transactions = ref([]);
const isLoading = ref(true);

const loadTransactions = async () => {
  try {
    const res = await api.get('/payments');
    const data = (res.data.data || []).map((p: any) => ({
      type: 'Ride Payment',
      passenger: p.customerName || 'Customer',
      driver: p.driverName || 'Driver',
      amount: p.amount || 0,
      method: p.paymentMethod || 'Cash',
      date: new Date(p.createdAt).toLocaleString(),
      status: p.status || 'Completed',
    }));
    if (data.length > 0) {
      transactions.value = data;
    }
  } catch (_) {
    transactions.value = [
      { type: 'Ride Payment', passenger: 'Loading...', driver: 'Loading...', amount: 0, method: '...', date: '...', status: 'Loading' },
    ];
  } finally {
    isLoading.value = false;
  }
};

const totalRevenue = computed(() =>
  transactions.value
    .filter((t: any) => t.amount > 0)
    .reduce((sum: number, t: any) => sum + t.amount, 0)
);

const totalCashouts = computed(() =>
  transactions.value
    .filter((t: any) => t.amount < 0)
    .reduce((sum: number, t: any) => sum + Math.abs(t.amount), 0)
);

const netRevenue = computed(() => totalRevenue.value - totalCashouts.value);

const gcashTotal = computed(() =>
  transactions.value
    .filter((t: any) => t.method === 'GCash' && t.amount > 0)
    .reduce((sum: number, t: any) => sum + t.amount, 0)
);

const cashTotal = computed(() =>
  transactions.value
    .filter((t: any) => t.method === 'Cash' && t.amount > 0)
    .reduce((sum: number, t: any) => sum + t.amount, 0)
);

onMounted(loadTransactions);
</script>
