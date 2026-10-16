/**
 * Build-time environment access.
 *
 * Every key is read with a literal `import.meta.env.VITE_*` expression so Vite
 * inlines the value into the bundle. Running the module outside Vite (a Node
 * check, or a plain `<script type="module">` host) leaves `import.meta.env`
 * undefined, which the try/catch turns into "nothing configured" instead of a
 * crash — `envText` then reports an empty string for every key.
 */
let RAW;
try {
  RAW = {
    APP_VERSION: import.meta.env.VITE_APP_VERSION,
    RELEASE_LABEL: import.meta.env.VITE_APP_RELEASE_LABEL,
    API_BASE_URL: import.meta.env.VITE_API_BASE_URL,
    APK_URL: import.meta.env.VITE_APK_URL,
    APK_SIZE: import.meta.env.VITE_APK_SIZE,
  };
} catch {
  RAW = {};
}

export const ENV = RAW;

export function envText(key) {
  const value = ENV[key];
  return typeof value === 'string' ? value.trim() : '';
}
