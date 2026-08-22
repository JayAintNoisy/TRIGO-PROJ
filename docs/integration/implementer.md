# Integration Feature Implementer

**Role**: Implementation skill for cross-stack API client integration across TriGo Backend, Vue Admin, and Flutter App.
**Permission**: You **CAN** edit API client composables and network providers.

---

## Guidelines

1. **Bruno Requests**: Maintain `.bru` files inside `apps/trigo-backend/bruno/requests/` for all new endpoints.
2. **Vue Axios Integration**: Update `useApi()` calls and typed services in `apps/trigo-admin/src/features/`; `useApi` now has a 401 interceptor that redirects to login.
3. **Flutter Dio Integration**: Ensure requests use `DioProvider` with `Bearer` headers; use `upload_repository.dart` for `POST /uploads` (via `file_picker`).
4. **New Buckets Since `450e01b`**: `uploads` (`driver-documents`), `broadcast` audience handling, fare-matrix partial updates.
5. **Name Fields**: All user payloads use `firstName`/`lastName` (backend `first_name`/`last_name`).
