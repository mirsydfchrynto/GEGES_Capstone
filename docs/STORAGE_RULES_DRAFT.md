# Firebase Storage Rules (Draft)

Purpose:
- Restrict access to tenant documents so only the tenant owner (owner_uid) and admin users can read/write files under `tenants/{tenantId}/docs/**`.

Rule (project root): `storage.rules` (draft included in repo).

How the rules work:
- `isOwner()` checks Firestore `tenants/{tenantId}.owner_uid` equals authenticated uid
- `isAdmin()` checks Firestore `users/{uid}.role == 'admin'`

Local emulator-based tests:
1. Install dev dependencies (once):
   - npm install --prefix scripts

2. Run the storage rules test:
   - npm run test:storage --prefix scripts

Notes:
- The test uses `@firebase/rules-unit-testing` to spin up emulators and run positive/negative assertions for read/write operations.
- Adjust `scripts/storage_rules_test.js` if you use a different project id or want to expand scenarios.
- Consider adding Storage emulator to CI matrix (GitHub Actions) to run rules tests on PRs.

Next steps:
- Add dedicated tests for file metadata (contentType limits / size limits).
- Add Storage emulator-based tests for tenant file listing and restricted downloads.
- After review, copy rules to Firebase console or deploy via `firebase deploy --only storage`.
