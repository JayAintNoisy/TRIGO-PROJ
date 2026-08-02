# TriGo — Project Plan

Digital platform to streamline tricycle ride booking for both locals and tourists. Similar to Angkas/Maxim but catering to tricycles and motorcabs, with routes limited to municipality jurisdiction.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Mobile App** | Flutter + Riverpod + Freezed + json_serializable + go_router + Dio + Retrofit + flex_color_scheme |
| **Admin Web** | Vue 3 (Composition API) + TypeScript (strict) + TailwindCSS |
| **Backend** | Express.js + TypeScript (strict) |
| **Database** | PostgreSQL |
| **Auth** | JWT (access + refresh tokens) |
| **Validation** | Zod (backend), Freezed + json_serializable (Flutter) |
| **API Client** | Dio + Retrofit (Flutter), Axios (Admin), Bruno (backend collection) |
| **Linting** | ESLint + Prettier (JS/TS), flutter_lints (Dart) |
| **Structure** | Monorepo (npm workspaces + separate Flutter projects) |

---

## Why Monorepo?

- **Shared backend** — Both the mobile app and admin web consume the same Express API.
- **Unified scripts** — Root-level commands to start all services in parallel.
- **Consistent tooling** — One ESLint/Prettier config for JS/TS projects.
- **Independent deployment** — Each project can be deployed separately (Flutter to app stores, Admin to web hosting, Backend to VPS).
- **Shared types** — API contracts defined in one place, referenced by all clients.

---

## Monorepo Structure

```
trigo/
├── apps/
│   ├── trigo/                    # Unified Flutter app (customer + driver roles)
│   │   ├── lib/
│   │   ├── android/
│   │   ├── ios/
│   │   ├── pubspec.yaml
│   │   └── ...
│   ├── trigo-admin/              # Vue.js Admin web app
│   │   ├── src/
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── vite.config.ts
│   │   └── ...
│   └── trigo-backend/            # Express.js backend
│       ├── src/
│       ├── package.json
│       ├── tsconfig.json
│       └── ...
├── docs/
│   ├── frontend/
│   │   ├── planner.md
│   │   └── implementer.md
│   ├── backend/
│   │   ├── planner.md
│   │   └── implementer.md
│   ├── integration/
│   │   ├── planner.md
│   │   └── implementer.md
│   └── bug-fixing/
│       ├── planner.md
│       └── implementer.md
├── package.json                  # Root workspace config
├── tsconfig.base.json            # Shared TS config
├── .eslintrc.js                  # Shared ESLint config
├── .prettierrc                   # Shared Prettier config
└── PLAN.md
```

---

## Architecture: Feature Domain-Driven

All backend code is organized by business domain. Each feature contains its own routes, controller, service, repository, schema, types, constants, and tests.

