<template>
  <div class="space-y-8">
    <!-- Header Section -->
    <div>
      <h1 class="text-2xl font-bold text-brand-slate-900">Communication Center</h1>
      <p class="text-brand-slate-500 mt-1">Send announcements and notifications to users</p>
    </div>

    <!-- Create New Announcement Card -->
    <div class="bg-white rounded-xl shadow-md p-6">
      <div class="flex flex-col md:flex-row md:items-center gap-4 mb-6">
        <div class="w-12 h-12 rounded-full bg-blue-100 text-brand-blue-base flex items-center justify-center shrink-0">
          <MessageCircle class="w-6 h-6" />
        </div>
        <div>
          <h2 class="text-lg font-bold text-brand-slate-900">Create New Announcement</h2>
          <p class="text-brand-slate-500 text-sm">Compose and send system-wide messages</p>
        </div>
      </div>

      <!-- Audience Selection -->
      <div class="mt-6">
        <h3 class="font-bold text-brand-slate-900 text-sm mb-3">Select Audience</h3>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          <button 
            class="rounded-xl py-3 flex items-center justify-center gap-2 transition-colors border-2"
            :class="audience === 'all' ? 'bg-brand-blue-base text-white border-brand-blue-base hover:bg-brand-blue-dark' : 'bg-white text-brand-slate-600 border-brand-slate-200 hover:bg-brand-slate-50'"
            @click="audience = 'all'"
          >
            <Users class="w-5 h-5" />
            <span class="font-medium text-sm">All Users</span>
          </button>
          <button 
            class="rounded-xl py-3 flex items-center justify-center gap-2 transition-colors border-2"
            :class="audience === 'drivers' ? 'bg-brand-blue-base text-white border-brand-blue-base hover:bg-brand-blue-dark' : 'bg-white text-brand-slate-600 border-brand-slate-200 hover:bg-brand-slate-50'"
            @click="audience = 'drivers'"
          >
            <Bike class="w-5 h-5" />
            <span class="font-medium text-sm">Drivers Only</span>
          </button>
          <button 
            class="rounded-xl py-3 flex items-center justify-center gap-2 transition-colors border-2"
            :class="audience === 'passengers' ? 'bg-brand-blue-base text-white border-brand-blue-base hover:bg-brand-blue-dark' : 'bg-white text-brand-slate-600 border-brand-slate-200 hover:bg-brand-slate-50'"
            @click="audience = 'passengers'"
          >
            <User class="w-5 h-5" />
            <span class="font-medium text-sm">Passengers Only</span>
          </button>
        </div>
      </div>

      <!-- Textarea -->
      <div class="mt-6">
        <h3 class="font-bold text-brand-slate-900 text-sm mb-3">Write Your Announcement</h3>
        <textarea 
          v-model="message"
          class="w-full border border-brand-slate-200 rounded-xl p-4 min-h-[160px] text-brand-slate-700 focus:outline-none focus:ring-2 focus:ring-brand-blue-base focus:border-transparent resize-y" 
          placeholder="Type your announcement here..."></textarea>
        <div class="flex justify-between items-center mt-1">
          <span class="text-brand-slate-400 text-sm">{{ message.length }} / 500 characters</span>
        </div>
      </div>

      <!-- Send Button -->
      <button 
        @click="sendNotification"
        :disabled="isSending || !message.trim()"
        class="mt-4 w-full bg-brand-blue-base hover:bg-brand-blue-dark text-white rounded-xl py-4 font-semibold flex items-center justify-center gap-2 transition-colors shadow-sm disabled:opacity-50"
      >
        <span>{{ isSending ? 'Sending...' : 'Send Notification' }}</span>
        <Send class="w-5 h-5" />
      </button>
      <p v-if="sendStatus" class="mt-2 text-sm" :class="sendStatus.includes('sent') ? 'text-green-600' : 'text-red-600'">{{ sendStatus }}</p>
    </div>

    <!-- Recent Announcements -->
    <div class="mt-8">
      <h2 class="text-lg font-bold text-brand-slate-900 mb-4">Recent Announcements</h2>
      
      <div class="bg-white rounded-xl shadow-md overflow-hidden">
        <div v-for="(announcement, index) in recentAnnouncements" :key="index" class="flex items-center gap-4 p-4 border-b border-brand-slate-100 hover:bg-brand-slate-50 transition-colors">
          <div class="w-10 h-10 rounded-full bg-brand-slate-100 text-brand-slate-500 flex items-center justify-center shrink-0">
            <Bell class="w-5 h-5" />
          </div>
          <div class="flex-1">
            <h4 class="font-bold text-brand-slate-900 text-sm">{{ announcement.title }}</h4>
            <p class="text-xs text-brand-slate-500 mt-1">
              {{ announcement.date }} &middot; <span class="text-brand-blue-base">{{ announcement.audience }}</span>
            </p>
          </div>
          <div class="shrink-0">
            <span class="inline-flex items-center px-2 py-1 rounded-full bg-green-100 text-green-700 text-xs font-semibold">
              SENT
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { MessageCircle, Users, Bike, User, Send, Bell } from '@lucide/vue';
import { useApi } from '@/composables/useApi';

const api = useApi();

const audience = ref('all');
const message = ref('');
const isSending = ref(false);
const sendStatus = ref('');

const recentAnnouncements = ref([]);

const loadAnnouncements = async () => {
  try {
    const res = await api.get('/notifications');
    recentAnnouncements.value = (res.data.data || []).slice(0, 10).map((n: any) => ({
      title: n.title,
      date: new Date(n.createdAt).toLocaleString(),
      audience: n.type || 'All Users',
    }));
  } catch (_) {}
};

const sendNotification = async () => {
  if (!message.value.trim()) return;
  isSending.value = true;
  try {
    await api.post('/notifications', {
      title: message.value.slice(0, 50),
      body: message.value,
      audience: audience.value,
    });
    sendStatus.value = 'Notification sent!';
    message.value = '';
    setTimeout(() => (sendStatus.value = ''), 3000);
    loadAnnouncements();
  } catch (_) {
    sendStatus.value = 'Failed to send';
  } finally {
    isSending.value = false;
  }
};

onMounted(loadAnnouncements);
</script>
