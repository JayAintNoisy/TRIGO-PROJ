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
- **Structure**: Monorepo workspace — `apps/trigo/`

### Dual-Role Architecture (Passenger ↔ Driver Toggle)
The mobile app serves both passengers and drivers natively on mobile devices. Users can switch modes dynamically via the `AppModeSwitch` header widget.
- **Passenger Mode**: Book tricycle rides, set pickup/dropoff, view live ETA, rate drivers.
- **Driver Mode**: Go online/offline, receive dispatch ride requests, navigate to pickup, complete rides, view gross earnings.

### Key Directory Structure
```
apps/trigo/lib/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart             # FlexThemeData light theme definitions
│   │   ├── app_colors.dart            # Brand Blue, Brand Green, Driver Orange tokens
│   │   └── app_typography.dart        # Text styles (FontWeight.w800 for headings)
│   ├── constants/
│   │   ├── api_endpoints.dart         # Backend REST API endpoint URLs
│   │   └── ride_status.dart           # Ride lifecycle constants
│   ├── router/
│   │   └── app_router.dart            # go_router configuration with mode routes
├── shared/
│   └── widgets/
│       ├── app_button.dart            # Primary, secondary, outline, ghost variants
│       ├── app_input.dart             # Form text fields with labels
│       ├── app_card.dart              # Card surface with soft elevation & 24px radius
│       └── app_mode_switch.dart        # Passenger ↔ Driver toggle widget
└── features/
    ├── auth/                          # LoginScreen, RegisterScreen, authProvider
    ├── home/                          # CustomerHomeScreen, DriverHomeScreen
    ├── ride_booking/                  # BookingScreen, RideTrackingScreen, RideCompleteScreen
    ├── driver_application/            # DriverApplicationScreen, DriverStatusScreen
    ├── earnings/                      # EarningsScreen (hero green card & trips)
    └── profile/                       # ProfileScreen & mode actions
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

- **No Deprecated APIs**: Use `.withValues(alpha: ...)` instead of `.withOpacity()`, and `surfaceContainerHighest` instead of `surfaceVariant`.
- **Font Weights**: Use `FontWeight.w800` for extrabold text.
- **Theme Consistency**: All widgets reference `Theme.of(context)` or `FlexThemeData`.
- **Icons & Styling**: Do NOT use emojis for UI icons; always use standard Flutter/Material Icons. Prefer soft shadows over hard borders for elevated surfaces, and use lighter colors for dividers.
- **Static Analysis**: Code must pass `flutter analyze` with 0 errors and 0 warnings.
