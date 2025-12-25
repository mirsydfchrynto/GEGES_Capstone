QA Checklist — Booking lifecycle (added barber selection & payment improvements)

1) Default barber selection
- Scenario: User opens appointment screen and does NOT pick barber manually.
- Expectation: system auto-selects a barber who has no bookings in the next 1 hour; if none available, picks barber with fewest bookings in next 24h.
- Steps:
  - Set up barbers and queues in test Firestore
  - Open AppointmentScreen
  - Verify selected barber id matches expected criteria

2) Paid barber selection
- Scenario: Customer explicitly picks a barber and chooses the paid option.
- Expectation: Dialog confirms choice and adds Rp 5.000 to total; payload saved with `barber_selection_fee` and `paid_barber_selection=true`.
- Steps:
  - Choose a barber from the carousel and pick "Pilih Barber (Rp 5.000)"
  - Verify total updates to include Rp 5.000
  - Complete booking and check Firestore doc: `barber_selection_fee` == 5000, `paid_barber_selection` == true

3) Refund guard for unpaid bookings
- Scenario: Customer created booking but did NOT pay
- Expectation: History/detail screen does NOT show "Minta Pembatalan / Refund" button; Admin refund API performs a cancel (no `is_refunded` flag set).
- Steps:
  - Create a booking with status awaiting_payment/no payment proof
  - Open booking detail as customer: ensure refund button not visible
  - Call `adminRefundBooking` on booking: ensure `status == cancelled` and `is_refunded != true`

4) Admin management for barber schedule
- Scenario: Admin sets barber `onLeave` or weekly `offDays` using Barber Management screen
- Expectation: Changes stored on `barbermen` doc fields `onLeave`, `offDays` and reflected in default pick logic.
- Steps:
  - Set onLeave for a barber, create booking attempt on that day/time; ensure barber not selectable by default

5) Regression checks
- Run all unit tests (existing and new tests)
- Manually test payment flow: payment upload, admin verify, booking proceeds to ongoing state, finish service
- Confirm notification flow works for refund and payment acceptance

Notes:
- Firestore schema changes: `barbermen.offDays` (list of string), `barbermen.onLeave` (bool), `queues.barber_selection_fee` (int), `queues.paid_barber_selection` (bool)
- Document changes may require migration if you have existing data; for older documents, code provides defaults (0 / false) to remain compatible.