```
apps/trigo-backend/src/
├── features/
│   ├── auth/
│   │   ├── auth.routes.ts
│   │   ├── auth.controller.ts
│   │   ├── auth.service.ts
│   │   ├── auth.repository.ts
│   │   ├── auth.schema.ts
│   │   ├── auth.types.ts
│   │   ├── auth.constants.ts
│   │   └── auth.test.ts
│   ├── users/
│   │   ├── users.routes.ts
│   │   ├── users.controller.ts
│   │   ├── users.service.ts
│   │   ├── users.repository.ts
│   │   ├── users.schema.ts
│   │   ├── users.types.ts
│   │   └── users.test.ts
│   ├── drivers/
│   │   ├── drivers.routes.ts
│   │   ├── drivers.controller.ts
│   │   ├── drivers.service.ts
│   │   ├── drivers.repository.ts
│   │   ├── drivers.schema.ts
│   │   ├── drivers.types.ts
│   │   ├── drivers.constants.ts
│   │   └── drivers.test.ts
│   ├── rides/
│   │   ├── rides.routes.ts
│   │   ├── rides.controller.ts
│   │   ├── rides.service.ts
│   │   ├── rides.repository.ts
│   │   ├── rides.schema.ts
│   │   ├── rides.types.ts
│   │   ├── rides.constants.ts
│   │   └── rides.test.ts
│   ├── tracking/
│   │   ├── tracking.routes.ts
│   │   ├── tracking.controller.ts
│   │   ├── tracking.service.ts
│   │   ├── tracking.repository.ts
│   │   ├── tracking.types.ts
│   │   └── tracking.test.ts
│   ├── municipalities/
│   │   ├── municipalities.routes.ts
│   │   ├── municipalities.controller.ts
│   │   ├── municipalities.service.ts
│   │   ├── municipalities.repository.ts
│   │   ├── municipalities.schema.ts
│   │   ├── municipalities.types.ts
│   │   └── municipalities.test.ts
│   ├── payments/
│   │   ├── payments.routes.ts
│   │   ├── payments.controller.ts
│   │   ├── payments.service.ts
│   │   ├── payments.repository.ts
│   │   ├── payments.schema.ts
│   │   ├── payments.types.ts
│   │   ├── payments.constants.ts
│   │   └── payments.test.ts
│   └── notifications/
│       ├── notifications.routes.ts
│       ├── notifications.controller.ts
│       ├── notifications.service.ts
│       ├── notifications.types.ts
│       └── notifications.test.ts
├── shared/
│   ├── database/
│   │   ├── connection.ts
│   │   ├── migrate.ts
│   │   └── seed.ts
│   ├── errors/
│   │   ├── app-error.ts
│   │   ├── error-handler.ts
│   │   └── error-codes.ts
│   ├── logging/
│   │   ├── logger.ts
│   │   ├── access-logger.ts
│   │   └── logs.routes.ts
│   ├── middleware/
│   │   ├── authenticate.ts
│   │   ├── authorize.ts
│   │   └── validate.ts
│   ├── constants/
│   │   ├── roles.ts
│   │   ├── ride-status.ts
│   │   ├── payment-status.ts
│   │   └── pagination.ts
│   └── utils/
│       ├── calculate-distance.ts
│       ├── calculate-fare.ts
│       └── calculate-fare.test.ts
├── app.ts
├── server.ts
└── env.ts
```

---

## Flutter App Architecture (Unified App)

The unified Flutter app serves both customers and drivers. The user's role determines which features are accessible via role-based navigation. A user can be both a customer and driver — they can switch modes from the app.

