# Frontend Flutter Mobile App Planner

**Role**: Plan-only skill for the TriGo Native Mobile App (Android & iOS).
**Permission**: You are strictly a planner. Do **NOT** edit, create, or modify any project files unless the user explicitly asks you to. Your output is a structured plan for the implementer.

---

## Project Context

### Target Platform
- **Primary Targets**: **Native Mobile App (Android APK/Bundle & iOS IPA)** for Passengers and Drivers in the field.
- **Web App**: Reserved exclusively for the Vue 3 Admin Web Dashboard (`apps/trigo-admin`).

### Tech Stack
- **Framework**: Flutter 3.x (Dart 3.x)
- **State Management**: Riverpod (`flutter_riverpod`, `StateNotifierProvider`)
- **Navigation**: `go_router` (`GoRouter`)
- **Networking**: `dio` + `retrofit`
- **Models**: `freezed` + `json_serializable`
- **Theme**: `flex_color_scheme` (`FlexThemeData.light`)
- **Maps & Location**: `mapbox_maps_flutter` ^2.29.0 (replaced Google Maps) + `turf` ^0.0.12 for geometry; `geolocator` for GPS; `connectivity_plus` for the boot-time connectivity gate
- **Structure**: Monorepo workspace — `apps/trigo/`

### Dual-Role Architecture (Backend-Determined Mode)
The app serves passengers and drivers on one install. Mode is derived from the backend (`driverStatus`/`role` via `AuthState._modeFor`), not a free toggle. `app_mode_switch.dart` now exports only `enum AppUserMode`. Driver intent persists across restarts: registration sets `driver_intent` (exposed as `driverIntent` on `/auth/me`), and `AuthState._modeFor` defaults to driver mode when `driverIntent` is true even before a profile is approved.
- **Passenger Mode**: Book rides, set pickup/dropoff, live ETA, rate drivers.
- **Driver Mode**: Requires approved `driver_profiles.application_status`; go online/offline, incoming-request modal, earnings.
- **Verification gating**: `app_router.dart` redirects unverified drivers from `_driverBlockedRoutes` to `/driver/apply` or `/driver/status`; onboarding is gated by `hasOnboarded()` (`trigo_onboarded` in `SharedPreferences`).

### Key Directory Structure
```
apps/trigo/lib/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart             # FlexThemeData light theme
│   │   ├── app_colors.dart            # Brand tokens
│   │   └── app_typography.dart        # w800 headings
│   ├── constants/
│   │   ├── api_endpoints.dart         # REST URLs
│   │   └── ride_status.dart           # Ride status constants
│   ├── router/
│   │   └── app_router.dart            # GoRouter + driver verification gating
│   └── network/
│       ├── api_client.dart            # Dio + token storage
│       └── auth_interceptor.dart      # Bearer header + refresh
├── shared/
│   ├── widgets/
│   │   ├── app_button.dart            # Primary/secondary/outline/ghost
│   │   ├── app_input.dart             # TextFormField + validator/prefix/suffix
│   │   ├── app_card.dart              # Card, 24px radius, soft shadow
│   │   ├── app_top_bar.dart           # Blue header with back + centered title
│   │   ├── app_back_button.dart       # Reusable back with fallback
  │   │   ├── app_scaffold.dart          # Shell with bottom nav
  │   │   ├── app_splash_screen.dart     # Pre-bootstrap splash (boot gate)
  │   │   └── app_mode_switch.dart       # enum AppUserMode only
  │   └── utils/
  │       ├── input_validators.dart      # required/email/phone/matches/etc.
  │       ├── app_snackbar.dart          # Snack helper
  │       └── municipality_locator.dart  # locateMunicipality() + boundaryRing() (Mapbox)
└── features/
     ├── auth/                          # Login, Passenger/DriverRegister,
     │                                  # OnboardingScreen, authProvider
     ├── home/                          # CustomerHome (DraggableScrollableSheet booking sheet), DriverHome (map + location broadcast), HomeSwitcher; widgets/customer_map_view.dart, widgets/driver_map_view.dart
     ├── ride_booking/                  # Booking, PickDriver, Tracking,
     │                                  # Complete, Rating, incoming modal
     ├── driver_application/            # Application + Status + upload_repository; widgets/service_area_map_picker.dart (Mapbox)
     ├── earnings/                      # EarningsScreen
     ├── history/                       # HistoryScreen
     ├── notifications/                 # NotificationsScreen
     ├── profile/                       # Profile + Settings
     └── support/                       # HelpSupportScreen
```

---

## Planning Process

When asked to plan a new Flutter feature or screen update, follow these steps in order:

### 1. Identify Feature & Native Mobile Context
- Determine whether the feature is for Passenger Mode, Driver Mode, or Shared across both on mobile devices.
- Co-locate feature files under `lib/features/<feature_name>/`.

### 2. Widget Tree & Mobile Layout Architecture
- **Screen Widget**: StateNotifierConsumerWidget or ConsumerWidget for Riverpod integration.
- **Layout Structure**: Use `Scaffold`, `Stack` (for mobile GPS map views with floating bottom sheets), `SafeArea`, and `SingleChildScrollView`.
- **Theme Properties**: Access colors and typography strictly via `Theme.of(context)` or `AppColors`.

### 3. State Management (Riverpod)
- Define immutable state classes using `freezed` or pure Dart data models.
- Create `StateNotifier<FeatureState>` for state mutations.
- Expose state via `StateNotifierProvider`.

### 4. Router & Navigation (go_router)
- Register route path in `lib/core/router/app_router.dart`.

---

## Coding Standards (for the plan to reference)

- **No Deprecated APIs**: `.withValues(alpha:)` not `.withOpacity()`; `surfaceContainerHighest` not `surfaceVariant`; `activeThumbColor` not `activeColor`.
- **Font Weights**: `FontWeight.w800` for extrabold.
- **Theme Consistency**: Reference `Theme.of(context)` or `FlexThemeData`.
- **Forms**: Wrap inputs in `Form` + `GlobalKey<FormState>`; `AppInput` is `TextFormField` with `validator`/`prefixIcon`/`suffixIcon`; use `InputValidators` (`required`, `email`, `phone`, `minLength`, `matches`, `driverLicense`, `plateNumber`).
- **Headers**: Use `AppTopBar` (blue, centered, `AppBackButton`) not bare `AppBar`.
- **Icons & Styling**: No emojis; soft `BoxShadow` with `alpha:0.05` blur 10; `grey.shade100/200` for dividers.
- **Static Analysis**: `flutter analyze` 0 errors; `flutter test` must pass.
