<template>
  <div class="flex flex-col gap-1.5 w-full">
    <label v-if="label" :for="id" class="text-sm font-semibold text-brand-slate-900">
      {{ label }}
    </label>
    <div class="relative">
      <input
        :id="id"
        :type="type"
        :value="modelValue"
        :placeholder="placeholder"
        :disabled="disabled"
        :class="[
          'w-full px-4 py-2.5 rounded-xl border text-sm transition-all focus:outline-none focus:ring-2 disabled:bg-brand-slate-50 disabled:cursor-not-allowed',
          error ? 'border-red-500 focus:ring-red-200' : 'border-brand-slate-200 focus:border-brand-blue-base focus:ring-blue-100'
        ]"
        @input="$emit('update:modelValue', ($event.target as HTMLInputElement).value)"
      />
    </div>
    <span v-if="error" class="text-xs font-medium text-red-500">{{ error }}</span>
  </div>
</template>

<script setup lang="ts">
defineProps({
  modelValue: [String, Number],
  label: String,
  id: String,
  type: {
    type: String,
    default: 'text'
  },
  placeholder: String,
  error: String,
  disabled: Boolean,
});

defineEmits(['update:modelValue']);
</script>
