Release notes — Barber selection & payment-first flow (v1.x)

Summary:
- Added default barber selection algorithm that picks barbers free in the next hour or low-load fallback.
- Added paid barber selection option (+Rp 5.000) — reflected in UI totals and persisted in `queues` as `barber_selection_fee` and `paid_barber_selection`.
- Payment-first booking flow enforced: bookings are created with `status='awaiting_payment'` and a `payment_deadline`.
- Hardened refund logic: unpaid bookings cannot be refunded via UI; admin refund API will cancel unpaid bookings without `is_refunded` flag.
- Added admin Barber Management screen: manage `onLeave`, weekly `offDays`, and bulk-set off-day for all barbers in a shop.
- Added migration/backfill script: `scripts/backfill_barber_selection_and_barberman.js` to populate new fields for existing documents.

Testing:
- Extensive unit and integration tests added. Current test suite: 26 passed, 0 failed.
- New UI tests: `test/payment_ui_submit_test.dart` covers image pick + submit flow in `PaymentScreen`.

Migration instructions:
1. Run the backfill script with service account credentials set in `GOOGLE_APPLICATION_CREDENTIALS`:

```bash
npm i firebase-admin
node scripts/backfill_barber_selection_and_barberman.js
```

2. Verify sample documents in Firestore:
- `queues` should contain `barber_selection_fee` and `paid_barber_selection`.
- `barbermen` should contain `offDays`, `onLeave`, and `annualLeaveDays`.

Notes:
- The backfill is idempotent and runs in batches.
- If you want to run a one-off migration via Cloud Functions, adapt the script to your environment.
