import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Release identity of the running app build, resolved from the environment.
///
/// Two optional `.env` keys drive everything:
///
/// * `APP_RELEASE_VERSION` — the version to display. Trimmed; when absent or
///   blank it falls back to [defaultVersion] (`1.0.0`). Keep this in sync with
///   `pubspec.yaml`'s `version:` so the displayed value tracks the real build.
/// * `APP_RELEASE_LABEL` — an optional release channel such as `demo` or
///   `beta`. When absent, empty, or whitespace-only the build is treated as
///   **production**.
///
/// Displayed text is therefore:
///
/// * production (no label): `1.0.0`
/// * labelled: `1.0.0-demo` — the label is appended verbatim, so any text is
///   allowed.
///
/// A mirrored implementation lives in the landing page; both must agree on the
/// rule above.
class AppReleaseInfo {
  const AppReleaseInfo._();

  /// Version shown when `APP_RELEASE_VERSION` is missing or blank.
  static const String defaultVersion = '1.0.0';

  /// Reads one dotenv key without throwing when dotenv was never initialised
  /// (happens in `flutter test`) or when the `.env` asset failed to load.
  static String? _env(String key) {
    try {
      return dotenv.env[key];
    } catch (_) {
      // dotenv is not initialised: degrade to defaults rather than throwing.
      return null;
    }
  }

  /// Pure, testable implementation of the display rule.
  ///
  /// Values are trimmed; blank (null / empty / whitespace-only) counts as
  /// absent. A blank [version] yields [defaultVersion]; a blank [label] yields
  /// the production form, i.e. the bare version.
  static String resolveDisplay({String? version, String? label}) {
    final resolvedVersion = _normalize(version) ?? defaultVersion;
    final resolvedLabel = _normalize(label);
    return resolvedLabel == null
        ? resolvedVersion
        : '$resolvedVersion-$resolvedLabel';
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// The version to display; never blank.
  static String get version =>
      _normalize(_env('APP_RELEASE_VERSION')) ?? defaultVersion;

  /// The release channel label, or an empty string for production builds.
  static String get label => _normalize(_env('APP_RELEASE_LABEL')) ?? '';

  /// Whether this build carries no release channel label.
  static bool get isProduction => label.isEmpty;

  /// Text to show users: the version alone in production, otherwise
  /// `version-label` (e.g. `1.0.0-demo`).
  static String get display =>
      resolveDisplay(version: version, label: _env('APP_RELEASE_LABEL'));
}
