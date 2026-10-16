/// Mapbox GL JS is loaded from a CDN by index.html, so it arrives as a browser
/// global rather than an import (the same pattern the municipality boundary
/// mapper uses). This module keeps the token in one place and makes a blocked
/// or missing CDN detectable instead of an exception.

declare const mapboxgl: any;

/// Public Mapbox token. `VITE_MAPBOX_TOKEN` wins so a deployment can rotate the
/// token without a code change; the fallback is the token this panel has always
/// shipped with, kept so existing setups keep working.
export const MAPBOX_TOKEN: string =
  import.meta.env.VITE_MAPBOX_TOKEN ||
  'pk.eyJ1Ijoia2VudHgiLCJhIjoiY210NWJ1bndqMDdidjJ3czU4ajRpdHl5eiJ9.bIrzKPttbOo0gAf4_jtj5g';

export const MAP_STYLE = 'mapbox://styles/mapbox/streets-v12';

/// The Mapbox global, or null when the CDN script did not load (offline,
/// blocked, or a CSP that rejects it).
export function getMapbox(): any {
  return typeof mapboxgl === 'undefined' ? null : mapboxgl;
}

/// True when the library is usable; sets the access token as a side effect.
export function isMapboxReady(): boolean {
  const lib = getMapbox();
  if (!lib) return false;
  lib.accessToken = MAPBOX_TOKEN;
  return true;
}