```
apps/trigo/lib/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart            # flex_color_scheme theme definition
│   │   ├── app_colors.dart           # Color constants
│   │   └── app_typography.dart       # Text styles
│   ├── constants/
│   │   ├── api_endpoints.dart
│   │   ├── app_constants.dart
│   │   └── ride_status.dart
│   ├── errors/
│   │   ├── app_exception.dart
│   │   └── error_handler.dart
│   ├── network/
│   │   ├── dio_provider.dart         # Dio instance with interceptors
│   │   ├── api_client.dart           # Retrofit API client
│   │   └── auth_interceptor.dart     # JWT token interceptor
│   ├── router/
│   │   ├── app_router.dart           # go_router configuration (role-aware)
│   │   └── route_guards.dart
│   └── utils/
│       ├── location_utils.dart
│       └── fare_calculator.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── user.dart              # Freezed model (includes role)
│   │   │   │   ├── user.freezed.dart
│   │   │   │   ├── user.g.dart
│   │   │   │   ├── login_request.dart
│   │   │   │   └── auth_response.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── services/
│   │   │       └── auth_api.dart
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── register_screen.dart
│   │   │   ├── providers/
│   │   │   │   ├── auth_provider.dart     # Riverpod provider (tracks role)
│   │   │   │   └── auth_state.dart        # Freezed state
│   │   │   └── widgets/
│   │   │       └── auth_form.dart
│   │   └── auth_feature.dart
│   ├── home/
│   │   ├── data/
│   │   │   └── models/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── customer_home_screen.dart   # Map + book ride
│   │   │   │   └── driver_home_screen.dart     # Online/offline toggle, ride requests
│   │   │   └── providers/
│   │   │       └── home_provider.dart
│   │   └── home_feature.dart
│   ├── ride_booking/                      # Customer features
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── ride.dart
│   │   │   │   ├── ride.freezed.dart
│   │   │   │   ├── ride.g.dart
│   │   │   │   ├── ride_request.dart
│   │   │   │   └── fare_estimate.dart
│   │   │   ├── repositories/
│   │   │   │   └── ride_repository.dart
│   │   │   └── services/
│   │   │       └── ride_api.dart
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── booking_screen.dart
│   │   │   │   ├── ride_tracking_screen.dart
│   │   │   │   └── ride_complete_screen.dart
│   │   │   ├── providers/
│   │   │   │   ├── booking_provider.dart
│   │   │   │   └── ride_tracking_provider.dart
│   │   │   └── widgets/
│   │   │       ├── location_picker.dart
│   │   │       ├── fare_display.dart
│   │   │       └── driver_info_card.dart
│   │   └── ride_booking_feature.dart
│   ├── ride_requests/                     # Driver features
│   │   ├── data/
│   │   │   └── models/
│   │   │       ├── ride_request.dart
│   │   │       └── ride_offer.dart
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── ride_request_screen.dart
│   │   │   │   └── ride_detail_screen.dart
│   │   │   └── providers/
│   │   │       ├── ride_request_provider.dart
│   │   │       └── driver_status_provider.dart
│   │   └── ride_requests_feature.dart
│   ├── active_ride/                       # Driver features
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── navigation_screen.dart
│   │   │   │   └── ride_complete_screen.dart
│   │   │   └── providers/
│   │   │       └── active_ride_provider.dart
│   │   └── active_ride_feature.dart
│   ├── earnings/                          # Driver features
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── earnings_screen.dart
│   │   │   └── providers/
│   │   └── earnings_feature.dart
│   ├── ride_history/
│   │   ├── data/
│   │   │   └── models/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   └── ride_history_screen.dart
│   │   │   └── providers/
│   │   └── ride_history_feature.dart
│   ├── driver_application/                # Customer → Driver transition
│   │   ├── data/
│   │   │   ├── models/
│   │   │   │   ├── driver_profile.dart
│   │   │   │   ├── driver_profile.freezed.dart
│   │   │   │   └── driver_profile.g.dart
│   │   │   ├── repositories/
│   │   │   │   └── driver_repository.dart
│   │   │   └── services/
│   │   │       └── driver_api.dart
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── driver_application_screen.dart
│   │   │   │   └── driver_status_screen.dart
│   │   │   └── providers/
│   │   │       └── driver_application_provider.dart
│   │   └── driver_application_feature.dart
│   └── profile/
│       ├── data/
│       │   └── models/
│       ├── presentation/
│       │   ├── screens/
│       │   │   ├── profile_screen.dart
│       │   │   └── edit_profile_screen.dart
│       │   └── providers/
│       └── profile_feature.dart
├── shared/
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_input.dart
│   │   ├── app_card.dart
│   │   ├── app_dialog.dart
│   │   ├── app_snackbar.dart
│   │   ├── app_loading.dart
│   │   ├── app_map.dart
│   │   ├── app_navbar.dart
│   │   ├── app_mode_switch.dart       # Customer ↔ Driver mode toggle
│   │   └── app_logo.dart
│   ├── models/
│   │   ├── api_response.dart
│   │   └── paginated_response.dart
│   └── utils/
│       ├── date_formatter.dart
│       └── currency_formatter.dart
├── app.dart
└── main.dart
```

---

## Admin Web App Architecture

```
apps/trigo-admin/src/
├── assets/
│   └── styles/
│       └── main.css                 # TailwindCSS entry
├── components/
│   ├── ui/
│   │   ├── AppButton.vue
│   │   ├── AppInput.vue
│   │   ├── AppSelect.vue
│   │   ├── AppModal.vue
│   │   ├── AppCard.vue
│   │   ├── AppTable.vue
│   │   ├── AppBadge.vue
│   │   ├── AppToast.vue
│   │   ├── AppSpinner.vue
│   │   └── AppLogo.vue
│   └── layout/
│       ├── AppNavbar.vue
│       ├── AppSidebar.vue
│       └── AppLayout.vue
├── composables/
│   ├── useApi.ts                    # Axios wrapper with auth
│   └── useToast.ts
├── features/
│   ├── auth/
│   │   ├── AuthLogin.vue
│   │   ├── auth.service.ts
│   │   ├── auth.types.ts
│   │   └── auth.guard.ts
│   ├── dashboard/
│   │   ├── DashboardView.vue
│   │   ├── dashboard.service.ts
│   │   └── dashboard.types.ts
│   ├── driver-applications/
│   │   ├── DriverApplicationsList.vue
│   │   ├── DriverApplicationDetail.vue
│   │   ├── driver-applications.service.ts
│   │   └── driver-applications.types.ts
│   ├── drivers/
│   │   ├── DriversList.vue
│   │   ├── DriverDetail.vue
│   │   ├── drivers.service.ts
│   │   └── drivers.types.ts
│   ├── rides/
│   │   ├── RidesList.vue
│   │   ├── RideDetail.vue
│   │   ├── rides.service.ts
│   │   └── rides.types.ts
│   ├── municipalities/
│   │   ├── MunicipalitiesList.vue
│   │   ├── MunicipalityDetail.vue
│   │   ├── municipalities.service.ts
│   │   └── municipalities.types.ts
│   └── users/
│       ├── UsersList.vue
│       ├── users.service.ts
│       └── users.types.ts
├── router/
│   └── index.ts
├── stores/
│   └── auth.store.ts
├── types/
│   └── api.ts
├── App.vue
└── main.ts
```

