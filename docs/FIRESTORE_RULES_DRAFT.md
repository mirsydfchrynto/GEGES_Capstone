# Firestore Security Rules (Draft)

Summary:

- Tenants collection protects onboarding flow.
- Authenticated users can create tenant applications.
- Owner (owner_uid) can read/update their tenant doc while status != 'active'.
- Only users with `users/{uid}.role == 'admin'` can set status to `active` or `rejected` and perform approvals.

Example rules: See `firestore.rules` at project root (draft).

Notes & next steps:
- Add automated unit tests against the Firebase emulator to validate rules.
- Consider indexes for tenant queries (status, invoice.status).
- Add Storage rules for tenant uploaded documents (restrict read to admins and tenant owners only).
- Document the RBAC model in `docs/` with example flows (owner creates tenant -> uploads docs -> submits payment -> admin verifies -> tenant activated).
