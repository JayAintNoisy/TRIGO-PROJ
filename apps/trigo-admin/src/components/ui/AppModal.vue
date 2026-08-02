<template>
  <Teleport to="body">
    <Transition name="fade">
      <div v-if="isOpen" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/50 backdrop-blur-sm" @click.self="$emit('close')">
        <div class="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl animate-in fade-in zoom-in duration-200">
          <div class="flex items-center justify-between pb-3 border-b border-brand-slate-200 mb-4">
            <h3 class="text-lg font-bold text-brand-slate-900">{{ title }}</h3>
            <button class="text-brand-slate-500 hover:text-brand-slate-900" @click="$emit('close')">✕</button>
          </div>
          <div class="mb-6">
            <slot />
          </div>
          <div v-if="$slots.footer" class="flex justify-end gap-3 pt-3 border-t border-brand-slate-200">
            <slot name="footer" />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
defineProps({
  isOpen: Boolean,
  title: String,
});
defineEmits(['close']);
</script>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
