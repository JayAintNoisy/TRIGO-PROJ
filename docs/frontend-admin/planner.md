# Frontend Admin Web App Planner

**Role**: Plan-only skill for the TriGo Vue 3 Admin Web App.
**Permission**: You are strictly a planner. Do **NOT** edit, create, or modify any project files unless the user explicitly asks you to. Your output is a structured plan for the implementer.

---

## Project Context

### Tech Stack
- **Framework**: Vue 3 (Composition API, `<script setup lang="ts">`)
- **Build**: Vite (`apps/trigo-admin/vite.config.ts`)
- **State**: Pinia (`apps/trigo-admin/src/stores/`)
- **Routing**: Vue Router with role-based auth guards (`apps/trigo-admin/src/router/index.ts`)
- **Language**: TypeScript (strict mode, no `any`)
- **Styling**: Tailwind CSS v4 utility classes (`@import "tailwindcss";` via `@theme` directives in `src/assets/styles/main.css`)
- **HTTP**: Axios via `useApi()` composable (`apps/trigo-admin/src/composables/useApi.ts`)
- **Structure**: Monorepo workspace — `apps/trigo-admin/`

### Design System: TriGo Admin Design Language
No heavy third-party component libraries. All UI elements are custom-built Vue 3 SFCs enforcing modern card elevation, rounded corners (24px cards, 12px inputs), and accessible status badges.

Available shared UI components in `src/components/ui/` & `src/components/layout/`:

| Component | File | Purpose |
|-----------|------|---------|
| `AppButton` | `components/ui/AppButton.vue` | Primary, secondary, danger, outline, ghost; sm/md/lg with loading spinners |
| `AppInput` | `components/ui/AppInput.vue` | Form input with label, placeholder, and validation error messages |
| `AppSelect` | `components/ui/AppSelect.vue` | Custom dropdown selector |
| `AppModal` | `components/ui/AppModal.vue` | Modal dialog with backdrop blur, keyboard ESC handling |
| `AppCard` | `components/ui/AppCard.vue` | Elevated card container with configurable headers |
| `AppTable` | `components/ui/AppTable.vue` | Responsive data table with styled header and row dividers |
| `AppBadge` | `components/ui/AppBadge.vue` | Status pills (success, warning, danger, info, neutral) |
| `AppSpinner` | `components/ui/AppSpinner.vue` | Animated loading spinner |
| `AppLogo` | `components/ui/AppLogo.vue` | TriGo Admin brand logo mark |
| `AppSidebar` | `components/layout/AppSidebar.vue` | Admin dashboard navigation sidebar |
| `AppNavbar` | `components/layout/AppNavbar.vue` | Top header bar showing route title & system health |
| `AppLayout` | `components/layout/AppLayout.vue` | Main container layout pairing sidebar and navbar |

### Design Tokens (Tailwind CSS v4)
All design tokens are configured in `src/assets/styles/main.css` under the `@theme` block and consumed via Tailwind CSS v4 utility classes:

| Token | Class / Variable Example | Purpose |
|-------|-------------------------|---------|
| Brand Blue Base | `bg-brand-blue-base`, `text-brand-blue-base` | Primary actions, header accents (`#2563EB`) |
| Brand Blue Light/Dark | `bg-brand-blue-light`, `bg-brand-blue-dark` | Hover & soft highlight states (`#60A5FA`, `#1D4ED8`) |
| Brand Green Base | `bg-brand-green-base`, `text-brand-green-base` | Active drivers, positive trends (`#10B981`) |
| Driver Orange | `bg-brand-orange-base` | Driver role accents & warnings (`#F97316`) |
| Admin Purple | `bg-brand-purple-base` | Revenue & financial stats (`#A855F7`) |
| Neutral Slate | `bg-brand-slate-50`, `text-brand-slate-900` | Backgrounds, text hierarchy (`#F8FAFC`, `#0F172A`) |
| Rounded Corners | `rounded-2xl` (24px), `rounded-xl` (12px), `rounded-full` | Friendly rounded component boundaries |

