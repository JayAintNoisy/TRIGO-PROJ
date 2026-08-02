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

1. Run Vitest suite: `npm run test:backend`. All 13 tests must pass.
2. Run TypeScript compilation check: `npx tsc --noEmit` inside `apps/trigo-backend/`.
3. Verify zero `any` types.
