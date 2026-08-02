import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(localStorage.getItem('trigo_admin_token'));
  const user = ref<any | null>(JSON.parse(localStorage.getItem('trigo_admin_user') || 'null'));

  const isAuthenticated = computed(() => !!token.value);

  const setAuth = (newToken: string, newUser: any) => {
    token.value = newToken;
    user.value = newUser;
    localStorage.setItem('trigo_admin_token', newToken);
    localStorage.setItem('trigo_admin_user', JSON.stringify(newUser));
  };

  const logout = () => {
    token.value = null;
    user.value = null;
    localStorage.removeItem('trigo_admin_token');
    localStorage.removeItem('trigo_admin_user');
  };

  return { token, user, isAuthenticated, setAuth, logout };
});
