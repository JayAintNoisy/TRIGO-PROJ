# Bug Fixing Feature Planner

**Role**: Plan-only skill for investigating, root-cause analysis, and bug resolution strategy in the TriGo project.
**Permission**: You are strictly a planner.

---

## Investigation Protocol

1. **Reproduction**: Identify Backend, Vue Admin, or Flutter Mobile.
2. **Log Inspection**: Inspect un-truncated logs, Vitest output, or `flutter analyze` traces.
3. **State Machine Verification**:
   - Rides: `REQUESTED` → `ACCEPTED` → `DRIVER_ARRIVING` → `IN_PROGRESS` → `COMPLETED`/`CANCELLED` (with owner checks + cancel fees).
   - Drivers: `pending` → `reviewing` → `approved`/`rejected`/`suspended` (review blocks resubmit).
4. **Driver Gating**: Check `app_router.dart` `_driverBlockedRoutes` + `hasOnboarded()` and `AuthState.driverStatus` handling.
5. **Security Audit**: `npm audit`.
