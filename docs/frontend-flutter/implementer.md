# Frontend Flutter Mobile App Implementer

**Role**: Implementation skill for the TriGo Native Mobile App (Android & iOS).
**Permission**: You **CAN** create, edit, and modify Dart files in `apps/trigo/lib/`. You **CAN** run `flutter analyze` and `flutter test`.
**Pre-requisite**: You **MUST** have a plan before implementing. If no plan is provided, request one from the user.

---

## Project Context

### Target Platform
- **Primary Targets**: **Native Mobile App (Android & iOS)** for Passengers and Drivers in the field.

### Tech Stack
- **Framework**: Flutter 3.x (Dart 3.x)
- **State**: Riverpod (`flutter_riverpod`)
- **Navigation**: `go_router` (`GoRouter`)
- **Theme**: `flex_color_scheme` (`FlexThemeData.light`)
- **Directory**: `apps/trigo/lib/`

---

## Implementation Patterns

### 1. ConsumerWidget Standard
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_top_bar.dart';
import '../providers/feature_provider.dart';

class FeatureScreen extends ConsumerWidget {
  const FeatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(featureProvider);

    return Scaffold(
      appBar: const AppTopBar(title: 'Feature Title'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              AppCard(
                child: Text(
                  'Feature Content',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                label: 'Submit Action',
                onPressed: () {
                  ref.read(featureProvider.notifier)
                    .performAction();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 2. Form + Validation Standard
```dart
import '../../../../shared/widgets/app_input.dart';
import '../../../../shared/utils/input_validators.dart';

final formKey = GlobalKey<FormState>();
// In Scaffold body:
Form(
  key: formKey,
  child: Column(
    children: [
      AppInput(
        label: 'Email',
        controller: emailCtrl,
        keyboardType: TextInputType.emailAddress,
        validator: InputValidators.email,
      ),
      AppInput(
        label: 'Password',
        isPassword: true,
        validator: (v) => InputValidators.minLength(
          6, v, 'Password must be at least 6 chars'),
      ),
    ],
  ),
);
// Submit:
if (!formKey.currentState!.validate()) return;
```

### 3. Auth & Mode Notes
- `AuthState` holds `driverStatus` + `activeMode`; `auth_provider.dart` exposes `hasOnboarded()`/`_markOnboarded()` and `refreshCurrentUser()` for post-approval refresh; mode is backend-derived (`_modeFor`).
- `UserData` has `firstName`/`lastName` + computed `name`; `driverStatus` parsed from `driverProfile.applicationStatus`.
- Register via `firstName`/`lastName` (two fields, `Row` layout) + `confirmPassword` validated with `InputValidators.matches`.
- `register()` accepts `asDriver`; the backend stores `driver_intent` and `/auth/me` returns `driverIntent`. `AuthState._modeFor` prefers driver mode when `driverIntent` is true, so an unverified registrant is dropped straight into driver onboarding after a restart.
- Boot gate: `app.dart` runs a connectivity check (`connectivity_plus`, fail-open) + `tryAutoLogin` in a post-frame callback and only mounts the router once `AuthState.isBootstrapped`; `app_splash_screen.dart` is the pre-bootstrap splash.

### 4. Maps (Mapbox) Notes
- `main.dart` calls `MapboxOptions.setAccessToken(dotenv['MAPBOX_PUBLIC_TOKEN'])` at startup and `MapboxMapsOptions.setTileStoreUsageMode(TileStoreUsageMode.READ_AND_UPDATE)` for offline tile caching. `MAPBOX_PUBLIC_TOKEN` lives in `.env` (see `.env.example`).
- Native prerequisites (already wired): Android `app/build.gradle.kts` adds `id("kotlin-android")` (required by the Mapbox Gradle plugin under AGP 9); root `android/build.gradle.kts` applies `kotlin-android` to `:mapbox_maps_flutter`; `AndroidManifest.xml` declares `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`; iOS `Info.plist` declares `NSLocationWhenInUseUsageDescription`.
- `shared/utils/municipality_locator.dart`: `locateMunicipality(lat, lng, list)` → nearest `MunicipalityMatch` (`centerLat`/`centerLng`/`radiusKm`); `boundaryRing(m)` → circular polygon ring for `PolygonAnnotationManager`.
- Map widgets (`*_map_view.dart`, `service_area_map_picker.dart`) render a full-screen `MapWidget` inside a `Stack`; annotation taps use `addInteraction(TapInteraction(FeaturesetDescriptor(layerId: ...), action))` and read `feature.id?.id`.

---

## Strict Flutter Quality Rules

1. **Zero Deprecation Warnings**:
   - No `withOpacity()` → `.withValues(alpha: 0.5)`
   - No `surfaceVariant` → `surfaceContainerHighest`
   - No `activeColor` → `activeThumbColor`
2. **Font Weights**: `FontWeight.w800` for extrabold.
3. **No Hardcoded Hex Colors**: Use `Theme.of(context)` or `AppColors`.
4. **Headers & Inputs**:
    - Use `AppTopBar` for every screen header, **except** full-screen map screens (`driver_home`, `customer_home`) which use a floating notification button over a `Stack` + `MapWidget`.
    - `AppInput` is `TextFormField`; always supply `validator` via `InputValidators`.
5. **Icons & Styling**:
   - No emojis; use Material Icons.
   - Soft `BoxShadow` (`alpha:0.05`, blur 10) for cards; `grey.shade100/200` for dividers.
6. **Verification**: `flutter analyze` + `flutter test` in `apps/trigo/`.
