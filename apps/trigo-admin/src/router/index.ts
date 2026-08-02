import { createRouter, createWebHistory, RouteRecordRaw } from 'vue-router';
import AppLayout from '@/components/layout/AppLayout.vue';
import AuthLogin from '@/features/auth/AuthLogin.vue';
import DashboardView from '@/features/dashboard/DashboardView.vue';
import DriverApplicationsList from '@/features/driver-applications/DriverApplicationsList.vue';
import DriversList from '@/features/drivers/DriversList.vue';
import RidesList from '@/features/rides/RidesList.vue';
import MunicipalitiesList from '@/features/municipalities/MunicipalitiesList.vue';
import UsersList from '@/features/users/UsersList.vue';
import TrackingView from '@/features/tracking/TrackingView.vue';
import { useAuthStore } from '@/stores/auth.store';

const routes: Array<RouteRecordRaw> = [
  {
    path: '/login',
    name: 'Login',
    component: AuthLogin,
    meta: { public: true },
  },
  {
    path: '/',
    component: AppLayout,
    children: [
      { path: '', name: 'Dashboard', component: DashboardView },
      { path: 'applications', name: 'DriverApplications', component: DriverApplicationsList },
      { path: 'drivers', name: 'Drivers', component: DriversList },
      { path: 'rides', name: 'Rides', component: RidesList },
      { path: 'municipalities', name: 'Municipalities', component: MunicipalitiesList },
      { path: 'fare-matrix', name: 'FareMatrix', component: () => import('@/features/municipalities/FareMatrix.vue') },
      { path: 'users', name: 'Users', component: UsersList },
      { path: 'tracking', name: 'Tracking', component: TrackingView },
      { path: 'communication', name: 'Communication', component: () => import('@/features/communication/CommunicationView.vue') },
      { path: 'financial', name: 'Financial', component: () => import('@/features/financial/FinancialView.vue') },
      { path: 'safety', name: 'Safety', component: () => import('@/features/safety/SafetyView.vue') },
    ],
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach((to, from, next) => {
  const authStore = useAuthStore();
  if (!to.meta.public && !authStore.isAuthenticated) {
    next('/login');
  } else {
    next();
  }
});

export default router;