### Existing Views
| Domain | View | File Path |
|--------|------|-----------|
| `auth` | `AuthLogin.vue` | `src/features/auth/AuthLogin.vue` |
| `dashboard` | `DashboardView.vue` | `src/features/dashboard/DashboardView.vue` |
| `driver-applications` | `DriverApplicationsList.vue` | `src/features/driver-applications/DriverApplicationsList.vue` |
| `drivers` | `DriversList.vue` | `src/features/drivers/DriversList.vue` |
| `rides` | `RidesList.vue` | `src/features/rides/RidesList.vue` |
| `municipalities` | `MunicipalitiesList.vue` | `src/features/municipalities/MunicipalitiesList.vue` |
| `users` | `UsersList.vue` | `src/features/users/UsersList.vue` |
| `tracking` | `TrackingView.vue` | `src/features/tracking/TrackingView.vue` |
| `communication`| `CommunicationView.vue` | `src/features/communication/CommunicationView.vue` |
| `financial` | `FinancialView.vue` | `src/features/financial/FinancialView.vue` |
| `fare-matrix` | `FareMatrix.vue` | `src/features/fare-matrix/FareMatrix.vue` |
| `safety` | `SafetyView.vue` | `src/features/safety/SafetyView.vue` |

#### Recent View Enhancements (since `450e01b`)
- `UsersList.vue`: renders `firstName` + `lastName`.
- `DriverApplicationsList.vue`: status filters, `review`/`approve`/`reject` actions, authenticated blob docs viewer.
- `FareMatrix.vue`: per-municipality edits for `base_fare`, `per_km_rate`, `exclusive_multiplier`, `min_fare`, `night_surcharge`, `max_passengers`.
- `CommunicationView.vue`: broadcast to `all`/`drivers`/`customers` with recipient counts.
- `useApi.ts`: 401 interceptor redirects to login.
- `AppSidebar.vue`: nav label "Passengers" renamed to "Users" (matches the `users` directory view).

---

## Planning Process

When asked to plan a new Vue Admin feature or UI update, follow these steps in order:

### 1. Identify the Feature Domain
- Determine if this belongs in an existing feature folder (`src/features/<domain>/`) or requires a new domain.
- Folder names must be kebab-case (e.g., `driver-applications`, `municipalities`).

### 2. Component Architecture Tree
For each view, specify the component hierarchy:
- **Page Component**: The main route target (e.g. `MunicipalitiesList.vue`)
- **Modal / Form Dialogs**: Sub-components for creation/editing (e.g. `AppModal`, `AppInput`)
- **Shared UI Elements**: Reusable components from `src/components/ui/`

### 3. State & Data Flow Design
- **API Endpoints**: Specify method, route path, query params, and JSON body payload.
- **Pinia Store**: Define reactive state, getters, and async actions in `src/stores/`.
- **UI States**: Plan for Loading (`AppSpinner`), Error (Alert banner), Empty (Empty state table row), and Data states.

### 4. Route Registration & Navigation
- Path, route name, component lazy loading, and auth guards in `src/router/index.ts`.
- Sidebar navigation item in `src/components/layout/AppSidebar.vue`.

---

## Coding Standards (for the plan to reference)

- **Composition API**: `<script setup lang="ts">` exclusively.
- **No `any`**: Explicitly type reactive refs, props, and API response objects.
- **Tailwind CSS v4 Only**: Use Tailwind utility classes. Avoid inline style blocks.
- **Axios HTTP Client**: Use `useApi()` composable for all REST calls.

---

## Output Format

Provide the plan as structured text covering:
1. Feature domain & file structure
2. Component tree & layout specs
3. Pinia store & API service design
4. Route definition & sidebar navigation link
5. Loading, error, and empty state strategy
