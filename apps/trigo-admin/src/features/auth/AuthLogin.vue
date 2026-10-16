<template>
  <div class="min-h-screen bg-gradient-to-br from-slate-900 via-blue-950 to-slate-900 flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl shadow-2xl p-8 max-w-md w-full">
      <div class="text-center mb-8">
        <AppLogo class="justify-center mb-3" />
        <h2 class="text-2xl font-extrabold text-brand-slate-900">Admin Portal Sign In</h2>
        <p class="text-sm text-brand-slate-500 mt-1">Manage tricycle rides, drivers, and jurisdictions</p>
      </div>

      <form @submit.prevent="handleLogin" class="space-y-4">
        <AppInput id="email" v-model="email" label="Email Address" placeholder="you@example.com" type="email" required />
        <AppInput id="password" v-model="password" label="Password" placeholder="••••••••" type="password" required />

        <div v-if="error" class="p-3 rounded-xl bg-red-50 border border-red-200 text-xs font-semibold text-red-600">
          {{ error }}
        </div>

        <AppButton type="submit" variant="primary" size="lg" class="w-full" :loading="loading">
          Sign In to Dashboard
        </AppButton>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import AppLogo from '@/components/ui/AppLogo.vue';
import AppInput from '@/components/ui/AppInput.vue';
import AppButton from '@/components/ui/AppButton.vue';
import { useAuthStore } from '@/stores/auth.store';
import { useApi } from '@/composables/useApi';

// Left blank on purpose: a prefilled credential would ship a working
// account (the seeded admin) inside the public bundle.
const email = ref('');
const password = ref('');
const loading = ref(false);
const error = ref('');

const authStore = useAuthStore();
const router = useRouter();
const api = useApi();

const handleLogin = async () => {
  loading.value = true;
  error.value = '';
  try {
    const res = await api.post('/auth/login', { email: email.value, password: password.value });
    const { accessToken, user } = res.data.data;
    authStore.setAuth(accessToken, user);
    router.push('/');
  } catch (err: any) {
    error.value = err.response?.data?.error?.message || 'Login failed. Please check credentials.';
  } finally {
    loading.value = false;
  }
};
</script>