---

## Design System: TriGo Branding

### Theme (flex_color_scheme)

Colors, branding, and logo will be added later. The theme scaffold will use placeholder values that can be easily swapped.

```dart
// apps/trigo/lib/core/theme/app_theme.dart
class AppTheme {
  // Placeholder — will be replaced with actual brand colors
  static const Color primaryColor = Color(0xFF1565C0);    // Blue placeholder
  static const Color secondaryColor = Color(0xFF00897B);   // Teal placeholder
  static const Color accentColor = Color(0xFFFF6F00);      // Amber placeholder

  static ThemeData lightTheme() {
    return FlexThemeData.light(
      scheme: FlexScheme.custom,
      primary: primaryColor,
      secondary: secondaryColor,
      // ... full theme config
    );
  }

  static ThemeData darkTheme() {
    return FlexThemeData.dark(
      scheme: FlexScheme.custom,
      primary: primaryColor,
      secondary: secondaryColor,
      // ... full theme config
    );
  }
}
```

### Shared UI Components (Flutter)

| Component | File | Description |
|-----------|------|-------------|
| `AppButton` | `app_button.dart` | Primary, secondary, outline, ghost variants; size: sm, md, lg |
| `AppInput` | `app_input.dart` | Text input with label, error state, prefix/suffix |
| `AppCard` | `app_card.dart` | Elevated card with configurable padding |
| `AppDialog` | `app_dialog.dart` | Modal dialog with focus trap |
| `AppSnackbar` | `app_snackbar.dart` | Positioned notifications |
| `AppLoading` | `app_loading.dart` | Loading indicator (shimmer, spinner) |
| `AppMap` | `app_map.dart` | Google Maps wrapper for location |
| `AppNavbar` | `app_navbar.dart` | Bottom navigation bar |
| `AppLogo` | `app_logo.dart` | TriGo logo placeholder |

### Admin UI Components (Vue + TailwindCSS)

| Component | File | Description |
|-----------|------|-------------|
| `AppButton` | `AppButton.vue` | Primary, secondary, outline, ghost variants |
| `AppInput` | `AppInput.vue` | Text input with label, error state |
| `AppSelect` | `AppSelect.vue` | Dropdown with search |
| `AppModal` | `AppModal.vue` | Modal with backdrop, ESC close |
| `AppCard` | `AppCard.vue` | Elevated card |
| `AppTable` | `AppTable.vue` | Sortable columns, pagination |
| `AppBadge` | `AppBadge.vue` | Status pills |
| `AppToast` | `AppToast.vue` | Notification toasts |
| `AppSpinner` | `AppSpinner.vue` | Loading indicator |
| `AppNavbar` | `AppNavbar.vue` | Top navigation |
| `AppSidebar` | `AppSidebar.vue` | Dashboard sidebar |
| `AppLogo` | `AppLogo.vue` | TriGo logo placeholder |

---

## Maps & GPS Tracking

### Google Maps Integration

| Client | Integration |
|--------|------------|
| **Flutter (Customer mode)** | `google_maps_flutter` — Show driver location, route preview, pickup/dropoff markers |
| **Flutter (Driver mode)** | `google_maps_flutter` — Navigation to pickup/dropoff, real-time location broadcast |
| **Admin** | Google Maps JS API — Overview map showing all active rides |

### Driver GPS Tracking

Drivers periodically send GPS coordinates to the backend while on an active ride. The location is viewable by the customer whose ride is in progress and by the admin dashboard.

**Privacy rules:**
- A driver's location is tied to an active ride only.
- The customer can see the driver's position for their own ride only.
- Admin can see all active drivers on a map overview.
- Locations are anonymized after ride completion.

**Flow:**
1. Driver app sends `POST /api/tracking/location` every 10 seconds while on active ride.
2. Backend stores `{ driverId, rideId, lat, lng, accuracy, timestamp }`.
3. Customer polls `GET /api/rides/:id/tracking` — returns latest driver position.
4. Admin polls `GET /api/tracking/active` — returns all active driver positions.

