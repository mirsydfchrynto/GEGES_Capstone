Server-side Atomic Create Guard

Problem
- Firestore security rules cannot reliably and atomically prevent a user from creating a second non-final tenant registration in all edge cases (client-side checks can be bypassed or race between clients).

Recommendation
- Implement a callable Cloud Function `createTenantGuard` that:
  1. Validates `context.auth.uid`.
  2. Queries the `tenants` collection for documents with `owner_uid == auth.uid` and an in-progress status (e.g., `draft`, `awaiting_payment`, `awaiting_confirmation`, `payment_submitted`).
  3. If any exist, returns an error with the existing tenant id and status.
  4. Otherwise, creates the tenant document server-side using admin privileges and returns the created tenant id.

Notes
- This ensures the check-and-create operation is atomic and trusted.
- The client-side `TenantService.createTenant` already performs a best-effort check and returns an existing tenant if found; the callable function is recommended as a follow-up for strong server-side enforcement.

Implementation outline (TS Cloud Function)
- Add a new file `backend/functions/src/createTenantGuard.ts`.
- Use `functions.https.onCall(async (data, context) => { ... })` to implement the flow.
- Unit test the function with fake_firestore or by mocking `firebase-admin`.

Deployment
- Add the function to `backend/functions/src/index.ts`, update `package.json` if needed, and deploy with `firebase deploy --only functions:createTenantGuard`.

Security
- The function checks `context.auth.uid` and returns `functions.https.HttpsError('failed-precondition', 'You have an active registration.');` where appropriate.
