<template>
  <div class="max-w-5xl mx-auto space-y-6">
    <!-- Title Area -->
    <div>
      <h1 class="text-2xl font-bold text-brand-slate-800">Fare Matrix Settings</h1>
      <p class="text-brand-slate-500 mt-1">Configure pricing rules applied across all rides</p>
    </div>

    <!-- Live Preview Banner -->
    <div class="bg-gradient-to-r from-brand-blue-base to-indigo-600 rounded-xl p-6 shadow-sm">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-2 text-blue-50">
          <Zap class="w-5 h-5 text-yellow-300 fill-yellow-300" />
          <span class="font-medium">Live Preview — 2.5 km Ride</span>
        </div>
        <select
          v-model="selectedMunicipalityId"
          class="bg-white/10 border border-white/20 rounded-lg px-3 py-2 text-sm text-white backdrop-blur-sm"
        >
          <option v-for="m in municipalities" :key="m.id" :value="m.id" class="text-brand-slate-800">
            {{ m.name }}
          </option>
        </select>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <!-- Standard Fare -->
        <div class="bg-white/10 rounded-xl p-4 backdrop-blur-sm border border-white/20">
          <div class="text-blue-100 text-sm mb-1 font-medium">Standard Fare</div>
          <div class="text-4xl font-bold text-white mb-1">₱{{ standardFarePreview }}</div>
          <div class="text-sm text-blue-200">Base ₱{{ baseFare }} + {{ perKmRate }}×2.5km</div>
        </div>
        <!-- Exclusive Fare -->
        <div class="bg-white/10 rounded-xl p-4 backdrop-blur-sm border border-white/20">
          <div class="text-blue-100 text-sm mb-1 font-medium">Exclusive Fare</div>
          <div class="text-4xl font-bold text-white mb-1">₱{{ exclusiveFarePreview }}</div>
          <div class="text-sm text-blue-200">×{{ exclusiveMultiplier }} multiplier</div>
        </div>
      </div>
    </div>

    <!-- Config Cards Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      
      <!-- Base Fare -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="mb-4">
          <h3 class="font-bold text-brand-slate-800">Base Fare</h3>
          <p class="text-sm text-brand-slate-500 mt-1">Starting fee for standard rides</p>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <button 
            @click="baseFare = Math.max(5, baseFare - 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-slate-100 text-brand-slate-500 hover:bg-brand-slate-200 transition-colors"
          >
            <Minus class="w-5 h-5" />
          </button>
          <div class="flex-1 text-center bg-brand-slate-50 rounded-lg py-3">
            <span class="text-2xl font-bold text-brand-blue-base">₱{{ baseFare }}</span>
          </div>
          <button 
            @click="baseFare = Math.min(100, baseFare + 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-blue-base text-white hover:bg-brand-blue-dark transition-colors"
          >
            <Plus class="w-5 h-5" />
          </button>
        </div>
        <div class="flex justify-between text-xs text-brand-slate-400 font-medium">
          <span>Min: ₱5</span>
          <span>Max: ₱100</span>
        </div>
      </div>

      <!-- Per Kilometer Rate -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="mb-4">
          <h3 class="font-bold text-brand-slate-800">Per Kilometer Rate</h3>
          <p class="text-sm text-brand-slate-500 mt-1">Added cost for each km traveled</p>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <button 
            @click="perKmRate = Math.max(2, perKmRate - 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-slate-100 text-brand-slate-500 hover:bg-brand-slate-200 transition-colors"
          >
            <span>➖</span>
          </button>
          <div class="flex-1 text-center bg-brand-slate-50 rounded-lg py-3">
            <span class="text-2xl font-bold text-brand-blue-base">₱{{ perKmRate }}<span class="text-sm font-medium text-brand-blue-base">/km</span></span>
          </div>
          <button 
            @click="perKmRate = Math.min(50, perKmRate + 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-blue-base text-white hover:bg-brand-blue-dark transition-colors"
          >
            <span>➕</span>
          </button>
        </div>
        <div class="flex justify-between text-xs text-brand-slate-400 font-medium">
          <span>Min: ₱2/km</span>
          <span>Max: ₱50/km</span>
        </div>
      </div>

      <!-- Exclusive Ride Multiplier -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="mb-4">
          <h3 class="font-bold text-brand-slate-800">Exclusive Ride Multiplier</h3>
          <p class="text-sm text-brand-slate-500 mt-1">Cost factor for solo passenger rides</p>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <button 
            @click="exclusiveMultiplier = Math.max(1, exclusiveMultiplier - 0.1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-slate-100 text-brand-slate-500 hover:bg-brand-slate-200 transition-colors"
          >
            <span>➖</span>
          </button>
          <div class="flex-1 text-center bg-brand-slate-50 rounded-lg py-3">
            <span class="text-2xl font-bold text-orange-500">×{{ exclusiveMultiplier.toFixed(1) }}</span>
          </div>
          <button 
            @click="exclusiveMultiplier = Math.min(4, exclusiveMultiplier + 0.1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-orange-500 text-white hover:bg-orange-600 transition-colors"
          >
            <span>➕</span>
          </button>
        </div>
        <div class="flex justify-between text-xs text-brand-slate-400 font-medium">
          <span>Min: ×1</span>
          <span>Max: ×4</span>
        </div>
      </div>

      <!-- Minimum Fare -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="mb-4">
          <h3 class="font-bold text-brand-slate-800">Minimum Fare</h3>
          <p class="text-sm text-brand-slate-500 mt-1">Lowest possible fare for short trips</p>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <button 
            @click="minFare = Math.max(10, minFare - 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-slate-100 text-brand-slate-500 hover:bg-brand-slate-200 transition-colors"
          >
            <span>➖</span>
          </button>
          <div class="flex-1 text-center bg-brand-slate-50 rounded-lg py-3">
            <span class="text-2xl font-bold text-emerald-500">₱{{ minFare }}</span>
          </div>
          <button 
            @click="minFare = Math.min(100, minFare + 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-emerald-500 text-white hover:bg-emerald-600 transition-colors"
          >
            <span>➕</span>
          </button>
        </div>
        <div class="flex justify-between text-xs text-brand-slate-400 font-medium">
          <span>Min: ₱10</span>
          <span>Max: ₱100</span>
        </div>
      </div>

      <!-- Night Surcharge -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="mb-4">
          <h3 class="font-bold text-brand-slate-800">Night Surcharge</h3>
          <p class="text-sm text-brand-slate-500 mt-1">Added flat fee for rides 10PM-4AM</p>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <button 
            @click="nightSurcharge = Math.max(0, nightSurcharge - 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-slate-100 text-brand-slate-500 hover:bg-brand-slate-200 transition-colors"
          >
            <span>➖</span>
          </button>
          <div class="flex-1 text-center bg-brand-slate-50 rounded-lg py-3">
            <span class="text-2xl font-bold text-brand-blue-base">₱{{ nightSurcharge }}</span>
          </div>
          <button 
            @click="nightSurcharge = Math.min(50, nightSurcharge + 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-blue-base text-white hover:bg-brand-blue-dark transition-colors"
          >
            <span>➕</span>
          </button>
        </div>
        <div class="flex justify-between text-xs text-brand-slate-400 font-medium">
          <span>Min: ₱0</span>
          <span>Max: ₱50</span>
        </div>
      </div>

      <!-- Max Passengers -->
      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="mb-4">
          <h3 class="font-bold text-brand-slate-800">Max Passengers</h3>
          <p class="text-sm text-brand-slate-500 mt-1">Maximum allowed for shared rides</p>
        </div>
        <div class="flex items-center gap-2 mb-3">
          <button 
            @click="maxPassengers = Math.max(1, maxPassengers - 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-brand-slate-100 text-brand-slate-500 hover:bg-brand-slate-200 transition-colors"
          >
            <span>➖</span>
          </button>
          <div class="flex-1 text-center bg-brand-slate-50 rounded-lg py-3">
            <span class="text-2xl font-bold text-emerald-500">{{ maxPassengers }} <span class="text-sm font-medium text-emerald-500">pax</span></span>
          </div>
          <button 
            @click="maxPassengers = Math.min(6, maxPassengers + 1)"
            class="w-12 h-12 flex items-center justify-center rounded-lg bg-emerald-500 text-white hover:bg-emerald-600 transition-colors"
          >
            <span>➕</span>
          </button>
        </div>
        <div class="flex justify-between text-xs text-brand-slate-400 font-medium">
          <span>Min: 1 pax</span>
          <span>Max: 6 pax</span>
        </div>
      </div>

    </div>

    <!-- Bottom Action Bar -->
    <div class="flex flex-col sm:flex-row gap-4 mt-8">
      <button 
        @click="resetConfig"
        class="flex items-center justify-center gap-2 px-6 py-4 text-brand-slate-600 bg-white border border-brand-slate-200 rounded-xl hover:bg-brand-slate-50 transition-colors font-medium sm:w-48 shadow-sm"
      >
        <RefreshCw class="w-5 h-5" />
        Reset
      </button>
      <button 
        @click="saveFareConfig"
        :disabled="isSaving"
        class="flex-1 flex items-center justify-center gap-2 bg-brand-blue-base text-white rounded-xl py-4 hover:bg-brand-blue-dark transition-colors shadow-sm font-medium disabled:opacity-50"
      >
        <Save class="w-5 h-5" />
        {{ isSaving ? 'Saving...' : 'Save Changes' }}
      </button>
    </div>
    <p v-if="saveMessage" class="text-sm" :class="saveMessage.includes('success') ? 'text-green-600' : 'text-red-600'">{{ saveMessage }}</p>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { Zap, Minus, Plus, RefreshCw, Save } from '@lucide/vue';
