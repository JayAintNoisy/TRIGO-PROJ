<template>
  <div class="flex items-center gap-2 font-bold text-xl tracking-tight text-brand-blue-base">
    <AppBrandMark :size="36" class="shadow-md shadow-blue-500/25" />
    <span class="text-brand-slate-900">Tri<span class="text-brand-blue-base">Go</span> <span class="text-xs px-2 py-0.5 rounded bg-brand-slate-200 text-brand-slate-500 font-semibold uppercase tracking-wider">Admin</span></span>
  </div>
</template>

<script setup lang="ts">
import AppBrandMark from './AppBrandMark.vue';
</script>
