<template>
  <header class="bg-white border-b border-brand-slate-200 sticky top-0 z-10 px-8 py-4 flex items-center justify-between">
    <div>
      <!-- Optional title area -->
    </div>
    <div class="flex items-center gap-4">
      <button class="w-10 h-10 rounded-full bg-brand-slate-100 flex items-center justify-center text-brand-slate-600 hover:bg-brand-slate-200 relative">
        <Bell class="w-5 h-5" />
        <span class="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border border-white"></span>
      </button>
      <div class="flex items-center gap-3 pl-4 border-l border-brand-slate-200">
        <div class="w-10 h-10 rounded-full bg-brand-slate-200 border border-brand-slate-300 flex items-center justify-center text-brand-slate-500 font-bold">
          A
        </div>
      </div>
    </div>
  </header>
</template>

<script setup lang="ts">
import { Bell } from 'lucide-vue-next';
</script>
