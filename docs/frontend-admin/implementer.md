# Frontend Admin Web App Implementer

**Role**: Implementation skill for the TriGo Vue 3 Admin Web App.
**Permission**: You **CAN** create, edit, and modify project files in `apps/trigo-admin/`. You **CAN** run build tests and type-checking.
**Pre-requisite**: You **MUST** have a plan before implementing. If no plan is provided, request one from the user.

---

## Project Context

### Tech Stack
- **Framework**: Vue 3 (Composition API, `<script setup lang="ts">`)
- **Build**: Vite (`apps/trigo-admin/vite.config.ts`)
- **State**: Pinia (`apps/trigo-admin/src/stores/`)
- **Routing**: Vue Router with auth guards (`apps/trigo-admin/src/router/index.ts`)
- **Language**: TypeScript (strict, no `any`)
- **Styling**: Tailwind CSS v4 utility classes (`@import "tailwindcss";` in `src/assets/styles/main.css`)
- **HTTP**: Axios via `useApi()` composable (`apps/trigo-admin/src/composables/useApi.ts`)

### Key Directory Structure
```
apps/trigo-admin/src/
├── assets/
│   └── styles/
│       └── main.css               # Tailwind v4 entry + @theme
├── components/
│   ├── ui/                        # Primitives (AppButton, AppInput, etc.)
│   └── layout/                    # Sidebar, Navbar, Layout
├── composables/
│   └── useApi.ts                  # Axios + auth header + 401 redirect
├── features/
│   ├── auth/                      # Login view & service
│   ├── dashboard/                 # Stats & activity
│   ├── driver-applications/       # List + review/approve/reject + docs viewer
│   ├── drivers/                   # Directory & suspension toggle
│   ├── rides/                     # Ride history
│   ├── municipalities/            # Jurisdiction + FareMatrix
│   ├── users/                     # Directory (firstName + lastName)
│   ├── communication/             # Broadcast
│   ├── financial/                 # FinancialView
│   ├── safety/                    # SafetyView
│   └── tracking/                  # Live GPS map
├── router/
│   └── index.ts                   # Routes & guards
├── stores/
│   └── auth.store.ts              # Auth & token state
├── App.vue
└── main.ts
```

---

## Implementation Patterns

### 1. Vue SFC Component Standard
```vue
<script setup lang="ts">
import { ref, onMounted } from 'vue';
import AppCard from '@/components/ui/AppCard.vue';
import AppButton from '@/components/ui/AppButton.vue';
import AppSpinner from '@/components/ui/AppSpinner.vue';
import { useApi } from '@/composables/useApi';

interface DataItem {
  id: string;
  name: string;
  status: string;
}

const api = useApi();
const items = ref<DataItem[]>([]);
const loading = ref(false);
const error = ref('');

const fetchData = async () => {
  loading.value = true;
  error.value = '';
  try {
    const res = await api.get('/feature-endpoint');
    items.value = res.data.data;
  } catch (err: any) {
    error.value = err.response?.data?.error?.message || 'Failed to load data';
  } finally {
    loading.value = false;
  }
};

onMounted(fetchData);
</script>

<template>
  <div class="space-y-6">
    <AppCard>
      <div v-if="loading" class="flex justify-center p-8">
        <AppSpinner />
      </div>
      <div v-else-if="error" class="p-4 bg-red-50 text-red-600 rounded-xl text-sm font-semibold">
        {{ error }}
      </div>
      <div v-else-if="items.length === 0" class="p-8 text-center text-sm text-brand-slate-500">
        No records found.
      </div>
      <div v-else>
        <!-- Data rendering -->
      </div>
    </AppCard>
  </div>
</template>
```

### 2. Required UI States
Every data-fetching view **MUST** implement the 4 core UI states:
1. **Loading**: Show `<AppSpinner />` while requesting backend API data.
2. **Error**: Render error alert box with user-friendly error message.
3. **Empty**: Display clear empty state message when list arrays return empty.
4. **Data**: Render responsive, formatted data cards/tables.

---

## Verification Before Committing
1. Test TypeScript types: run `npx vite build` inside `apps/trigo-admin`.
2. Test backend API integration via `useApi()`.
3. Verify zero `any` types.
