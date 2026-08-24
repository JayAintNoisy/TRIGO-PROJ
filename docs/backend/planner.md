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
| `auth` | Register (always `customer`, with optional `asDriver` that sets `driver_intent`), login, refresh, logout, `/auth/me` (includes `driverProfile` and `driverIntent`); users use `first_name`/`last_name` |
| `users` | Directory + profile update (`firstName`/`lastName`/`phone`/`photoUrl`) |
| `municipalities` | Jurisdictions + fare config (`base_fare`, `per_km_rate`, `exclusive_multiplier`, `min_fare`, `night_surcharge`, `max_passengers`); CRUD + partial updates |
| `drivers` | App lifecycle `pending`→`reviewing`→`approved`/`rejected`/`suspended`; transactional doc replace; `review`/`approve`/`reject` endpoints; online toggle |
| `rides` | Hardened state machine (`REQUESTED`→`ACCEPTED`→`DRIVER_ARRIVING`→`IN_PROGRESS`→`COMPLETED`/`CANCELLED`), owner checks, cancel fees, cash completion, idempotent ratings, polling |
| `tracking` | GPS broadcast + history (`ride_tracking`, `accuracy`), fleet query |
| `payments` | Cash payment records on ride completion |
| `notifications` | Persisted inbox + `device_tokens` (unique per user/platform); `POST /broadcast` with audience (`all`/`drivers`/`customers`) |
| `uploads` | `POST /uploads` (multer, 5 MB, `driver-documents`, JPG/PNG/WEBP/PDF, UUID names) + `GET /uploads/:folder/:filename` (auth, strict pattern) |

---

## Output Format

1. Domain & file structure
2. Database schema & entity types
3. Zod validation schemas & API endpoint contracts
4. Service layer business logic & state checks
5. Controller & route wiring
6. Vitest test plan
