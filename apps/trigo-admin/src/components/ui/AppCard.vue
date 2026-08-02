<template>
  <div class="bg-white rounded-2xl p-6 shadow-md transition-all hover:shadow-lg">
    <div v-if="$slots.header" class="mb-4 pb-3 border-b border-brand-slate-200/50 flex justify-between items-center">
      <slot name="header" />
    </div>
    <slot />
  </div>
</template>
