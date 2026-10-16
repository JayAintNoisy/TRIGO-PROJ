/// <reference types="vite/client" />

/// Variables the admin panel reads from `.env` (see .env.example).
interface ImportMetaEnv {
  /// Base URL of the TriGo API, e.g. http://localhost:4000/api
  readonly VITE_API_BASE_URL?: string;
  /// Public Mapbox token for the boundary mapper and the live tracking map.
  /// Optional: both fall back to the token the panel ships with.
  readonly VITE_MAPBOX_TOKEN?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
