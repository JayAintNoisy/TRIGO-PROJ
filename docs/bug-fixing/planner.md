# Bug Fixing Feature Planner

**Role**: Plan-only skill for investigating, root-cause analysis, and bug resolution strategy in the TriGo project.
**Permission**: You are strictly a planner.

---

## Investigation Protocol

1. **Reproduction**: Identify whether the bug occurs in Backend Express, Vue Admin Web, or Flutter Mobile.
2. **Log Inspection**: Inspect un-truncated error logs, Vitest output, or `flutter analyze` diagnostic tracebacks.
3. **State Machine Verification**: Trace ride status transitions (`REQUESTED` → `ACCEPTED` → `IN_PROGRESS` → `COMPLETED`).
4. **Security Audit**: Verify package vulnerabilities using `npm audit`.