import { useApi } from '@/composables/useApi';

const api = useApi();

interface Municipality {
  id: string;
  name: string;
  baseFare: number;
  perKmRate: number;
  exclusiveMultiplier: number;
  minFare: number;
  nightSurcharge: number;
  maxPassengers: number;
}

const isSaving = ref(false);
const saveMessage = ref('');
const municipalities = ref<Municipality[]>([]);
const selectedMunicipalityId = ref('');

const baseFare = ref(15);
const perKmRate = ref(10);
const exclusiveMultiplier = ref(1.5);
const minFare = ref(20);
const nightSurcharge = ref(5);
const maxPassengers = ref(4);

const loadFareConfig = async () => {
  try {
    const res = await api.get('/municipalities');
    const list = res.data.data || [];
    municipalities.value = list;
    if (list.length > 0 && !selectedMunicipalityId.value) {
      selectedMunicipalityId.value = list[0].id;
    }
    applySelected();
  } catch (_) {}
};

// Backend returns flat fare fields on the municipality object
const applySelected = () => {
  const m = municipalities.value.find((x) => x.id === selectedMunicipalityId.value);
  if (!m) return;
  baseFare.value = m.baseFare ?? 15;
  perKmRate.value = m.perKmRate ?? 10;
  exclusiveMultiplier.value = m.exclusiveMultiplier ?? 1.5;
  minFare.value = m.minFare ?? 20;
  nightSurcharge.value = m.nightSurcharge ?? 0;
  maxPassengers.value = m.maxPassengers ?? 4;
};

