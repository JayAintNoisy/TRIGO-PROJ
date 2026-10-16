import { envText } from './env.js';

/** Shown when VITE_APP_VERSION is not configured. Mirrors apps/trigo/pubspec.yaml. */
const DEFAULT_VERSION = '1.0.0';

/**
 * Resolve the advertised release identity.
 *
 * Rule (identical to `AppReleaseInfo` in the Flutter app):
 *   - version: trimmed non-empty string, otherwise the default version;
 *   - label: optional free text such as `demo`, `beta` or `rc`;
 *   - display: `1.0.0-demo` when labelled, or just `1.0.0` in production.
 *
 * @param {{ version?: string, label?: string }} input
 */
export function resolveRelease({ version = '', label = '' } = {}) {
  const resolvedVersion = String(version).trim() || DEFAULT_VERSION;
  const resolvedLabel = String(label).trim();

  return {
    version: resolvedVersion,
    label: resolvedLabel,
    isProduction: resolvedLabel === '',
    display: resolvedLabel === '' ? resolvedVersion : `${resolvedVersion}-${resolvedLabel}`,
  };
}

export const releaseInfo = resolveRelease({
  version: envText('APP_VERSION'),
  label: envText('RELEASE_LABEL'),
});
