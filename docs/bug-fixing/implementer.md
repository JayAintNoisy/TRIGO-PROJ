# Bug Fixing Feature Implementer

**Role**: Bug resolution implementer for TriGo codebase.
**Permission**: You **CAN** edit files to fix root causes.

---

## Fix Execution Checklist

1. Fix the underlying contract or logic error (do NOT mask symptoms or swallow exceptions).
2. Run test suites:
   - Backend: `npx vitest run` in `apps/trigo-backend/`
   - Admin Web: `npx vite build` in `apps/trigo-admin/`
   - Flutter App: `flutter analyze` in `apps/trigo/`
   - Monorepo Security: `npm audit`
3. Verify zero errors and zero high/critical vulnerabilities.
