<template>
  <div class="flex flex-col gap-1.5 w-full">
    <label v-if="label" class="text-sm font-semibold text-brand-slate-900">{{ label }}</label>
    <select
      :value="modelValue"
      :disabled="disabled"
      class="w-full px-4 py-2.5 rounded-xl border border-brand-slate-200 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-100 focus:border-brand-blue-base"
      @change="$emit('update:modelValue', ($event.target as HTMLSelectElement).value)"
    >
      <option v-for="opt in options" :key="opt.value" :value="opt.value">
        {{ opt.label }}
      </option>
    </select>
  </div>
</template>

<script setup lang="ts">
import { PropType } from 'vue';

defineProps({
  modelValue: [String, Number],
  label: String,
  disabled: Boolean,
  options: {
    type: Array as PropType<{ label: string; value: string | number }[]>,
    default: () => [],
  },
});

defineEmits(['update:modelValue']);
</script>
