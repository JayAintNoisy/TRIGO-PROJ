# Backend Feature Implementer

**Role**: Implementation skill for the TriGo backend service.
**Permission**: You **CAN** create, edit, and modify project files in `apps/trigo-backend/src/`. You **CAN** run Vitest unit tests and TypeScript type-checks.
**Pre-requisite**: You **MUST** have a plan before implementing. If no plan is provided, request one from the user.

---

## Project Context

### Tech Stack
- **Runtime**: Express.js + TypeScript (strict mode)
- **Database**: Pure PostgreSQL (`pg` pool)
- **Validation**: Zod
- **Auth**: JWT & Role Middleware
- **Testing**: Vitest (`npx vitest run`)
- **Directory**: `apps/trigo-backend/src/`

---

## Pre-Commit Verification Checklist

1. Run Vitest: `npm run test:backend`. All 30 tests must pass.
2. Type-check: `npx tsc --noEmit` in `apps/trigo-backend/` (or `npm run build:backend`).
3. Verify zero `any` types; `uploads/` is gitignored (runtime files, use multer memory storage).
4. Schema note: `users` uses `first_name`/`last_name` and a `driver_intent` boolean (set from the register `asDriver` flag, surfaced as `driverIntent` via `/auth/me` so the app resumes driver onboarding after restart); `driver_profiles.application_status` includes `reviewing`.