---

## Feature Breakdown

### 1. Account System (2 Roles + Admin)

| Role | Capabilities |
|------|-------------|
| **User** | Book rides, view history, track active ride, rate driver, manage profile, apply to become a driver |
| **Driver** | Go online/offline, accept/reject ride requests, navigate to pickup, complete rides, view earnings |
| **Admin** | View dashboard, review driver applications, manage drivers, view all rides, manage municipalities |

- Users can hold both customer and driver roles simultaneously — they switch modes via a toggle in the app.
- JWT authentication with role-based middleware.
- Registration includes name, email, phone, password.
- Driver application is submitted after registration (requires document upload and admin approval).
- Roles defined as a TypeScript enum `USER_ROLE` (no magic strings).

### 2. Driver Application & Approval System

- Any registered user can apply to become a driver from within the app.
- Application requires: license number, tricycle details, municipality selection.
- Upload requirements: driver's license, tricycle registration, profile photo.
- Admin reviews applications — approve or reject with reason.
- Once approved, the user gains driver capabilities and can switch to driver mode.
- Driver status: `PENDING` → `APPROVED` | `REJECTED` | `SUSPENDED`

### 3. Ride Booking System

- Customer sets pickup and dropoff locations (within same municipality).
- Fare calculation based on distance + base fare + per-km rate.
- Nearby online drivers receive the ride request.
- Driver accepts → Customer notified → Driver navigates to pickup.
- Ride status as a TS enum `RIDE_STATUS`:
  - `REQUESTED` → `ACCEPTED` → `DRIVER_ARRIVING` → `IN_PROGRESS` → `COMPLETED` → `CANCELLED`
- Customer can cancel before driver accepts (free) or after accepting (cancellation fee).
- Driver can cancel with valid reason (tracked for quality).

### 4. Municipality Jurisdiction

- Each municipality has defined service boundaries (polygon or center + radius).
- Rides can only be booked within a single municipality's boundaries.
- Drivers are registered to a specific municipality and can only receive rides within that area.
- Cross-municipality rides are not supported in MVP.

### 5. Fare & Payment

- Fare = base_fare + (distance_km × per_km_rate)
- Each municipality can configure its own base fare and per-km rate.
- Payment methods: Cash (MVP), digital wallets (future).
- Payment status: `PENDING` → `COMPLETED` | `REFUNDED`

### 6. Rating & Review

- Customer rates driver after ride completion (1-5 stars + optional comment).
- Driver average rating is displayed on their profile.
- Low-rated drivers flagged for admin review.

### 7. Notifications

- Push notifications via Firebase Cloud Messaging (FCM).
- Events: ride accepted, driver arriving, ride completed, application status.
- In-app notification history.

---

## API Endpoints

### Auth
| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | `/api/auth/register` | Public | Register as user |
| POST | `/api/auth/login` | Public | Login |
| POST | `/api/auth/refresh` | Authenticated | Refresh token |
| GET | `/api/auth/me` | Authenticated | Get current user (includes driver profile if applicable) |

### Users
| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/api/users` | Admin | List all users |
| GET | `/api/users/:id` | Admin | Get user detail |
| PUT | `/api/users/:id` | Authenticated | Update own profile |

### Drivers
| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | `/api/drivers/apply` | User | Submit driver application |
| GET | `/api/drivers/me` | Driver | Get own driver profile |
| GET | `/api/drivers` | Admin | List all drivers |
| GET | `/api/drivers/:id` | Admin | Get driver detail |
| GET | `/api/drivers/applications` | Admin | List pending applications |
| GET | `/api/drivers/applications/:id` | Admin | Get application detail |
| PATCH | `/api/drivers/applications/:id/approve` | Admin | Approve driver |
| PATCH | `/api/drivers/applications/:id/reject` | Admin | Reject driver |
| PATCH | `/api/drivers/:id/status` | Admin | Suspend/activate driver |
| PATCH | `/api/drivers/online-status` | Driver | Toggle online/offline |

### Rides
| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | `/api/rides` | Customer | Request a ride |
| GET | `/api/rides` | Admin (all), Customer (own), Driver (assigned) | List rides |
| GET | `/api/rides/:id` | Authenticated (scoped) | Get ride detail |
| POST | `/api/rides/:id/accept` | Driver | Accept ride request |
| POST | `/api/rides/:id/cancel` | Customer/Driver | Cancel ride |
| POST | `/api/rides/:id/arrive` | Driver | Mark arrived at pickup |
| POST | `/api/rides/:id/start` | Driver | Start ride |
| POST | `/api/rides/:id/complete` | Driver | Complete ride |
| POST | `/api/rides/:id/rate` | Customer | Rate completed ride |
| GET | `/api/rides/:id/tracking` | Customer (own), Admin | Get ride tracking data |

### Tracking (GPS)
| Method | Path | Role | Description |
|--------|------|------|-------------|
| POST | `/api/tracking/location` | Driver | Send GPS coordinates |
| GET | `/api/tracking/active` | Admin | Get all active driver positions |

### Municipalities
| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/api/municipalities` | Public | List all municipalities |
| GET | `/api/municipalities/:id` | Public | Get municipality detail |
| POST | `/api/municipalities` | Admin | Create municipality |
| PUT | `/api/municipalities/:id` | Admin | Update municipality |
| DELETE | `/api/municipalities/:id` | Admin | Delete municipality |
| PATCH | `/api/municipalities/:id/fare-config` | Admin | Update fare config |

