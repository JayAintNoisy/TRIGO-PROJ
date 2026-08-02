<template>
  <div v-if="isVisible" class="fixed top-4 right-4 z-50 flex items-center w-full max-w-xs p-4 mb-4 text-brand-slate-500 bg-white rounded-lg shadow-lg" role="alert">
    <div class="inline-flex items-center justify-center flex-shrink-0 w-8 h-8 rounded-lg" :class="iconClasses">
      <component :is="icon" class="w-5 h-5" />
    </div>
    <div class="ml-3 text-sm font-normal">{{ message }}</div>
    <button type="button" class="ml-auto -mx-1.5 -my-1.5 bg-white text-brand-slate-400 hover:text-brand-slate-900 rounded-lg focus:ring-2 focus:ring-brand-slate-300 p-1.5 hover:bg-brand-slate-100 inline-flex h-8 w-8" @click="close">
      <span class="sr-only">Close</span>
      <X class="w-4 h-4 m-auto" />
    </button>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { CheckCircle, AlertCircle, AlertTriangle, Info, X } from '@lucide/vue';

const props = defineProps({
  message: {
    type: String,
    required: true,
  },
  type: {
    type: String,
    default: 'info', // 'success', 'error', 'warning', 'info'
  },
  duration: {
    type: Number,
    default: 3000,
  }
});

const isVisible = ref(true);

const icon = computed(() => {
  switch (props.type) {
    case 'success': return CheckCircle;
    case 'error': return AlertCircle;
    case 'warning': return AlertTriangle;
    default: return Info;
  }
});

const iconClasses = computed(() => {
  switch (props.type) {
    case 'success': return 'text-brand-green-dark bg-green-100';
    case 'error': return 'text-red-500 bg-red-100';
    case 'warning': return 'text-amber-500 bg-amber-100';
    default: return 'text-brand-blue-base bg-blue-100';
  }
});

const close = () => {
  isVisible.value = false;
};

if (props.duration > 0) {
  setTimeout(() => {
    close();
  }, props.duration);
}
</script>
