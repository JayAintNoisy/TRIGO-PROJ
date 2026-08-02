<template>
  <div class="flex min-h-screen bg-brand-slate-50">
    <AppSidebar />
    <div class="flex-1 flex flex-col min-w-0 ml-48">
      <AppNavbar />
      <main class="p-8 max-w-7xl mx-auto w-full">
        <router-view />
      </main>
    </div>
  </div>
</template>

<script setup lang="ts">
import AppSidebar from './AppSidebar.vue';
import AppNavbar from './AppNavbar.vue';
</script>
