Barber selection & paid selection — Implementation notes

Summary:
- Implemented default barber selection algorithm in `BarbershopService.pickDefaultBarber`.

### Migration script
A simple Node script to backfill the new fields has been added: `scripts/backfill_barber_selection_and_barberman.js`.

- Queues: set `barber_selection_fee` = 0 and `paid_barber_selection` = false where missing.
- Barbermen: set `offDays` = [] , `onLeave` = false, `annualLeaveDays` = 0 where missing.

Run it using a service account (set `GOOGLE_APPLICATION_CREDENTIALS`) and `node`:

```bash
npm i firebase-admin
node scripts/backfill_barber_selection_and_barberman.js
```

The script runs in batches and logs progress.

QA / Rollout Checklist:
- Run backfill in a staging project and verify sample documents.
- Run full test-suite (unit + integration + E2E) in CI green.
- Prepare migration window and schedule (low-traffic hours recommended).
- Communicate to operations team: no client-side action required; updated app handles missing fields.
- Tag release and create release notes with CHANGELOG entry.

- Added paid barber selection option (+Rp 5.000) in `AppointmentScreen` with confirmation dialog.
- Persisted additional fields in booking docs: `barber_selection_fee` (int) and `paid_barber_selection` (bool).
- Added `barbermen.offDays` (list of string) and `barbermen.onLeave` (bool) to manage barber availability.
- Hardened refund behavior in `QueueService.adminRefundBooking` to avoid marking refunds when no payment exists.

Firestore schema changes / migration notes:
- New fields for `barbermen` documents:
  - `offDays`: ["monday", "tuesday", ...] (optional)
  - `onLeave`: bool (default false)
- New fields for `queues` documents:
  - `barber_selection_fee`: int (default 0)
  - `paid_barber_selection`: bool (default false)

Migration guidance:
- Existing documents will work with new code (defaults applied if fields missing).
- If you want to backfill historical data, consider a one-off Cloud Function or script that sets `barber_selection_fee` to 0 and `paid_barber_selection` to false for any queues missing the fields.

Manual QA checklist (short):
- Create booking without selecting barber explicitly → check default barber chosen
- Select barber with paid option → total includes Rp 5.000 and booking doc contains flags
- Try to request refund on unpaid booking → button should not be visible
- Admin trying to refund unpaid booking → booking becomes cancelled (no refund flag)

Files changed (high level):
- `lib/services/barbershop_service.dart` (added `pickDefaultBarber` and DI support)
- `lib/screens/customer/appointment_screen.dart` (paid barber selection UI & fee handling)
- `lib/models/barberman.dart` (serializing `offDays` & `onLeave`)
- `lib/models/queue.dart` (added `barberSelectionFee` & `paidBarberSelection`)
- `lib/services/queue_service.dart` (store barber fee in createQueue, harden refund)
- `lib/screens/admin/barber_management_screen.dart` (admin UI for offDays / onLeave)

Next recommended steps:
- Add integration tests for the full booking flow (UI + Firestore). If you want, I can add them next.
