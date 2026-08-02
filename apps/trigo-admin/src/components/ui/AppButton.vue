<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    :class="[
      'inline-flex items-center justify-center font-semibold transition-all duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed',
      variantClasses[variant],
      sizeClasses[size],
      rounded ? 'rounded-full' : 'rounded-xl'
    ]"
    @click="$emit('click', $event)"
  >
    <svg v-if="loading" class="animate-spin -ml-1 mr-2 h-4 w-4 text-current" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    <slot />
  </button>
</template>

<script setup lang="ts">
import { PropType } from 'vue';

defineProps({
  variant: {
    type: String as PropType<'primary' | 'secondary' | 'danger' | 'outline' | 'ghost'>,
    default: 'primary'
  },
  size: {
    type: String as PropType<'sm' | 'md' | 'lg'>,
    default: 'md'
  },
  type: {
    type: String as PropType<'button' | 'submit' | 'reset'>,
    default: 'button'
  },
  disabled: Boolean,
  loading: Boolean,
  rounded: Boolean,
});

defineEmits(['click']);

const variantClasses = {
  primary: 'bg-brand-blue-base hover:bg-brand-blue-dark text-white shadow-lg shadow-blue-500/20 focus:ring-brand-blue-base',
  secondary: 'bg-brand-green-base hover:bg-brand-green-dark text-white shadow-lg shadow-emerald-500/20 focus:ring-brand-green-base',
  danger: 'bg-red-600 hover:bg-red-700 text-white shadow-lg shadow-red-500/20 focus:ring-red-600',
  outline: 'border border-brand-slate-200 text-brand-slate-900 bg-white hover:bg-brand-slate-50 focus:ring-brand-blue-base',
  ghost: 'text-brand-slate-500 hover:text-brand-slate-900 hover:bg-brand-slate-200/50 focus:ring-brand-blue-base',
};

const sizeClasses = {
  sm: 'px-3 py-1.5 text-xs',
  md: 'px-4 py-2 text-sm',
  lg: 'px-6 py-3 text-base',
};
</script>
