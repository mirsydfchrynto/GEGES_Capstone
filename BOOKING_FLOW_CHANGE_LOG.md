# Booking Flow Changes — Summary

This document summarizes the recent changes to booking and payment flows (Dec 2025).

Key changes:

- Booking creation is now **payment-first** for customer flows:
  - When a customer creates a booking from the mobile booking screen, the system will create the queue with `status = 'awaiting_payment'` and set a `payment_deadline` (default 10 minutes).
  - The booking slot is locked immediately (no other customer can take the same slot) while awaiting payment.
  - After creating booking, the customer is immediately navigated to the `PaymentScreen` to upload payment proof.
  - Admin will **verify payment** in the `Payment Verification` screen; upon approval the booking becomes `booked`.

- Admin confirmation of booking requests has been deprecated:
  - The previous `waiting -> awaiting_payment` confirm step is removed for normal customer flows.
  - The `Booking Requests` admin screen now shows an informational message and a shortcut to the `Payment Verification` screen.

- Slot availability now respects `awaiting_payment` state:
  - `isSlotAvailable` considers `awaiting_payment` as a locking status (in addition to `booked` and `ongoing`).

- Booking lead time (anti-collision rule):
  - Bookings must be created at least **30 minutes** before the requested booking time. This is enforced on both client and server.

- Manual booking by admin:
  - Admins can create manual (walk-in) bookings from `Add Manual Booking` screen.
  - Manual bookings are created with `status = 'booked'` and `payment_method = 'cash'` and use a shared `customer_id = 'manual_customer'` for easy tracing.
  - Manual booking UI validates slot availability (same as customer flow) before saving.

- Auto-cancel / cleanup:
  - An awaiting payment booking will be auto-cancelled when `payment_deadline` passes (system / UI triggers exist).

- Per-barbershop payment window:
  - Default payment window is **10 minutes** when a booking enters `awaiting_payment` or `waiting` without a client-provided `payment_deadline`.
  - Barbershops may override this per-shop via `payment_window_minutes` in their document. The server (QueueService) reads this value and sets `payment_deadline` accordingly.

Notes:
- Tests: added unit tests for the server-side lead-time helper (`QueueService.isBookingLeadTimeSufficient`).
- Follow-ups: integrate super admin tenant onboarding pages (React) and add integration tests for booking + payment lifecycle.
