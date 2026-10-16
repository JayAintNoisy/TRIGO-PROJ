<template>
  <!-- TriGo brand tile carried over from the mobile app: a solid #2563EB
       rounded tile holding the white MaterialIcons "electric_rickshaw" glyph.
       Inline SVG keeps the mark crisp at any size and needs no network fetch. -->
  <span
    class="inline-flex shrink-0 items-center justify-center overflow-hidden"
    :style="{ width: `${size}px`, height: `${size}px`, borderRadius: `${Math.round(size * radius)}px` }"
  >
    <svg viewBox="0 0 48 48" class="h-full w-full" role="img" aria-label="TriGo">
      <rect width="48" height="48" fill="#2563EB" />
      <g fill="#FFFFFF" transform="translate(24 24) scale(1.1) translate(-12 -12)">
        <path
          d="M21,11.18V9.72c0-0.47-0.16-0.92-0.46-1.28L16.6,3.72C16.22,3.26,15.66,3,15.06,3H3C1.9,3,1,3.9,1,5v8c0,1.1,0.9,2,2,2 h0.18C3.6,16.16,4.7,17,6,17s2.4-0.84,2.82-2h8.37c0.41,1.16,1.51,2,2.82,2c1.66,0,3-1.34,3-3C23,12.7,22.16,11.6,21,11.18z M18.4,9H16V6.12L18.4,9z M3,5h4v4H3V5z M6,15c-0.55,0-1-0.45-1-1s0.45-1,1-1s1,0.45,1,1S6.55,15,6,15z M9,13v-2h3V9H9V5h5v8H9z M20,15c-0.55,0-1-0.45-1-1s0.45-1,1-1s1,0.45,1,1S20.55,15,20,15z"
        />
        <polygon points="7,20 11,20 11,18 17,21 13,21 13,23" />
      </g>
    </svg>
  </span>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    /** Rendered width and height in pixels. */
    size?: number;
    /** Corner radius as a fraction of [size]; 0.25 matches the app's splash tile. */
    radius?: number;
  }>(),
  { size: 36, radius: 0.25 }
);
</script>
