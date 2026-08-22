<template>
  <aside class="fixed inset-y-0 left-0 w-48 bg-white border-r border-brand-slate-200 flex flex-col z-20">
    <div class="p-6 border-b border-brand-slate-100 flex flex-col items-center">
      <div class="w-12 h-12 bg-brand-blue-base rounded-full flex items-center justify-center text-white font-bold text-xl mb-2 shadow-lg shadow-blue-200">
        T
      </div>
      <h1 class="font-bold text-lg text-brand-slate-900 tracking-tight">TRIGO</h1>
      <p class="text-xs text-brand-slate-500 font-medium">Admin Portal</p>
    </div>

    <nav class="flex-1 py-4 flex flex-col gap-1 overflow-y-auto">
      <router-link
        v-for="item in navItems"
        :key="item.path"
        :to="item.path"
        class="px-6 py-3 border-l-4 font-medium flex items-center gap-3 transition-colors"
        :class="[
          $route.path === item.path
            ? 'border-brand-blue-base bg-blue-50 text-blue-700'
            : 'border-transparent text-brand-slate-600 hover:bg-brand-slate-50 hover:text-brand-slate-900'
        ]"
      >
        <component :is="item.icon" class="w-5 h-5" :class="{ 'opacity-75': $route.path !== item.path }" />
        <span class="text-sm">{{ item.name }}</span>
      </router-link>
    </nav>

    <div class="p-4 border-t border-brand-slate-100">
      <button 
        @click="handleLogout"
        class="w-full py-2.5 px-4 bg-red-50 text-red-600 font-medium rounded-lg text-sm flex items-center justify-center gap-2 hover:bg-red-100 transition-colors"
      >
        <LogOut class="w-4 h-4" />
        Logout
      </button>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { useAuthStore } from '@/stores/auth.store';
import { useRouter } from 'vue-router';
import {
  LayoutDashboard,
  Bike,
  Users,
  DollarSign,
  TrendingUp,
  Shield,
  Megaphone,
  LogOut,
  ClipboardList,
  Route,
  MapPin,
  Navigation,
} from '@lucide/vue';

const authStore = useAuthStore();
const router = useRouter();

const navItems = [
  { name: 'Dashboard', path: '/', icon: LayoutDashboard },
  { name: 'Applications', path: '/applications', icon: ClipboardList },
  { name: 'Drivers', path: '/drivers', icon: Bike },
  { name: 'Passengers', path: '/users', icon: Users },
  { name: 'Rides', path: '/rides', icon: Route },
  { name: 'Municipalities', path: '/municipalities', icon: MapPin },
  { name: 'Live Tracking', path: '/tracking', icon: Navigation },
  { name: 'Financial', path: '/financial', icon: DollarSign },
  { name: 'Fare Matrix', path: '/fare-matrix', icon: TrendingUp },
  { name: 'Safety & Reports', path: '/safety', icon: Shield },
  { name: 'Communication', path: '/communication', icon: Megaphone },
];

const handleLogout = () => {
  authStore.logout();
  router.push('/login');
};
</script>