### Payments
| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/api/payments` | Admin | List all payments |
| GET | `/api/payments/:id` | Admin | Get payment detail |
| GET | `/api/payments/ride/:rideId` | Authenticated (scoped) | Get payment for ride |

### Notifications
| Method | Path | Role | Description |
|--------|------|------|-------------|
| GET | `/api/notifications` | Authenticated | Get user notifications |
| PATCH | `/api/notifications/:id/read` | Authenticated | Mark as read |
| POST | `/api/notifications/register-device` | Authenticated | Register FCM token |

---

## Frontend Routes

### Unified Mobile App (Flutter - go_router)

| Path | Screen | Auth | Notes |
|------|--------|------|-------|
| `/` | Landing | Public | |
| `/login` | Login | Public | |
| `/register` | Register | Public | |
| `/home` | Home | Authenticated | Shows customer or driver home based on active mode |
| `/book` | Ride booking | Customer | |
| `/ride/:id/tracking` | Live ride tracking | Customer | |
| `/ride/:id/complete` | Ride completed + rate | Customer | |
| `/history` | Ride history | Customer | |
| `/driver/home` | Driver home | Driver | Online/offline toggle, incoming requests |
| `/driver/ride-request/:id` | Incoming ride request | Driver | |
| `/driver/ride/:id/navigate` | Navigation to pickup/dropoff | Driver | |
| `/driver/ride/:id/complete` | Ride completed | Driver | |
| `/driver/earnings` | Earnings dashboard | Driver | |
| `/driver/apply` | Driver application | User | For users who want to become drivers |
| `/driver/status` | Application status | User | Pending/approved/rejected status |
| `/profile` | Profile | Authenticated | |
| `/profile/edit` | Edit profile | Authenticated | |

### Admin Web App (Vue Router)

| Path | View | Roles |
|------|------|-------|
| `/login` | Login page | Public |
| `/` | Dashboard | Admin |
| `/applications` | Driver applications list | Admin |
| `/applications/:id` | Application detail | Admin |
| `/drivers` | Active drivers list | Admin |
| `/drivers/:id` | Driver detail | Admin |
| `/rides` | All rides | Admin |
| `/rides/:id` | Ride detail | Admin |
| `/municipalities` | Municipalities list | Admin |
| `/municipalities/:id` | Municipality detail | Admin |
| `/users` | Users list | Admin |
| `/tracking` | Live tracking map | Admin |

---

## Database Schema (PostgreSQL)

### Tables

```sql
-- Users (all roles)
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  role VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'driver', 'admin')),
  profile_photo_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Driver profiles
CREATE TABLE driver_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  municipality_id UUID REFERENCES municipalities(id),
  license_number VARCHAR(50) NOT NULL,
  tricycle_plate_number VARCHAR(20) NOT NULL,
  tricycle_model VARCHAR(100),
  application_status VARCHAR(20) DEFAULT 'pending' CHECK (application_status IN ('pending', 'approved', 'rejected', 'suspended')),
  rejection_reason TEXT,
  is_online BOOLEAN DEFAULT false,
  current_lat DECIMAL(10, 8),
  current_lng DECIMAL(11, 8),
  average_rating DECIMAL(3, 2) DEFAULT 0,
  total_rides INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Driver application documents
CREATE TABLE driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_profile_id UUID REFERENCES driver_profiles(id) ON DELETE CASCADE,
  document_type VARCHAR(50) NOT NULL,
  document_url TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Municipalities
