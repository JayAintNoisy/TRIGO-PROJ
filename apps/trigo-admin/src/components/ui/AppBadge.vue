<template>
  <span
    :class="[
      'inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold tracking-wide uppercase',
      variantClasses[variant]
    ]"
  >
    <slot />
  </span>
</template>

<script setup lang="ts">
import { PropType } from 'vue';

defineProps({
  variant: {
    type: String as PropType<'success' | 'warning' | 'danger' | 'info' | 'neutral'>,
    default: 'neutral'
  }
});

const variantClasses = {
  success: 'bg-emerald-100 text-emerald-800 border border-emerald-200',
  warning: 'bg-amber-100 text-amber-800 border border-amber-200',
  danger: 'bg-red-100 text-red-800 border border-red-200',
  info: 'bg-blue-100 text-blue-800 border border-blue-200',
  neutral: 'bg-slate-100 text-slate-700 border border-slate-200',
};
</script>
