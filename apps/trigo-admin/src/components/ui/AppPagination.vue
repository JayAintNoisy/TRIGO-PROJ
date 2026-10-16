<template>
  <div
    v-if="total > 0"
    class="mt-4 flex flex-col items-center justify-between gap-3 border-t border-brand-slate-200 pt-4 sm:flex-row"
  >
    <!-- Range summary -->
    <p class="text-xs font-medium text-brand-slate-500">
      Showing
      <span class="font-bold text-brand-slate-900">{{ rangeStart }}–{{ rangeEnd }}</span>
      of
      <span class="font-bold text-brand-slate-900">{{ total }}</span>
      {{ total === 1 ? 'entry' : 'entries' }}
    </p>

    <div class="flex flex-wrap items-center justify-center gap-3">
      <!-- Page size -->
      <label class="flex items-center gap-2 text-xs font-medium text-brand-slate-500">
        Rows per page
        <select
          :value="pageSize"
          class="cursor-pointer rounded-lg border border-brand-slate-200 bg-white px-2 py-1 text-xs font-semibold text-brand-slate-700 focus:border-brand-blue-base focus:outline-none focus:ring-2 focus:ring-brand-blue-base/30"
          @change="onPageSizeChange"
        >
          <option v-for="size in pageSizes" :key="size" :value="size">{{ size }}</option>
        </select>
      </label>

      <!-- Page navigation -->
      <nav class="flex items-center gap-1" aria-label="Pagination">
        <button
          type="button"
          class="inline-flex h-8 w-8 items-center justify-center rounded-lg border border-brand-slate-200 text-brand-slate-600 transition-colors hover:bg-brand-slate-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
          :disabled="page <= 1"
          aria-label="Previous page"
          @click="emit('update:page', page - 1)"
        >
          <ChevronLeft class="h-4 w-4" />
        </button>

        <template v-for="(entry, index) in pageNumbers" :key="`${entry}-${index}`">
          <span
            v-if="entry === '…'"
            class="inline-flex h-8 w-8 items-center justify-center text-xs font-bold text-brand-slate-400"
          >
            …
          </span>
          <button
            v-else
            type="button"
            class="inline-flex h-8 min-w-8 items-center justify-center rounded-lg border px-2 text-xs font-bold transition-colors"
            :class="entry === page
              ? 'border-brand-blue-base bg-brand-blue-base text-white shadow-sm shadow-blue-500/25'
              : 'border-brand-slate-200 text-brand-slate-600 hover:bg-brand-slate-50'"
            :aria-current="entry === page ? 'page' : undefined"
            :aria-label="`Page ${entry}`"
            @click="emit('update:page', entry)"
          >
            {{ entry }}
          </button>
        </template>

        <button
          type="button"
          class="inline-flex h-8 w-8 items-center justify-center rounded-lg border border-brand-slate-200 text-brand-slate-600 transition-colors hover:bg-brand-slate-50 disabled:cursor-not-allowed disabled:opacity-40 disabled:hover:bg-white"
          :disabled="page >= totalPages"
          aria-label="Next page"
          @click="emit('update:page', page + 1)"
        >
          <ChevronRight class="h-4 w-4" />
        </button>
      </nav>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { ChevronLeft, ChevronRight } from '@lucide/vue';

const props = withDefaults(
  defineProps<{
    /** Current 1-based page. */
    page: number;
    /** Rows per page. */
    pageSize: number;
    /** Total rows across every page. */
    total: number;
    /** Selectable page sizes. */
    pageSizes?: number[];
  }>(),
  { pageSizes: () => [10, 25, 50, 100] }
);

const emit = defineEmits<{
  (event: 'update:page', value: number): void;
  (event: 'update:pageSize', value: number): void;
}>();

const totalPages = computed(() => Math.max(1, Math.ceil(props.total / props.pageSize)));
const rangeStart = computed(() => (props.total === 0 ? 0 : (props.page - 1) * props.pageSize + 1));
const rangeEnd = computed(() => Math.min(props.page * props.pageSize, props.total));

/** First/middle/last window so long lists never overflow the bar. */
const pageNumbers = computed<(number | '…')[]>(() => {
  const last = totalPages.value;
  const current = Math.min(Math.max(props.page, 1), last);
  if (last <= 7) return Array.from({ length: last }, (_, i) => i + 1);

  const pages: (number | '…')[] = [1];
  const from = Math.max(2, current - 1);
  const to = Math.min(last - 1, current + 1);
  if (from > 2) pages.push('…');
  for (let i = from; i <= to; i += 1) pages.push(i);
  if (to < last - 1) pages.push('…');
  pages.push(last);
  return pages;
});

const onPageSizeChange = (event: Event) => {
  emit('update:pageSize', Number((event.target as HTMLSelectElement).value));
};
</script>