CREATE TABLE municipalities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  province VARCHAR(255),
  center_lat DECIMAL(10, 8) NOT NULL,
  center_lng DECIMAL(11, 8) NOT NULL,
  radius_km DECIMAL(5, 2) NOT NULL,
  base_fare DECIMAL(10, 2) NOT NULL DEFAULT 30.00,
  per_km_rate DECIMAL(10, 2) NOT NULL DEFAULT 10.00,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Rides
CREATE TABLE rides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES users(id),
  driver_id UUID REFERENCES users(id),
  municipality_id UUID REFERENCES municipalities(id),
  pickup_lat DECIMAL(10, 8) NOT NULL,
  pickup_lng DECIMAL(11, 8) NOT NULL,
  pickup_address TEXT,
  dropoff_lat DECIMAL(10, 8) NOT NULL,
  dropoff_lng DECIMAL(11, 8) NOT NULL,
  dropoff_address TEXT,
  status VARCHAR(20) DEFAULT 'requested' CHECK (status IN ('requested', 'accepted', 'driver_arriving', 'in_progress', 'completed', 'cancelled')),
  fare_estimate DECIMAL(10, 2),
  fare_final DECIMAL(10, 2),
  distance_km DECIMAL(8, 2),
  cancellation_reason TEXT,
  cancelled_by VARCHAR(10) CHECK (cancelled_by IN ('customer', 'driver')),
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Ride ratings
CREATE TABLE ride_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES users(id),
  driver_id UUID REFERENCES users(id),
  rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Ride tracking
CREATE TABLE ride_tracking (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID REFERENCES rides(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES users(id),
  lat DECIMAL(10, 8) NOT NULL,
  lng DECIMAL(11, 8) NOT NULL,
  accuracy DECIMAL(6, 2),
  timestamp TIMESTAMP DEFAULT NOW()
);

-- Payments
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id UUID REFERENCES rides(id),
  amount DECIMAL(10, 2) NOT NULL,
  method VARCHAR(20) DEFAULT 'cash' CHECK (method IN ('cash', 'gcash', 'card')),
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'refunded')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(50),
  is_read BOOLEAN DEFAULT false,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## Flutter Data Models (Freezed Examples)

### Ride Model

```dart
// apps/trigo/lib/features/ride_booking/data/models/ride.dart
@freezed
class Ride with _$Ride {
  const factory Ride({
    required String id,
    required String customerId,
    String? driverId,
    required String municipalityId,
    required double pickupLat,
    required double pickupLng,
    String? pickupAddress,
    required double dropoffLat,
    required double dropoffLng,
    String? dropoffAddress,
    required RideStatus status,
    double? fareEstimate,
    double? fareFinal,
    double? distanceKm,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? startedAt,
    DateTime? completedAt,
    required DateTime createdAt,
  }) = _Ride;

  factory Ride.fromJson(Map<String, dynamic> json) => _$RideFromJson(json);
}

@freezed
class RideStatus with _$RideStatus {
  const factory RideStatus.requested() = _Requested;
  const factory RideStatus.accepted() = _Accepted;
  const factory RideStatus.driverArriving() = _DriverArriving;
  const factory RideStatus.inProgress() = _InProgress;
  const factory RideStatus.completed() = _Completed;
  const factory RideStatus.cancelled() = _Cancelled;
}
```

### Driver Profile Model

```dart
// apps/trigo/lib/features/driver_application/data/models/driver_profile.dart
@freezed
class DriverProfile with _$DriverProfile {
  const factory DriverProfile({
    required String id,
    required String userId,
    required String municipalityId,
    required String licenseNumber,
    required String tricyclePlateNumber,
    String? tricycleModel,
    required ApplicationStatus applicationStatus,
    String? rejectionReason,
    required bool isOnline,
    double? currentLat,
    double? currentLng,
    required double averageRating,
    required int totalRides,
  }) = _DriverProfile;

  factory DriverProfile.fromJson(Map<String, dynamic> json) => _$DriverProfileFromJson(json);
}
```

### User Model (with dual role support)

