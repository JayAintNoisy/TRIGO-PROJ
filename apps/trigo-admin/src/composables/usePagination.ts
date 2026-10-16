import { computed, ref, watch, type ComputedRef, type Ref } from 'vue';

/** A reactive array the pagination slices. */
export type PaginationSource<T> = Ref<T[]> | ComputedRef<T[]>;

export interface UsePaginationOptions {
  /** Rows shown per page. Defaults to 10. */
  pageSize?: number;
}

/**
 * Client-side pagination over a reactive list.
 *
 * The backend list endpoints return whole arrays without page metadata, so
 * pages slice locally. Clamping is reactive: when a filter (or a refetch)
 * shrinks the list, the current page follows instead of stranding the user on
 * a blank page.
 */
export function usePagination<T>(source: PaginationSource<T>, options: UsePaginationOptions = {}) {
  const pageSize = ref(options.pageSize ?? 10);
  const page = ref(1);

  const items = computed<T[]>(() => source.value ?? []);
  const totalItems = computed(() => items.value.length);
  const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / pageSize.value)));

  const pageItems = computed<T[]>(() => {
    const start = (page.value - 1) * pageSize.value;
    return items.value.slice(start, start + pageSize.value);
  });

  const rangeStart = computed(() =>
    totalItems.value === 0 ? 0 : (page.value - 1) * pageSize.value + 1
  );
  const rangeEnd = computed(() => Math.min(page.value * pageSize.value, totalItems.value));

  const canPrev = computed(() => page.value > 1);
  const canNext = computed(() => page.value < totalPages.value);

  const goTo = (target: number) => {
    const wanted = Number.isFinite(target) ? Math.trunc(target) : 1;
    page.value = Math.min(Math.max(wanted, 1), totalPages.value);
  };
  const next = () => goTo(page.value + 1);
  const prev = () => goTo(page.value - 1);
  const reset = () => { page.value = 1; };
  const setPageSize = (size: number) => {
    pageSize.value = Math.max(1, Math.trunc(size) || 1);
    reset();
  };

  // Keep the page in range when rows disappear (filtering, deletion, refetch).
  watch(totalPages, (max) => {
    if (page.value > max) page.value = max;
  });

  return {
    page,
    pageSize,
    pageItems,
    totalItems,
    totalPages,
    rangeStart,
    rangeEnd,
    canPrev,
    canNext,
    goTo,
    next,
    prev,
    reset,
    setPageSize,
  };
}
