## PR: Centralize Tenant Service, Auto-cancel Cloud Function, Tests

Summary
- Centralized tenant Firestore operations into `lib/services/tenant_service.dart`.
- Added `lib/models/tenant.dart` for shared models.
- Implemented a scheduled Cloud Function in `backend/functions/src` to auto-cancel expired tenant invoices and accompanying unit test.
- Added a callable Cloud Function `createTenantGuard` in `backend/functions/src/createTenantGuard.ts` that atomically checks for existing in-progress registrations for the authenticated user and creates a new tenant if none exists. Included unit test and documentation (`docs/SERVER_SIDE_GUARD.md`).
- Added/updated widget and unit tests; full Flutter test suite passes locally.

Files changed (high-level)
- lib/services/tenant_service.dart (new/updated)
- lib/models/tenant.dart (new)
- lib/screens/* (updated call sites to use TenantServiceContract)
- backend/functions/src/* (cloud function, test, configs)

Tests
- Flutter: full `flutter test` run passed locally.
- Backend: `npm test` inside `backend/functions` passed (Jest + ts-jest).

Deployment / Runbook (Cloud Function)
1. Enter `backend/functions` directory.
2. Install deps: `npm ci` or `npm install`.
3. Run unit tests: `npm test`.
4. Ensure Firebase CLI is authenticated and project selected: `firebase login` and `firebase use <PROJECT_ID>`.
5. Deploy functions: `firebase deploy --only functions:scheduleCancelExpiredInvoices` (or deploy all functions if preferred).
6. Monitor logs: `firebase functions:log --only scheduleCancelExpiredInvoices` or via Firebase Console → Functions → Logs.

Indexes / Performance
- Consider indexing `tenants` collection on `invoices.<invoiceId>.deadline` or maintain a top-level map/array of pending invoice deadlines for efficient queries.

Security / Rules
- Ensure Firestore rules only allow status transitions via server-side admin context or via the verified-markPaid function.

Next steps (recommended)
- Draft PR branch and open PR with this description and links to key tests.
- Add CHANGELOG entry and concise migration notes in `CHANGELOG.md`.
- Implement E2E test for closed-app resume + server-side verify (integration harness/emulator).
- Added GitHub Actions workflow `.github/workflows/integration-e2e.yml` to start the Firestore emulator and run `integration_test/e2e_resume_payment_test.dart` on Android emulator. This workflow is configured as **manual** (`workflow_dispatch`) so it does not run automatically on PRs — the CI will continue to run **unit & widget tests** on PRs to preserve quick feedback loops. The workflow includes caching, retry logic (3 attempts), log collection, and an increased timeout to reduce flakiness.

Contact
- If you want, I can create the PR branch and open the PR — confirm and I'll proceed to push and open it.