```dart
// apps/trigo/lib/features/auth/data/models/user.dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String name,
    required String phone,
    String? profilePhotoUrl,
    DriverProfile? driverProfile,    // Non-null if user has applied/is a driver
    required DateTime createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

---

## Bruno API Client

```
apps/trigo-backend/bruno/
├── bruno.json
├── environments/
│   ├── local.bru
│   └── development.bru
└── requests/
    ├── health.bru
    ├── auth/
    │   ├── register.bru
    │   ├── login.bru
    │   └── me.bru
    ├── drivers/
    │   ├── list.bru
    │   ├── applications.bru
    │   └── approve.bru
    ├── rides/
    │   ├── create.bru
    │   ├── list.bru
    │   └── accept.bru
    └── municipalities/
        ├── list.bru
        └── create.bru
```

---

## Implementation Order

| Step | Task | Effort |
|------|------|--------|
| 1 | Scaffold monorepo structure (root configs, folder structure for all 3 projects) | Small |
| 2 | Backend — Express + TypeScript setup, env validation (Zod), PostgreSQL connection, health endpoint | Small |
| 3 | Backend — Shared layer: AppError, error handler, structured logger, auth middleware, validation middleware | Medium |
| 4 | Backend — Auth feature (register, login, refresh, me) | Medium |
| 5 | Backend — Users feature (CRUD, profile management) | Small |
| 6 | Backend — Municipalities feature (CRUD, fare configuration, boundary check) | Medium |
| 7 | Backend — Drivers feature (application, approval, online status, profile) | Medium |
| 8 | Backend — Rides feature (request, accept, status transitions, cancellation) | Large |
| 9 | Backend — Tracking feature (GPS location receive, active drivers endpoint) | Medium |
| 10 | Backend — Payments feature (create on ride complete, status management) | Small |
| 11 | Backend — Notifications feature (FCM integration, in-app notifications) | Medium |
| 12 | Backend — Seed data + Bruno collection | Small |
| 13 | Mobile App — Scaffold Flutter project (Riverpod, go_router, Dio, flex_color_scheme, Freezed setup) | Small |
| 14 | Mobile App — Design system: theme, shared UI components (AppButton, AppInput, AppCard, AppModeSwitch, etc.) | Medium |
| 15 | Mobile App — Auth feature (login, register, token management) | Medium |
| 16 | Mobile App — Customer home + Ride booking (map, location picker, fare estimate, ride request) | Large |
| 17 | Mobile App — Customer ride tracking (live driver location, status updates) | Medium |
| 18 | Mobile App — Driver home (online/offline toggle, ride request reception) | Medium |
| 19 | Mobile App — Driver active ride flow (accept, navigate, complete) | Large |
| 20 | Mobile App — Driver application flow (apply, upload documents, status tracking) | Medium |
| 21 | Mobile App — Earnings + Ride history + Profile | Medium |
| 22 | Mobile App — Mode switching (customer ↔ driver toggle) | Medium |
| 23 | Admin — Scaffold Vue.js + TypeScript + TailwindCSS project | Small |
| 24 | Admin — Design system: UI components (AppButton, AppInput, AppTable, etc.) | Medium |
| 25 | Admin — Auth feature (login, route guards) | Small |
| 26 | Admin — Dashboard (stats overview) | Medium |
| 27 | Admin — Driver applications (list, review, approve/reject) | Medium |
| 28 | Admin — Drivers management (list, detail, suspend/activate) | Medium |
| 29 | Admin — Rides management (list, detail, live tracking map) | Medium |
| 30 | Admin — Municipalities management (CRUD, fare config) | Medium |
| 31 | Admin — Users management (list, detail) | Small |
| 32 | Docs — Write all 8 skill set files (planner + implementer for frontend, backend, integration, bug-fixing) | Medium |
| 33 | Polish — Final error handling, responsive styling, pre-commit hooks | Small |

---

## Notes

- Single unified Flutter app — users can be both customers and drivers, switching modes via a toggle.
- Routes are strictly limited to municipality jurisdiction — cross-municipality rides are not supported in MVP.
- Cash payment is the primary method for MVP; digital wallets are a future enhancement.
- Driver approval is manual by admin; automated verification is a future enhancement.
- Google Maps is used for all mapping needs (no OpenStreetMap in this project).
- Firebase Cloud Messaging (FCM) for push notifications.
- Colors, branding, and logo will be added later — current theme uses placeholder values.
- All magic values (statuses, roles, thresholds) live in `constants/` files as enums or named exports.
- Driver GPS tracking is privacy-scoped: customers see only their own ride's driver; admin sees all active drivers.
- Freezed + json_serializable for all Dart data models; code generation must run before building.
- Riverpod for all state management — no setState or other state management solutions.
- go_router for all navigation — no Navigator.push usage.
