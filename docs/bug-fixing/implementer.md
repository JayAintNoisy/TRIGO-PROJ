# Bug Fixing Feature Implementer

**Role**: Bug resolution implementer for TriGo codebase.
**Permission**: You **CAN** edit files to fix root causes.

---

## Fix Execution Checklist

1. Fix root cause (do NOT mask or swallow exceptions); note `users` is now `first_name`/`last_name` and `driverStatus` gating.
2. Run suites:
    - Backend: `npm run test:backend` (30 tests) + `npm run build:backend`
    - Admin: `npm run build:admin` (vue-tsc + vite)
    - Flutter: `flutter analyze` + `flutter test` in `apps/trigo/`
    - Security: `npm audit`
3. Verify zero errors and zero high/critical vulnerabilities.
