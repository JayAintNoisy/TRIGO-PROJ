<template>
  <div class="w-full overflow-x-auto rounded-xl shadow-md">
    <table class="w-full text-left text-sm text-brand-slate-900">
      <thead class="bg-brand-slate-50 border-b border-brand-slate-200 text-xs font-semibold text-brand-slate-500 uppercase tracking-wider">
        <tr>
          <slot name="headers" />
        </tr>
      </thead>
      <tbody class="divide-y divide-brand-slate-200 bg-white">
        <slot name="rows" />
      </tbody>
    </table>
  </div>
</template>
