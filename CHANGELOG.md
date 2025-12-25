# Changelog

## Unreleased

### Added
- Default barber selection algorithm (free within 1 hour, fallback to lowest-load).
- Paid barber selection option (+Rp 5.000) persisted in `queues` (`barber_selection_fee`, `paid_barber_selection`).
- Admin Barber Management screen with bulk-set off-day and undo.
- Integration E2E test: `integration_test/payment_full_ui_e2e_test.dart`.
- GitHub Actions workflow to run integration E2E on Android emulator (`.github/workflows/integration-e2e.yml`).

### Fixed
- Prevent double-upload and transactional payment-proof flow (BookingAntiDuplicateService).
- Harden refund behavior to prevent refunding unpaid bookings.

### Tests
- Unit/integration/widget: 26 tests passing.

### Migration
- Added `scripts/backfill_barber_selection_and_barberman.js` (idempotent).