watch(selectedMunicipalityId, applySelected);

const saveFareConfig = async () => {
  if (!selectedMunicipalityId.value) return;
  isSaving.value = true;
  try {
    await api.patch(`/municipalities/${selectedMunicipalityId.value}/fare-config`, {
      baseFare: baseFare.value,
      perKmRate: perKmRate.value,
      exclusiveMultiplier: Number(exclusiveMultiplier.value.toFixed(2)),
      minFare: minFare.value,
      nightSurcharge: nightSurcharge.value,
      maxPassengers: maxPassengers.value,
    });
    saveMessage.value = 'Saved successfully';
    setTimeout(() => (saveMessage.value = ''), 3000);
  } catch (_) {
    saveMessage.value = 'Failed to save';
  } finally {
    isSaving.value = false;
  }
};

const resetConfig = async () => {
  baseFare.value = 15;
  perKmRate.value = 10;
  exclusiveMultiplier.value = 1.5;
  minFare.value = 20;
  nightSurcharge.value = 5;
  maxPassengers.value = 4;
};

onMounted(loadFareConfig);

const standardFarePreview = computed(() => {
  const calculated = baseFare.value + (perKmRate.value * 2.5);
  return Math.max(calculated, minFare.value).toFixed(0);
});

const exclusiveFarePreview = computed(() => {
  return (parseFloat(standardFarePreview.value) * exclusiveMultiplier.value).toFixed(0);
});
</script>
