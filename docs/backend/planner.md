# Backend Feature Planner

**Role**: Plan-only skill for the TriGo backend service.
**Permission**: You are strictly a planner. Do **NOT** edit, create, or modify any project files unless the user explicitly asks you to. Your output is a structured plan for the implementer.

---

## Project Context

### Tech Stack
- **Runtime**: Express.js + TypeScript (strict mode)
- **Database**: PostgreSQL (Strict SQL connection pool via `pg`, throws error if DB connection or migration fails)
- **Validation**: Zod schema validation middleware
- **Auth**: JWT (access + refresh tokens) + Role-based middleware (`USER_ROLE.ADMIN`, `USER_ROLE.DRIVER`, `USER_ROLE.CUSTOMER`)
- **Testing**: Vitest (unit & domain feature tests)
- **Structure**: Monorepo workspace — `apps/trigo-backend/`

### Architecture: Feature Domain-Driven
Code is organized by business domain. Each feature lives in `apps/trigo-backend/src/features/<domain>/`:

```
src/features/<domain>/
├── <domain>.routes.ts        # Express Router with validation & auth middleware
├── <domain>.controller.ts    # Controller (validates request, delegates to service)
├── <domain>.service.ts       # Core business logic & error handling
├── <domain>.repository.ts    # Pure PostgreSQL database query pool
├── <domain>.schema.ts        # Zod request validation schemas
├── <domain>.types.ts         # TypeScript interfaces & domain entities
├── <domain>.constants.ts     # Domain-specific enums & named constants
└── <domain>.test.ts          # Vitest unit tests for feature logic
```

### Business Domains

| Domain | Purpose |
|--------|---------|
| `auth` | User registration, login, JWT token refresh, current user profile |
| `users` | User account directory, profile management |
| `municipalities` | Municipality jurisdiction boundary definitions, radius check, base fare & per-km fare matrix |
| `drivers` | Driver verification applications, admin approval/rejection, online status toggle |
| `rides` | Ride request, driver matching, ride status state machine (`REQUESTED` → `ACCEPTED` → `DRIVER_ARRIVING` → `IN_PROGRESS` → `COMPLETED` / `CANCELLED`), customer ratings |
| `tracking` | Driver GPS coordinate broadcast (`POST /api/tracking/location`), active fleet positions query |
| `payments` | Ride payment records & cash payment status |
| `notifications` | User notifications history & FCM device token registration |

---

## Output Format

1. Domain & file structure
2. Database schema & entity types
3. Zod validation schemas & API endpoint contracts
4. Service layer business logic & state checks
5. Controller & route wiring
6. Vitest test plan
