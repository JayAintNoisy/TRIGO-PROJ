# Integration Feature Implementer

**Role**: Implementation skill for cross-stack API client integration across TriGo Backend, Vue Admin, and Flutter App.
**Permission**: You **CAN** edit API client composables and network providers.

---

## Guidelines

1. **Bruno Requests**: Maintain `.bru` files inside `apps/trigo-backend/bruno/requests/` for all new endpoints.
2. **Vue Axios Integration**: Update `useApi()` calls and typed services in `apps/trigo-admin/src/features/`.
3. **Flutter Dio Integration**: Ensure network requests use `DioProvider` and pass `Bearer` auth headers automatically.
