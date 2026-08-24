# Integration Feature Planner

**Role**: Plan-only skill for end-to-end API integration between TriGo Backend, Vue 3 Admin Web App, and Flutter Mobile App.
**Permission**: You are strictly a planner. Do **NOT** edit, create, or modify project files unless explicitly asked.

---

## Project Context

### API Client Architecture
- **Vue Admin Web App**: Uses Axios via `useApi()` composable (`apps/trigo-admin/src/composables/useApi.ts`).
- **Flutter Mobile App**: Uses Dio HTTP client with `api_client.dart` & `auth_interceptor.dart` (`apps/trigo/lib/core/network/`).
- **Bruno Collection**: Pre-configured collection at `apps/trigo-backend/bruno/`.

---

## Planning Integration Endpoints

When planning API integration:
1. Define unified JSON API response shape:
    ```json
    {
      "success": true,
      "data": {},
      "error": null
    }
    ```
2. Verify token storage:
    - Web Admin: `localStorage.setItem('trigo_admin_token', token)`
    - Flutter App: `SharedPreferences` token persistence
3. Handle 401 Unauthorized token refresh sequence.

### Endpoints Added Since `450e01b`
| Area | Method & Path | Notes |
|------|---------------|-------|
| `uploads` | `POST /api/uploads` + `GET /api/uploads/:folder/:filename` | Multer, `driver-documents`, 5 MB, auth, strict filename pattern |
| `drivers` | `POST /drivers/applications`, `PATCH .../review`/`approve`/`reject`, `GET /drivers/applications/:id` (with docs) | Transactional doc replace; reviewing status |
| `municipalities` | `PATCH /municipalities/:id`, `DELETE /municipalities/:id` | Partial fare-matrix updates |
| `rides` | `POST /rides`, `PATCH /rides/:id/...`, `GET /rides/available`, `POST /rides/:id/rate` | Owner checks, cancel fees, idempotent ratings |
| `tracking` | `POST /tracking/location`, `GET /tracking/ride/:id` | `accuracy` + history points |
| `notifications` | `POST /notifications/broadcast`, `POST /notifications/device-token` | Audience `all`/`drivers`/`customers`; `device_tokens` unique per user/platform |
| `auth` | `POST /auth/register` (optional `asDriver` → sets `driver_intent`), `POST /auth/logout`, `GET /auth/me` (includes `driverProfile` and `driverIntent`) | First/last name fields |
